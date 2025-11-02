//
//  ActivityStore.swift
//  SolUnified
//
//  Activity logging state management and coordination
//

import Foundation
import Combine
import AppKit
import CoreGraphics

// Compact logging
private let log = ActivityLogger.shared

class ActivityStore: ObservableObject {
    static let shared = ActivityStore()
    
    @Published var isEnabled: Bool = false
    @Published var isMonitoringActive: Bool = false
    @Published var events: [ActivityEvent] = []
    @Published var stats: ActivityStats?
    @Published var lastEventTime: Date?
    @Published var eventsTodayCount: Int = 0
    @Published var monitoringError: String?
    
    private let db = Database.shared
    private let monitor = ActivityMonitor.shared
    private let idleDetector = IdleDetector.shared
    private let inputMonitor = InputMonitor.shared
    
    private var eventBuffer: [ActivityEvent] = []
    private let bufferSize = 50
    private let flushInterval: TimeInterval = 12 // Flush every 12 seconds
    private var flushTimer: Timer?
    private var heartbeatTimer: Timer?
    
    private var lastActiveApp: NSRunningApplication?
    private var lastActiveAppSessionStart: Date?
    private var statsCache: ActivityStats?
    private var statsCacheTime: Date?
    private let statsCacheDuration: TimeInterval = 30
    
    // Deduplication tracking
    private var lastEventHash: String?
    private var lastDeduplicationTime: Date?
    private let deduplicationWindow: TimeInterval = 0.5 // Ignore duplicate events within 0.5 seconds
    
    // App activation deduplication - track last activation separately
    private var lastAppActivationBundleId: String?
    private var lastAppActivationTime: Date?
    private let appActivationDeduplicationWindow: TimeInterval = 2.0 // Ignore duplicate activations within 2 seconds
    
    private init() {
        setupCallbacks()
    }
    
    func startMonitoring() {
        // Prevent multiple simultaneous starts
        guard !isMonitoringActive else {
            log.logSkip("already monitoring")
            return
        }
        
        isEnabled = AppSettings.shared.activityLoggingEnabled
        guard isEnabled else { return }
        
        log.logStatus("Monitoring started", symbol: "▶")
        
        monitor.startMonitoring()
        idleDetector.startMonitoring()
        
        // Start input monitoring if enabled
        if AppSettings.shared.keyboardTrackingEnabled {
            inputMonitor.startMonitoring()
        }
        if AppSettings.shared.mouseTrackingEnabled {
            inputMonitor.startMouseTracking()
        }
        
        startFlushTimer()
        startHeartbeatTimer()
        
        isMonitoringActive = true
        monitoringError = nil
        
        // Reset deduplication tracking
        lastEventHash = nil
        lastDeduplicationTime = nil
        lastAppActivationBundleId = nil
        lastAppActivationTime = nil
        
        // Log current app state immediately (only once)
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            logCurrentAppState(app: currentApp)
        }
        
        // Load recent events
        loadRecentEvents(limit: 100)
        
