//
//  ActivityStore.swift
//  SolUnified
//
//  Activity logging state management and coordination
//

import Foundation
import Combine
import AppKit

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
    
    private init() {
        setupCallbacks()
    }
    
    func startMonitoring() {
        // Prevent multiple simultaneous starts
        guard !isMonitoringActive else {
            print("ActivityStore: Already monitoring, ignoring startMonitoring() call")
            return
        }
        
        isEnabled = AppSettings.shared.activityLoggingEnabled
        guard isEnabled else { return }
        
        print("ActivityStore: Starting monitoring...")
        
        monitor.startMonitoring()
        idleDetector.startMonitoring()
        
        startFlushTimer()
        startHeartbeatTimer()
        
        isMonitoringActive = true
        monitoringError = nil
        
        // Reset deduplication tracking
        lastEventHash = nil
        lastDeduplicationTime = nil
        
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
        
        print("ActivityStore: Stopping monitoring...")
        
        // Flush any pending events
        flushBuffer()
        
        monitor.stopMonitoring()
        idleDetector.stopMonitoring()
        
        flushTimer?.invalidate()
        flushTimer = nil
        
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        isMonitoringActive = false
        
        // Reset deduplication tracking
        lastEventHash = nil
        lastDeduplicationTime = nil
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
        let now = Date()
        
        // Skip if same app reactivated within 1 second (more aggressive deduplication)
        if let previousApp = previousApp,
           previousApp.bundleIdentifier == app.bundleIdentifier,
           let lastEvent = events.first,
           now.timeIntervalSince(lastEvent.timestamp) < 1.0 {
            print("ActivityStore: Skipping duplicate app activation: \(app.localizedName ?? "unknown")")
            return
        }
        
        // Also check if we just logged an activation for this app very recently
        if let lastEvent = events.first,
           lastEvent.eventType == .appActivate,
           lastEvent.appBundleId == app.bundleIdentifier,
           now.timeIntervalSince(lastEvent.timestamp) < 0.5 {
            print("ActivityStore: Skipping rapid duplicate activation: \(app.localizedName ?? "unknown")")
            return
        }
        
        lastActiveApp = app
        lastActiveAppSessionStart = now
        
        let windowTitle = monitor.getActiveWindowTitle()
        let event = ActivityEvent(
            eventType: .appActivate,
            appBundleId: app.bundleIdentifier,
            appName: app.localizedName,
            windowTitle: windowTitle,
            timestamp: now
        )
        addEvent(event)
    }
    
    private func handleWindowTitleChange(_ title: String?) {
        guard let app = monitor.getCurrentApp(),
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            return
        }
        
        // Additional deduplication: Skip if we just logged a window title change for this app
        let now = Date()
        if let lastEvent = events.first,
           lastEvent.eventType == .windowTitleChange,
           lastEvent.appBundleId == bundleId,
           lastEvent.windowTitle == title,
           now.timeIntervalSince(lastEvent.timestamp) < 1.0 {
            print("ActivityStore: Skipping duplicate window title change")
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
    
    private func addEvent(_ event: ActivityEvent) {
        // Validate timestamp
        let maxFutureTime = Date().addingTimeInterval(3600) // 1 hour in future
        
        guard event.timestamp <= maxFutureTime else {
            print("Invalid event timestamp: too far in future")
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
            print("ActivityStore: Skipping duplicate event: \(event.eventType.rawValue)")
            return
        }
        
        // Update deduplication tracking
        lastEventHash = eventHash
        lastDeduplicationTime = now
        
        eventBuffer.append(event)
        
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
        
        if success {
            print("Flushed \(eventsToFlush.count) activity events to database")
        } else {
            print("Failed to flush activity events")
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
}