        // Calculate initial stats
        calculateStatsAsync()
    }
    
    func stopMonitoring() {
        guard isMonitoringActive else { return }
        
        log.logStatus("Monitoring stopped", symbol: "⏸")
        
        // Flush any pending events
        flushBuffer()
        
        monitor.stopMonitoring()
        idleDetector.stopMonitoring()
        inputMonitor.stopMonitoring()
        inputMonitor.stopMouseTracking()
        
        flushTimer?.invalidate()
        flushTimer = nil
        
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        isMonitoringActive = false
        
        // Reset deduplication tracking
        lastEventHash = nil
        lastDeduplicationTime = nil
        lastAppActivationBundleId = nil
        lastAppActivationTime = nil
    }
    
    func loadRecentEvents(limit: Int = 100) {
        let results = db.query(
            "SELECT * FROM activity_log ORDER BY timestamp DESC LIMIT ?",
            parameters: [limit]
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.events = results.map { self?.eventFromRow($0) ?? ActivityEvent(eventType: .heartbeat) }
            self?.updateEventsTodayCount()
            self?.lastEventTime = self?.events.first?.timestamp
        }
    }
    
    func calculateStats(startDate: Date, endDate: Date) -> ActivityStats? {
        let startString = Database.dateToString(startDate)
        let endString = Database.dateToString(endDate)
        
        // Get all events in date range
        let results = db.query(
            "SELECT * FROM activity_log WHERE timestamp >= ? AND timestamp <= ? ORDER BY timestamp ASC",
            parameters: [startString, endString]
        )
        
        guard !results.isEmpty else {
            return ActivityStats(
                totalEvents: 0,
                totalActiveTime: 0,
                topApps: [],
                sessionsToday: 0
            )
        }
        
        let events = results.map { eventFromRow($0) }
        
        // Calculate sessions and time spent
        var sessions: [AppSession] = []
        var currentSession: AppSession?
        var totalActiveTime: TimeInterval = 0
        var lastActiveAppBundleId: String?
        var lastActiveAppName: String?
        
        for event in events {
            switch event.eventType {
            case .appActivate:
                // Close previous session
                if var session = currentSession {
                    session.endTime = event.timestamp
                    session.duration = event.timestamp.timeIntervalSince(session.startTime)
                    if session.duration >= 1.0 { // Minimum 1 second
                        sessions.append(session)
                        totalActiveTime += session.duration
                    }
                    currentSession = nil
                }
                
                // Start new session
                if let bundleId = event.appBundleId, let appName = event.appName {
                    currentSession = AppSession(
                        appBundleId: bundleId,
                        appName: appName,
                        startTime: event.timestamp,
                        windowTitle: event.windowTitle
                    )
                    lastActiveAppBundleId = bundleId
                    lastActiveAppName = appName
                }
                
            case .appTerminate:
                if var session = currentSession {
                    session.endTime = event.timestamp
                    session.duration = event.timestamp.timeIntervalSince(session.startTime)
                    if session.duration >= 1.0 {
                        sessions.append(session)
                        totalActiveTime += session.duration
                    }
                    currentSession = nil
                }
                
            case .idleStart:
                if var session = currentSession {
                    session.endTime = event.timestamp
                    session.duration = event.timestamp.timeIntervalSince(session.startTime)
                    if session.duration >= 1.0 {
                        sessions.append(session)
                        totalActiveTime += session.duration
                    }
                    currentSession = nil
                }
                
            case .idleEnd:
                // Resume session if we have a last active app
                if let bundleId = lastActiveAppBundleId, let appName = lastActiveAppName {
                    currentSession = AppSession(
                        appBundleId: bundleId,
                        appName: appName,
                        startTime: event.timestamp,
                        windowTitle: nil
                    )
                }
                
            default:
                break
            }
        }
        
        // Close any open session
        if var session = currentSession {
            session.endTime = endDate
            session.duration = endDate.timeIntervalSince(session.startTime)
            if session.duration >= 1.0 {
                sessions.append(session)
                totalActiveTime += session.duration
            }
        }
        
        // Group by app
        var appTimeMap: [String: (name: String, time: TimeInterval, count: Int)] = [:]
        
        for session in sessions {
            if let existing = appTimeMap[session.appBundleId] {
                appTimeMap[session.appBundleId] = (
                    name: existing.name,
                    time: existing.time + session.duration,
                    count: existing.count + 1
                )
            } else {
                appTimeMap[session.appBundleId] = (
                    name: session.appName,
                    time: session.duration,
                    count: 1
                )
            }
        }
        
        let topApps = appTimeMap.map { bundleId, data in
            ActivityStats.AppTime(
                appBundleId: bundleId,
                appName: data.name,
                totalTime: data.time,
                sessionCount: data.count
            )
        }.sorted { $0.totalTime > $1.totalTime }
        
        return ActivityStats(
            totalEvents: events.count,
            totalActiveTime: totalActiveTime,
            topApps: Array(topApps.prefix(5)),
            sessionsToday: sessions.count
        )
    }
    
    func calculateStatsAsync(startDate: Date? = nil, endDate: Date? = nil) {
        let start = startDate ?? Calendar.current.startOfDay(for: Date())
        let end = endDate ?? Date()
        
        // Check cache
        if let cached = statsCache,
           let cacheTime = statsCacheTime,
           Date().timeIntervalSince(cacheTime) < statsCacheDuration {
            DispatchQueue.main.async { [weak self] in
                self?.stats = cached
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let calculated = self.calculateStats(startDate: start, endDate: end)
            
            DispatchQueue.main.async {
                self.stats = calculated
                self.statsCache = calculated
                self.statsCacheTime = Date()
            }
        }
    }
    
    func getSessions(for appBundleId: String, date: Date) -> [AppSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let startString = Database.dateToString(startOfDay)
        let endString = Database.dateToString(endOfDay)
        
        let results = db.query(
            "SELECT * FROM activity_log WHERE app_bundle_id = ? AND timestamp >= ? AND timestamp <= ? ORDER BY timestamp ASC",
            parameters: [appBundleId, startString, endString]
        )
        
        // Similar session calculation logic as calculateStats
        var sessions: [AppSession] = []
        var currentSession: AppSession?
        
        for row in results {
            let event = eventFromRow(row)
            
            switch event.eventType {
            case .appActivate:
                if var session = currentSession {
                    session.endTime = event.timestamp
                    session.duration = event.timestamp.timeIntervalSince(session.startTime)
                    if session.duration >= 1.0 {
                        sessions.append(session)
                    }
                }
                
                if let bundleId = event.appBundleId, let appName = event.appName {
                    currentSession = AppSession(
                        appBundleId: bundleId,
                        appName: appName,
                        startTime: event.timestamp,
                        windowTitle: event.windowTitle
                    )
                }
                
            case .appTerminate, .idleStart:
                if var session = currentSession {
                    session.endTime = event.timestamp
                    session.duration = event.timestamp.timeIntervalSince(session.startTime)
                    if session.duration >= 1.0 {
                        sessions.append(session)
                    }
                    currentSession = nil
                }
                
            default:
                break
            }
        }
        
        return sessions
    }
    
    func clearHistory() -> Bool {
        let success = db.execute("DELETE FROM activity_log")
        if success {
            DispatchQueue.main.async { [weak self] in
                self?.events = []
                self?.eventsTodayCount = 0
                self?.stats = nil
                self?.lastEventTime = nil
            }
        }
        return success
    }
    
    func testEvent() {
        let event = ActivityEvent(
            eventType: .appActivate,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: "Test Event",
            timestamp: Date()
        )
        addEvent(event)
    }
    
    // MARK: - Private Methods
    
    private func setupCallbacks() {
        monitor.onAppLaunch = { [weak self] app in
            self?.handleAppLaunch(app)
        }
        
        monitor.onAppTerminate = { [weak self] app in
            self?.handleAppTerminate(app)
        }
        
        monitor.onAppActivate = { [weak self] app, previousApp in
            self?.handleAppActivate(app, previousApp: previousApp)
        }
        
        monitor.onWindowTitleChange = { [weak self] title in
            self?.handleWindowTitleChange(title)
        }
        
        monitor.onWindowClosed = { [weak self] title in
            self?.handleWindowClosed(title)
        }
        
        monitor.onScreenSleep = { [weak self] in
            self?.addEvent(ActivityEvent(eventType: .screenSleep, timestamp: Date()))
        }
        
        monitor.onScreenWake = { [weak self] in
            self?.addEvent(ActivityEvent(eventType: .screenWake, timestamp: Date()))
        }
        
        idleDetector.onIdleStart = { [weak self] in
            self?.addEvent(ActivityEvent(eventType: .idleStart, timestamp: Date()))
        }
        
        idleDetector.onIdleEnd = { [weak self] in
            self?.addEvent(ActivityEvent(eventType: .idleEnd, timestamp: Date()))
        }
        
        inputMonitor.onKeyPress = { [weak self] description, keyCode in
            self?.handleKeyPress(description: description, keyCode: keyCode)
        }
        
        inputMonitor.onMouseClick = { [weak self] position, button in
            self?.handleMouseClick(position: position, button: button)
        }
        
        inputMonitor.onMouseMove = { [weak self] position in
            self?.handleMouseMove(position: position)
        }
        
        inputMonitor.onMouseScroll = { [weak self] position, delta in
            self?.handleMouseScroll(position: position, delta: delta)
        }
    }
    
    private func logCurrentAppState(app: NSRunningApplication) {
        let windowTitle = monitor.getActiveWindowTitle()
        let event = ActivityEvent(
            eventType: .appActivate,
            appBundleId: app.bundleIdentifier,
            appName: app.localizedName,
            windowTitle: windowTitle,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleAppLaunch(_ app: NSRunningApplication) {
        let event = ActivityEvent(
            eventType: .appLaunch,
            appBundleId: app.bundleIdentifier,
            appName: app.localizedName,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleAppTerminate(_ app: NSRunningApplication) {
        let event = ActivityEvent(
            eventType: .appTerminate,
            appBundleId: app.bundleIdentifier,
            appName: app.localizedName,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleAppActivate(_ app: NSRunningApplication, previousApp: NSRunningApplication?) {
        guard let bundleId = app.bundleIdentifier else { return }
        let now = Date()
        
        // Aggressive deduplication: Check if we just logged this exact app activation
        if let lastBundleId = lastAppActivationBundleId,
           let lastTime = lastAppActivationTime,
           bundleId == lastBundleId,
           now.timeIntervalSince(lastTime) < appActivationDeduplicationWindow {
            log.logSkip("duplicate activation", eventType: .appActivate)
            return
        }
        
        // Also check the events array as a fallback (though this might be stale)
        if let lastEvent = events.first,
           lastEvent.eventType == .appActivate,
           lastEvent.appBundleId == bundleId,
           now.timeIntervalSince(lastEvent.timestamp) < appActivationDeduplicationWindow {
            log.logSkip("duplicate activation", eventType: .appActivate)
            return
        }
        
        // Update deduplication tracking BEFORE logging
        lastAppActivationBundleId = bundleId
        lastAppActivationTime = now
        
        lastActiveApp = app
        lastActiveAppSessionStart = now
        
        let windowTitle = monitor.getActiveWindowTitle()
        let event = ActivityEvent(
            eventType: .appActivate,
            appBundleId: bundleId,
            appName: app.localizedName,
            windowTitle: windowTitle,
            timestamp: now
        )
        
        // Log will happen in addEvent via logEvent
        addEvent(event)
    }
    
    private func handleWindowTitleChange(_ title: String?) {
        guard let app = monitor.getCurrentApp(),
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            return
        }
        
        let now = Date()
        
        // Skip window title changes immediately after app activation (within 3 seconds)
        // This prevents duplicate events when switching apps
        if let lastActivationTime = lastAppActivationTime,
           bundleId == lastAppActivationBundleId,
           now.timeIntervalSince(lastActivationTime) < 3.0 {
            log.logSkip("window change too soon", eventType: .windowTitleChange)
            return
        }
        
        // Additional deduplication: Skip if we just logged a window title change for this app
        if let lastEvent = events.first,
           lastEvent.eventType == .windowTitleChange,
           lastEvent.appBundleId == bundleId,
           lastEvent.windowTitle == title,
           now.timeIntervalSince(lastEvent.timestamp) < 2.0 {
            log.logSkip("duplicate window title", eventType: .windowTitleChange)
            return
        }
        
        let event = ActivityEvent(
            eventType: .windowTitleChange,
            appBundleId: bundleId,
            appName: appName,
            windowTitle: title,
            timestamp: now
        )
        addEvent(event)
    }
    
    private func handleWindowClosed(_ title: String?) {
        guard let app = monitor.getCurrentApp(),
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            return
        }
        
        let event = ActivityEvent(
            eventType: .windowClosed,
            appBundleId: bundleId,
            appName: appName,
            windowTitle: title,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleKeyPress(description: String?, keyCode: CGKeyCode) {
        guard let app = monitor.getCurrentApp(),
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            return
        }
        
        // Store key count in event_data as JSON
        let eventData = "{\"keyCount\":\"\(description ?? "1")\",\"keyCode\":\(keyCode)}"
        
        let event = ActivityEvent(
            eventType: .keyPress,
            appBundleId: bundleId,
            appName: appName,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleMouseClick(position: NSPoint, button: Int) {
        guard let app = monitor.getCurrentApp(),
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            return
        }
        
        let eventData = "{\"x\":\(position.x),\"y\":\(position.y),\"button\":\(button)}"
        
        let event = ActivityEvent(
            eventType: .mouseClick,
            appBundleId: bundleId,
            appName: appName,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleMouseMove(position: NSPoint) {
        guard let app = monitor.getCurrentApp(),
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            return
        }
        
        let eventData = "{\"x\":\(position.x),\"y\":\(position.y)}"
        
        let event = ActivityEvent(
            eventType: .mouseMove,
            appBundleId: bundleId,
            appName: appName,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleMouseScroll(position: NSPoint, delta: Double) {
        guard let app = monitor.getCurrentApp(),
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            return
        }
        
        let eventData = "{\"x\":\(position.x),\"y\":\(position.y),\"delta\":\(delta)}"
        
        let event = ActivityEvent(
            eventType: .mouseScroll,
            appBundleId: bundleId,
            appName: appName,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func addEvent(_ event: ActivityEvent) {
        // Validate timestamp
        let maxFutureTime = Date().addingTimeInterval(3600) // 1 hour in future
        
        guard event.timestamp <= maxFutureTime else {
            log.logError("invalid timestamp")
            return
        }
        
        // Deduplication: Create hash of event and check if it's a duplicate
        let eventHash = createEventHash(event)
        let now = event.timestamp
        
        // Skip if this is the exact same event within the deduplication window
        if let lastHash = lastEventHash,
           let lastTime = lastDeduplicationTime,
           eventHash == lastHash,
           now.timeIntervalSince(lastTime) < deduplicationWindow {
            log.logSkip("duplicate event", eventType: event.eventType)
            return
        }
        
        // Update deduplication tracking
        lastEventHash = eventHash
        lastDeduplicationTime = now
        
        eventBuffer.append(event)
        
        // Log event
        log.logEvent(event)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.events.insert(event, at: 0)
            if self.events.count > 500 {
                self.events.removeLast()
            }
            self.lastEventTime = event.timestamp
            self.updateEventsTodayCount()
        }
        
        // Flush if buffer is full
        if eventBuffer.count >= bufferSize {
            flushBuffer()
        }
    }
    
    private func createEventHash(_ event: ActivityEvent) -> String {
        // Create a hash based on event type, app bundle ID, and window title
        // This helps detect true duplicates (same event type, same app, same window)
        let components = [
            event.eventType.rawValue,
            event.appBundleId ?? "",
            event.windowTitle ?? ""
        ]
        return components.joined(separator: "|")
    }
    
    private func startFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flushBuffer()
        }
        
        if let timer = flushTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self, self.isMonitoringActive else { return }
            let event = ActivityEvent(eventType: .heartbeat, timestamp: Date())
            self.addEvent(event)
        }
        
        if let timer = heartbeatTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func flushBuffer() {
        guard !eventBuffer.isEmpty else { return }
        
        let eventsToFlush = eventBuffer
        eventBuffer.removeAll()
        
        let success = db.insertActivityEvents(eventsToFlush)
        log.logFlush(count: eventsToFlush.count, success: success)
        
        if !success {
            // Re-add to buffer for retry
            eventBuffer.insert(contentsOf: eventsToFlush, at: 0)
            monitoringError = "Failed to save events to database"
        }
    }
    
    private func updateEventsTodayCount() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let count = events.filter { $0.timestamp >= startOfDay }.count
        eventsTodayCount = count
    }
    
    private func eventFromRow(_ row: [String: Any]) -> ActivityEvent {
        let eventTypeString = row["event_type"] as? String ?? ""
        let eventType = ActivityEventType(rawValue: eventTypeString) ?? .heartbeat
        
        return ActivityEvent(
            id: row["id"] as? Int ?? 0,
            eventType: eventType,
            appBundleId: row["app_bundle_id"] as? String,
            appName: row["app_name"] as? String,
            windowTitle: row["window_title"] as? String,
            eventData: row["event_data"] as? String,
            timestamp: Database.stringToDate(row["timestamp"] as? String ?? "") ?? Date(),
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date()
        )
    }
    
    // MARK: - Timeline Methods
    
    func calculateTimelineBuckets(for range: TimeRange) -> [TimelineBucket] {
        let calendar = Calendar.current
        let now = Date()
        
        let (startDate, endDate): (Date, Date) = {
            switch range {
            case .today:
                return (calendar.startOfDay(for: now), now)
            case .last7Days:
                let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
                return (start, now)
            case .last30Days:
                let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
                return (start, now)
            }
        }()
        
        let bucketSize: DateComponents = {
            switch range {
            case .today:
                return DateComponents(hour: 1)
            case .last7Days:
                return DateComponents(day: 1)
            case .last30Days:
                return DateComponents(day: 1)
            }
        }()
        
        var buckets: [TimelineBucket] = []
        var currentStart = startDate
        
        while currentStart < endDate {
            guard let currentEnd = calendar.date(byAdding: bucketSize, to: currentStart),
                  currentEnd <= endDate else {
                break
            }
            
            let eventsInBucket = getEvents(from: currentStart, to: currentEnd)
            let intensity = calculateIntensity(events: eventsInBucket)
            let topApp = findTopApp(in: eventsInBucket)
            let activeMinutes = calculateActiveMinutes(events: eventsInBucket)
            
            let bucket = TimelineBucket(
                startTime: currentStart,
                endTime: currentEnd,
                eventCount: eventsInBucket.count,
                activeMinutes: activeMinutes,
                topApp: topApp,
                intensity: intensity
            )
            
            buckets.append(bucket)
            currentStart = currentEnd
        }
        
        return buckets
    }
    
    private func getEvents(from: Date, to: Date) -> [ActivityEvent] {
        let startString = Database.dateToString(from)
        let endString = Database.dateToString(to)
        
        let results = db.query(
            "SELECT * FROM activity_log WHERE timestamp >= ? AND timestamp < ? ORDER BY timestamp ASC",
            parameters: [startString, endString]
        )
        
        return results.map { eventFromRow($0) }
    }
    
    private func calculateIntensity(events: [ActivityEvent]) -> Double {
        guard !events.isEmpty else { return 0.0 }
        
        // Calculate intensity based on event count and app switches
        let switchCount = events.filter { $0.eventType == .appActivate }.count
        let totalEvents = events.count
        
        // Normalize to 0-1 range
        // For hourly buckets: expect max ~20 events/hour
        // For daily buckets: expect max ~500 events/day
        let maxExpected: Double = 20.0 // Base for hourly
        let intensity = min(1.0, Double(totalEvents) / maxExpected)
        
        // Boost intensity for high switch activity
        let switchBoost = min(0.3, Double(switchCount) / 10.0)
        
        return min(1.0, intensity + switchBoost)
    }
    
    private func findTopApp(in events: [ActivityEvent]) -> String? {
        var appCounts: [String: Int] = [:]
        
        for event in events {
            if event.eventType == .appActivate,
               let appName = event.appName {
                appCounts[appName, default: 0] += 1
            }
        }
        
        return appCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func calculateActiveMinutes(events: [ActivityEvent]) -> Int {
        guard !events.isEmpty else { return 0 }
        
        // Count unique minutes with activity
        var activeMinutes: Set<String> = []
        let calendar = Calendar.current
        
        for event in events {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: event.timestamp)
            if let year = components.year,
               let month = components.month,
               let day = components.day,
               let hour = components.hour,
               let minute = components.minute {
                let minuteKey = "\(year)-\(month)-\(day)-\(hour)-\(minute)"
                activeMinutes.insert(minuteKey)
            }
        }
        
        return activeMinutes.count
    }
}

