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
import SwiftUI

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
    
    // Sequence Tracking
    @Published var activeSequenceId: String?
    @Published var activeSequenceType: SequenceType?
    
    // Summary data for UI
    @Published var categorySummaries: [CategorySummary] = []
    @Published var timePeriodSummaries: [TimePeriodSummary] = []
    @Published var categoryChartSeries: [ChartSeries] = []
    private var summaryUpdateTimer: Timer?
    private var lastSummaryUpdate = Date()
    
    // Live activity tracking
    @Published var currentSession: LiveActivitySession?
    @Published var meaningfulSessions: [MeaningfulSession] = []
    @Published var recentAppSwitches: [MeaningfulSession] = [] // All recent app switches (shorter than 1 min)
    @Published var distractedPeriods: [DistractedPeriod] = []
    private var liveActivityUpdateTimer: Timer?
    
    // Session tracking for distraction detection
    private var currentSessionStart: Date?
    private var currentSessionAppName: String?
    private var currentSessionWindowTitle: String?
    private var recentSwitches: [(appName: String, time: Date)] = []
    private let meaningfulSessionThreshold: TimeInterval = 60 // 1 minute
    private let distractedPeriodThreshold: TimeInterval = 300 // 5 minutes
    
    private let db = Database.shared
    private let monitor = ActivityMonitor.shared
    private let idleDetector = IdleDetector.shared
    private let inputMonitor = InputMonitor.shared
    private let internalTracker = InternalAppTracker.shared
    
    private var eventBuffer: [ActivityEvent] = []
    private let bufferSize = 50
    private let flushInterval: TimeInterval = 12 // Flush every 12 seconds
    private var flushTimer: Timer?
    private var heartbeatTimer: Timer?
    private let bufferQueue = DispatchQueue(label: "com.solunified.eventbuffer", qos: .utility)
    
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
        
        // Start Causal Inference Sensor (ValueComputer)
        ValueComputer.shared.startMonitoring()
        
        // Setup internal app tracking callbacks
        setupInternalTrackingCallbacks()
        
        startFlushTimer()
        startHeartbeatTimer()
        startSummaryUpdateTimer()
        startLiveActivityTimer()
        
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
        
        // Load recent events asynchronously (don't block UI)
        loadRecentEventsAsync(limit: 100)
        
        // Calculate initial stats (already async)
        calculateStatsAsync()
    }
    
    func stopMonitoring() {
        guard isMonitoringActive else { return }
        
        log.logStatus("Monitoring stopped", symbol: "⏸")
        
        // Stop timers first (don't wait for flush)
        monitor.stopMonitoring()
        idleDetector.stopMonitoring()
        inputMonitor.stopMonitoring()
        inputMonitor.stopMouseTracking()
        
        ValueComputer.shared.stopMonitoring()
        
        flushTimer?.invalidate()
        flushTimer = nil
        
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        summaryUpdateTimer?.invalidate()
        summaryUpdateTimer = nil
        
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = nil
        
        isMonitoringActive = false
        
        // Reset deduplication tracking
        lastEventHash = nil
        lastDeduplicationTime = nil
        lastAppActivationBundleId = nil
        lastAppActivationTime = nil
        
        // Flush any pending events asynchronously (don't block)
        flushBufferAsync()
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
    
    func loadRecentEventsAsync(limit: Int = 100) {
        // Move database query off main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let results = self.db.query(
                "SELECT * FROM activity_log ORDER BY timestamp DESC LIMIT ?",
                parameters: [limit]
            )
            
            let loadedEvents = results.map { self.eventFromRow($0) }
            
            DispatchQueue.main.async { [weak self] in
                self?.events = loadedEvents
                self?.updateEventsTodayCount()
                self?.lastEventTime = self?.events.first?.timestamp
            }
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
    
    // MARK: - Sequence Management
    
    func startSequence(type: SequenceType, metadata: [String: Any]? = nil) {
        // End existing sequence if any
        if activeSequenceId != nil {
            endActiveSequence()
        }
        
        let id = UUID().uuidString
        let now = Date()
        
        var metadataString: String?
        if let metadata = metadata,
           let data = try? JSONSerialization.data(withJSONObject: metadata),
           let string = String(data: data, encoding: .utf8) {
            metadataString = string
        }
        
        let sequence = Sequence(
            id: id,
            type: type,
            startTime: now,
            status: .active,
            metadata: metadataString
        )
        
        if db.insertSequence(sequence) {
            DispatchQueue.main.async { [weak self] in
                self?.activeSequenceId = id
                self?.activeSequenceType = type
                ActivityLogger.shared.logStatus("Started sequence: \(type.rawValue)", symbol: "🎬")
            }
        } else {
            ActivityLogger.shared.logError("Failed to start sequence")
        }
    }
    
    func endActiveSequence(status: SequenceStatus = .completed) {
        guard let id = activeSequenceId else { return }
        
        let now = Date()
        if db.updateSequenceStatus(id: id, status: status, endTime: now) {
            DispatchQueue.main.async { [weak self] in
                self?.activeSequenceId = nil
                self?.activeSequenceType = nil
                ActivityLogger.shared.logStatus("Ended sequence: \(status.rawValue)", symbol: "🏁")
            }
        } else {
            ActivityLogger.shared.logError("Failed to end sequence")
        }
    }
    
    // MARK: - Data Capture Logging
    
    func logBiofeedback(type: String, value: Double, unit: String, source: String? = nil) {
        let payload = BiofeedbackPayload(type: type, value: value, unit: unit, source: source)
        logDataCaptureEvent(type: .biofeedbackLog, payload: payload)
    }
    
    func logEmotion(valence: Double, arousal: Double, label: String? = nil, note: String? = nil) {
        let payload = EmotionPayload(valence: valence, arousal: arousal, label: label, note: note)
        logDataCaptureEvent(type: .emotionLog, payload: payload)
    }
    
    func logLearningTarget(id: String, description: String, type: String, capacity: Double?) {
        let payload = LearningTargetPayload(targetId: id, description: description, targetType: type, capacityRequired: capacity)
        logDataCaptureEvent(type: .learningTargetSet, payload: payload)
    }
    
    func logOutcome(id: String, description: String, value: Double? = nil, tags: [String]? = nil) {
        let payload = OutcomePayload(outcomeId: id, description: description, value: value, tags: tags)
        logDataCaptureEvent(type: .outcomeLogged, payload: payload)
    }
    
    func logReflection(prompt: String?, response: String, tags: [String]? = nil) {
        let payload = ReflectionPayload(prompt: prompt, response: response, tags: tags)
        logDataCaptureEvent(type: .reflectionLog, payload: payload)
    }
    
    private func logDataCaptureEvent<T: Encodable>(type: ActivityEventType, payload: T) {
        guard let data = try? JSONEncoder().encode(payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            log.logError("Failed to encode payload for \(type)")
            return
        }
        
        let event = ActivityEvent(
            eventType: type,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            eventData: jsonString,
            timestamp: Date(),
            sequenceId: activeSequenceId
        )
        addEvent(event)
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
    
    private func setupInternalTrackingCallbacks() {
        internalTracker.onTabSwitch = { [weak self] tab in
            self?.handleInternalTabSwitch(tab)
        }
        
        internalTracker.onSettingsOpen = { [weak self] in
            self?.handleInternalSettingsOpen()
        }
        
        internalTracker.onSettingsClose = { [weak self] in
            self?.handleInternalSettingsClose()
        }
        
        internalTracker.onFeatureOpen = { [weak self] feature in
            self?.handleInternalFeatureOpen(feature)
        }
        
        internalTracker.onFeatureClose = { [weak self] feature in
            self?.handleInternalFeatureClose(feature)
        }
        
        internalTracker.onWindowShow = { [weak self] in
            self?.handleInternalWindowShow()
        }
        
        internalTracker.onWindowHide = { [weak self] in
            self?.handleInternalWindowHide()
        }
        
        // Notes
        internalTracker.onNoteCreate = { [weak self] title in
            self?.handleInternalNoteCreate(title: title)
        }
        
        internalTracker.onNoteEdit = { [weak self] id, title in
            self?.handleInternalNoteEdit(id: id, title: title)
        }
        
        internalTracker.onNoteDelete = { [weak self] id, title in
            self?.handleInternalNoteDelete(id: id, title: title)
        }
        
        internalTracker.onNoteView = { [weak self] id, title in
            self?.handleInternalNoteView(id: id, title: title)
        }
        
        internalTracker.onNoteSearch = { [weak self] query in
            self?.handleInternalNoteSearch(query: query)
        }
        
        internalTracker.onScratchpadEdit = { [weak self] in
            self?.handleInternalScratchpadEdit()
        }
        
        // Clipboard
        internalTracker.onClipboardCopy = { [weak self] preview in
            self?.handleInternalClipboardCopy(preview: preview)
        }
        
        internalTracker.onClipboardPaste = { [weak self] preview in
            self?.handleInternalClipboardPaste(preview: preview)
        }
        
        internalTracker.onClipboardClear = { [weak self] in
            self?.handleInternalClipboardClear()
        }
        
        internalTracker.onClipboardSearch = { [weak self] query in
            self?.handleInternalClipboardSearch(query: query)
        }
        
        // Timer
        internalTracker.onTimerStart = { [weak self] duration in
            self?.handleInternalTimerStart(duration: duration)
        }
        
        internalTracker.onTimerStop = { [weak self] in
            self?.handleInternalTimerStop()
        }
        
        internalTracker.onTimerReset = { [weak self] in
            self?.handleInternalTimerReset()
        }
        
        internalTracker.onTimerSetDuration = { [weak self] duration in
            self?.handleInternalTimerSetDuration(duration: duration)
        }
        
        // Screenshots
        internalTracker.onScreenshotView = { [weak self] filename in
            self?.handleInternalScreenshotView(filename: filename)
        }
        
        internalTracker.onScreenshotSearch = { [weak self] query in
            self?.handleInternalScreenshotSearch(query: query)
        }
        
        internalTracker.onScreenshotAnalyze = { [weak self] filename in
            self?.handleInternalScreenshotAnalyze(filename: filename)
        }
        
        // Settings
        internalTracker.onSettingChange = { [weak self] key, value in
            self?.handleInternalSettingChange(key: key, value: value)
        }
    }
    
    private func handleInternalTabSwitch(_ tab: AppTab) {
        let tabName = tabTabName(tab)
        let eventData = "{\"tab\":\"\(tabName)\"}"
        
        let event = ActivityEvent(
            eventType: .internalTabSwitch,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalSettingsOpen() {
        let event = ActivityEvent(
            eventType: .internalSettingsOpen,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: "Settings",
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalSettingsClose() {
        let event = ActivityEvent(
            eventType: .internalSettingsClose,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: "Settings",
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalFeatureOpen(_ feature: String) {
        let eventData = "{\"feature\":\"\(feature)\"}"
        
        let event = ActivityEvent(
            eventType: .internalFeatureOpen,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalFeatureClose(_ feature: String) {
        let eventData = "{\"feature\":\"\(feature)\"}"
        
        let event = ActivityEvent(
            eventType: .internalFeatureClose,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalWindowShow() {
        let event = ActivityEvent(
            eventType: .internalWindowShow,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: "Window Shown",
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalWindowHide() {
        let event = ActivityEvent(
            eventType: .internalWindowHide,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: "Window Hidden",
            timestamp: Date()
        )
        addEvent(event)
    }
    
    // MARK: - Notes Handlers
    private func handleInternalNoteCreate(title: String) {
        let eventData = "{\"title\":\"\(title)\"}"
        let event = ActivityEvent(
            eventType: .internalNoteCreate,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: title,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalNoteEdit(id: Int, title: String) {
        let eventData = "{\"id\":\(id),\"title\":\"\(title)\"}"
        let event = ActivityEvent(
            eventType: .internalNoteEdit,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: title,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalNoteDelete(id: Int, title: String) {
        let eventData = "{\"id\":\(id),\"title\":\"\(title)\"}"
        let event = ActivityEvent(
            eventType: .internalNoteDelete,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: title,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalNoteView(id: Int, title: String) {
        let eventData = "{\"id\":\(id),\"title\":\"\(title)\"}"
        let event = ActivityEvent(
            eventType: .internalNoteView,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: title,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalNoteSearch(query: String) {
        let eventData = "{\"query\":\"\(query)\"}"
        let event = ActivityEvent(
            eventType: .internalNoteSearch,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalScratchpadEdit() {
        let event = ActivityEvent(
            eventType: .internalScratchpadEdit,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: "Scratchpad",
            timestamp: Date()
        )
        addEvent(event)
    }
    
    // MARK: - Clipboard Handlers
    private func handleInternalClipboardCopy(preview: String) {
        let truncated = String(preview.prefix(100))
        let eventData = "{\"preview\":\"\(truncated)\"}"
        let event = ActivityEvent(
            eventType: .internalClipboardCopy,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: truncated,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalClipboardPaste(preview: String) {
        let truncated = String(preview.prefix(100))
        let eventData = "{\"preview\":\"\(truncated)\"}"
        let event = ActivityEvent(
            eventType: .internalClipboardPaste,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: truncated,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalClipboardClear() {
        let event = ActivityEvent(
            eventType: .internalClipboardClear,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalClipboardSearch(query: String) {
        let eventData = "{\"query\":\"\(query)\"}"
        let event = ActivityEvent(
            eventType: .internalClipboardSearch,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    // MARK: - Timer Handlers
    private func handleInternalTimerStart(duration: TimeInterval) {
        let minutes = Int(duration) / 60
        let eventData = "{\"duration\":\(duration),\"minutes\":\(minutes)}"
        let event = ActivityEvent(
            eventType: .internalTimerStart,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: "\(minutes)m Timer",
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalTimerStop() {
        let event = ActivityEvent(
            eventType: .internalTimerStop,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalTimerReset() {
        let event = ActivityEvent(
            eventType: .internalTimerReset,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalTimerSetDuration(duration: TimeInterval) {
        let minutes = Int(duration) / 60
        let eventData = "{\"duration\":\(duration),\"minutes\":\(minutes)}"
        let event = ActivityEvent(
            eventType: .internalTimerSetDuration,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: "\(minutes)m",
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    // MARK: - Screenshot Handlers
    private func handleInternalScreenshotView(filename: String) {
        let eventData = "{\"filename\":\"\(filename)\"}"
        let event = ActivityEvent(
            eventType: .internalScreenshotView,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: filename,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalScreenshotSearch(query: String) {
        let eventData = "{\"query\":\"\(query)\"}"
        let event = ActivityEvent(
            eventType: .internalScreenshotSearch,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func handleInternalScreenshotAnalyze(filename: String) {
        let eventData = "{\"filename\":\"\(filename)\"}"
        let event = ActivityEvent(
            eventType: .internalScreenshotAnalyze,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: filename,
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    // MARK: - Settings Handler
    private func handleInternalSettingChange(key: String, value: String) {
        let eventData = "{\"key\":\"\(key)\",\"value\":\"\(value)\"}"
        let event = ActivityEvent(
            eventType: .internalSettingChange,
            appBundleId: Bundle.main.bundleIdentifier,
            appName: "Sol Unified",
            windowTitle: "\(key): \(value)",
            eventData: eventData,
            timestamp: Date()
        )
        addEvent(event)
    }
    
    private func tabTabName(_ tab: AppTab) -> String {
        switch tab {
        case .tasks: return "Tasks"
        case .agents: return "Agents"
        case .vault: return "Vault"
        case .context: return "Context"
        case .terminal: return "Terminal"
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
        let appName = app.localizedName ?? bundleId
        
        // Update live activity session tracking
        updateCurrentSession(appName: appName, windowTitle: windowTitle, timestamp: now)
        
        let event = ActivityEvent(
            eventType: .appActivate,
            appBundleId: bundleId,
            appName: appName,
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
        
        // Skip tracking Sol Unified's own window changes
        if bundleId == Bundle.main.bundleIdentifier {
            return
        }
        
        let now = Date()
        
        // Skip window title changes immediately after app activation (within 0.5 seconds)
        // This prevents duplicate events when switching apps
        // Reduced from 3.0 to 0.5 seconds to allow faster window toggling
        if let lastActivationTime = lastAppActivationTime,
           bundleId == lastAppActivationBundleId,
           now.timeIntervalSince(lastActivationTime) < 0.5 {
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
        
        // Update current session window title
        if currentSessionAppName == appName {
            updateCurrentSessionWindowTitle(title)
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
        
        // Inject sequence ID if active and missing
        var eventToLog = event
        if eventToLog.sequenceId == nil, let activeId = activeSequenceId {
            eventToLog = ActivityEvent(
                id: event.id,
                eventType: event.eventType,
                appBundleId: event.appBundleId,
                appName: event.appName,
                windowTitle: event.windowTitle,
                eventData: event.eventData,
                timestamp: event.timestamp,
                createdAt: event.createdAt,
                sequenceId: activeId
            )
        }
        
        // Deduplication: Create hash of event and check if it's a duplicate
        let eventHash = createEventHash(eventToLog)
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
        
        bufferQueue.async { [weak self] in
            self?.eventBuffer.append(event)
            
            // Flush if buffer is full
            if let buffer = self?.eventBuffer, buffer.count >= self?.bufferSize ?? 50 {
                self?.flushBufferAsync()
            }
        }
        
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
            self?.flushBufferAsync()
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
        
        bufferQueue.sync {
            let eventsToFlush = eventBuffer
            eventBuffer.removeAll()
            
            let success = db.insertActivityEvents(eventsToFlush)
            log.logFlush(count: eventsToFlush.count, success: success)
            
            if !success {
                // Re-add to buffer for retry
                eventBuffer.insert(contentsOf: eventsToFlush, at: 0)
                DispatchQueue.main.async { [weak self] in
                    self?.monitoringError = "Failed to save events to database"
                }
            }
        }
    }
    
    private func flushBufferAsync() {
        // Move flush operation to background thread to avoid blocking UI
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard !self.eventBuffer.isEmpty else { return }
            
            let eventsToFlush = self.eventBuffer
            self.eventBuffer.removeAll()
            
            let success = self.db.insertActivityEvents(eventsToFlush)
            ActivityLogger.shared.logFlush(count: eventsToFlush.count, success: success)
            
            if !success {
                // Re-add to buffer for retry (on main thread for thread safety)
                self.eventBuffer.insert(contentsOf: eventsToFlush, at: 0)
                DispatchQueue.main.async { [weak self] in
                    self?.monitoringError = "Failed to save events to database"
                }
            }
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
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date(),
            sequenceId: row["sequence_id"] as? String
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
    
    func getEvents(from: Date, to: Date) -> [ActivityEvent] {
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
    
    // MARK: - Summary Calculations
    
    func calculateCategorySummaries() -> [CategorySummary] {
        let today = Calendar.current.startOfDay(for: Date())
        let recentEvents = events.filter { $0.timestamp >= today }
        
        guard !recentEvents.isEmpty else { return [] }
        
        var summaries: [CategorySummary] = []
        
        // By App (time-based)
        var appTimes: [String: (name: String, time: TimeInterval, count: Int)] = [:]
        var lastAppActivation: Date?
        var lastAppBundleId: String?
        
        for event in recentEvents.sorted(by: { $0.timestamp < $1.timestamp }) {
            switch event.eventType {
            case .appActivate:
                // Calculate time for previous app
                if let lastTime = lastAppActivation,
                   let lastBundleId = lastAppBundleId,
                   let lastAppName = recentEvents.first(where: { $0.appBundleId == lastBundleId })?.appName {
                    let duration = event.timestamp.timeIntervalSince(lastTime)
                    if var existing = appTimes[lastBundleId] {
                        existing.time += duration
                        existing.count += 1
                        appTimes[lastBundleId] = existing
                    } else {
                        appTimes[lastBundleId] = (name: lastAppName, time: duration, count: 1)
                    }
                }
                lastAppActivation = event.timestamp
                lastAppBundleId = event.appBundleId
            default:
                break
            }
        }
        
        // Handle current session
        if let lastTime = lastAppActivation,
           let lastBundleId = lastAppBundleId,
           let lastAppName = recentEvents.first(where: { $0.appBundleId == lastBundleId })?.appName {
            let duration = Date().timeIntervalSince(lastTime)
            if var existing = appTimes[lastBundleId] {
                existing.time += duration
                appTimes[lastBundleId] = existing
            } else {
                appTimes[lastBundleId] = (name: lastAppName, time: duration, count: 1)
            }
        }
        
        let totalAppTime = appTimes.values.reduce(0) { $0 + $1.time }
        
        for (bundleId, data) in appTimes.sorted(by: { $0.value.time > $1.value.time }).prefix(10) {
            let percentage = totalAppTime > 0 ? (data.time / totalAppTime) * 100 : 0
            summaries.append(CategorySummary(
                id: bundleId,
                category: data.name,
                count: data.count,
                duration: data.time,
                percentage: percentage,
                icon: "app.fill"
            ))
        }
        
        // By Event Type
        var eventTypeCounts: [ActivityEventType: Int] = [:]
        for event in recentEvents {
            eventTypeCounts[event.eventType, default: 0] += 1
        }
        
        let totalEvents = recentEvents.count
        for (eventType, count) in eventTypeCounts.sorted(by: { $0.value > $1.value }) {
            let percentage = totalEvents > 0 ? (Double(count) / Double(totalEvents)) * 100 : 0
            summaries.append(CategorySummary(
                id: eventType.rawValue,
                category: eventTypeLabel(eventType),
                count: count,
                duration: nil as TimeInterval?,
                percentage: percentage,
                icon: eventTypeIcon(eventType),
                color: eventTypeColor(eventType)
            ))
        }
        
        return summaries
    }
    
    func calculateTimePeriodSummaries() -> [TimePeriodSummary] {
        let calendar = Calendar.current
        let now = Date()
        var summaries: [TimePeriodSummary] = []
        
        // Get last 24 hours, grouped by hour
        for i in 0..<24 {
            guard let hourStart = calendar.date(byAdding: .hour, value: -i, to: now),
                  let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else {
                continue
            }
            
            let hourEvents = events.filter { $0.timestamp >= hourStart && $0.timestamp < hourEnd }
            
            if !hourEvents.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                let period = formatter.string(from: hourStart)
                
                // Calculate app summaries for this hour
                var appSummaries: [CategorySummary] = []
                var appCounts: [String: (name: String, count: Int)] = [:]
                
                for event in hourEvents {
                    if let bundleId = event.appBundleId,
                       let appName = event.appName {
                        if var existing = appCounts[bundleId] {
                            existing.count += 1
                            appCounts[bundleId] = existing
                        } else {
                            appCounts[bundleId] = (name: appName, count: 1)
                        }
                    }
                }
                
                let totalAppEvents = appCounts.values.reduce(0) { $0 + $1.count }
                for (bundleId, data) in appCounts.sorted(by: { $0.value.count > $1.value.count }).prefix(5) {
                    let percentage = totalAppEvents > 0 ? (Double(data.count) / Double(totalAppEvents)) * 100 : 0
                    appSummaries.append(CategorySummary(
                        id: "\(bundleId)-\(period)",
                        category: data.name,
                        count: data.count,
                        percentage: percentage,
                        icon: "app.fill"
                    ))
                }
                
                // Calculate event type summaries
                var eventTypeCounts: [ActivityEventType: Int] = [:]
                for event in hourEvents {
                    eventTypeCounts[event.eventType, default: 0] += 1
                }
                
                var eventTypeSummaries: [CategorySummary] = []
                let totalTypeEvents = hourEvents.count
                for (eventType, count) in eventTypeCounts.sorted(by: { $0.value > $1.value }).prefix(5) {
                    let percentage = totalTypeEvents > 0 ? (Double(count) / Double(totalTypeEvents)) * 100 : 0
                    eventTypeSummaries.append(CategorySummary(
                        id: "\(eventType.rawValue)-\(period)",
                        category: eventTypeLabel(eventType),
                        count: count,
                        percentage: percentage,
                        icon: eventTypeIcon(eventType),
                        color: eventTypeColor(eventType)
                    ))
                }
                
                summaries.append(TimePeriodSummary(
                    period: period,
                    startTime: hourStart,
                    endTime: hourEnd,
                    appSummaries: appSummaries,
                    eventTypeSummaries: eventTypeSummaries,
                    totalEvents: hourEvents.count
                ))
            }
        }
        
        return summaries.reversed() // Most recent first
    }
    
    private func eventTypeLabel(_ type: ActivityEventType) -> String {
        switch type {
        case .appLaunch: return "App Launch"
        case .appTerminate: return "App Terminate"
        case .appActivate: return "App Switch"
        case .windowTitleChange: return "Window Change"
        case .windowClosed: return "Window Closed"
        case .keyPress: return "Keyboard"
        case .mouseClick: return "Mouse Click"
        case .mouseMove: return "Mouse Move"
        case .mouseScroll: return "Mouse Scroll"
        case .internalTabSwitch: return "Tab Switch"
        case .internalSettingsOpen: return "Settings Open"
        case .internalSettingsClose: return "Settings Close"
        case .internalFeatureOpen: return "Feature Open"
        case .internalFeatureClose: return "Feature Close"
        case .internalNoteCreate: return "Note Create"
        case .internalNoteEdit: return "Note Edit"
        case .internalNoteDelete: return "Note Delete"
        case .internalNoteView: return "Note View"
        case .internalNoteSearch: return "Note Search"
        case .internalScratchpadEdit: return "Scratchpad Edit"
        case .internalClipboardCopy: return "Clipboard Copy"
        case .internalClipboardPaste: return "Clipboard Paste"
        case .internalClipboardClear: return "Clipboard Clear"
        case .internalClipboardSearch: return "Clipboard Search"
        case .internalTimerStart: return "Timer Start"
        case .internalTimerStop: return "Timer Stop"
        case .internalTimerReset: return "Timer Reset"
        case .internalTimerSetDuration: return "Timer Duration"
        case .internalScreenshotView: return "Screenshot View"
        case .internalScreenshotSearch: return "Screenshot Search"
        case .internalScreenshotAnalyze: return "Screenshot Analyze"
        case .internalSettingChange: return "Setting Change"
        case .internalWindowShow: return "Window Show"
        case .internalWindowHide: return "Window Hide"
        case .idleStart: return "Idle Start"
        case .idleEnd: return "Idle End"
        case .screenSleep: return "Screen Sleep"
        case .screenWake: return "Screen Wake"
        case .heartbeat: return "Heartbeat"
        case .biofeedbackLog: return "Biofeedback"
        case .emotionLog: return "Emotion Log"
        case .learningTargetSet: return "Target Set"
        case .learningTargetMet: return "Target Met"
        case .learningTargetMissed: return "Target Missed"
        case .outcomeLogged: return "Outcome"
        case .productivityMetric: return "Productivity"
        case .reflectionLog: return "Reflection"
        case .mindfulnessSessionStart: return "Mindfulness Start"
        case .mindfulnessSessionEnd: return "Mindfulness End"
        }
    }
    
    private func eventTypeIcon(_ type: ActivityEventType) -> String {
        switch type {
        case .appLaunch: return "arrow.up.circle.fill"
        case .appTerminate: return "xmark.circle.fill"
        case .appActivate: return "app.badge.fill"
        case .windowTitleChange: return "square.stack.3d.up.fill"
        case .windowClosed: return "xmark.square.fill"
        case .keyPress: return "keyboard.fill"
        case .mouseClick: return "cursorarrow.click"
        case .mouseMove: return "cursorarrow.move"
        case .mouseScroll: return "arrow.up.and.down"
        case .internalTabSwitch: return "rectangle.split.2x1"
        case .internalSettingsOpen: return "gearshape.fill"
        case .internalSettingsClose: return "gearshape"
        case .internalFeatureOpen: return "arrow.right.circle.fill"
        case .internalFeatureClose: return "arrow.left.circle.fill"
        case .internalNoteCreate: return "doc.badge.plus"
        case .internalNoteEdit: return "pencil"
        case .internalNoteDelete: return "trash.fill"
        case .internalNoteView: return "eye.fill"
        case .internalNoteSearch: return "magnifyingglass"
        case .internalScratchpadEdit: return "doc.text"
        case .internalClipboardCopy: return "doc.on.doc"
        case .internalClipboardPaste: return "doc.on.clipboard"
        case .internalClipboardClear: return "clear.fill"
        case .internalClipboardSearch: return "magnifyingglass"
        case .internalTimerStart: return "play.fill"
        case .internalTimerStop: return "pause.fill"
        case .internalTimerReset: return "stop.fill"
        case .internalTimerSetDuration: return "timer"
        case .internalScreenshotView: return "photo.fill"
        case .internalScreenshotSearch: return "magnifyingglass"
        case .internalScreenshotAnalyze: return "sparkles"
        case .internalSettingChange: return "gearshape.2.fill"
        case .internalWindowShow: return "eye.fill"
        case .internalWindowHide: return "eye.slash.fill"
        case .idleStart: return "moon.fill"
        case .idleEnd: return "sun.max.fill"
        case .screenSleep: return "moon.zzz.fill"
        case .screenWake: return "sunrise.fill"
        case .heartbeat: return "heart.fill"
        case .biofeedbackLog: return "waveform.path.ecg"
        case .emotionLog: return "face.smiling"
        case .learningTargetSet: return "target"
        case .learningTargetMet: return "checkmark.seal.fill"
        case .learningTargetMissed: return "xmark.seal.fill"
        case .outcomeLogged: return "flag.checkered"
        case .productivityMetric: return "chart.bar.fill"
        case .reflectionLog: return "book.closed.fill"
        case .mindfulnessSessionStart: return "leaf.fill"
        case .mindfulnessSessionEnd: return "leaf"
        }
    }
    
    private func eventTypeColor(_ type: ActivityEventType) -> Color {
        switch type {
        case .appLaunch, .appActivate, .screenWake, .idleEnd:
            return .brutalistAccent
        case .appTerminate, .windowClosed, .screenSleep, .idleStart:
            return .brutalistTextMuted
        default:
            return .brutalistTextSecondary
        }
    }
    
    // MARK: - Live Activity Tracking
    
    private func startLiveActivityTimer() {
        liveActivityUpdateTimer?.invalidate()
        
        // Update current session display every second
        liveActivityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isMonitoringActive else { return }
            
            DispatchQueue.main.async {
                // Update current session (triggers UI refresh)
                if self.currentSession != nil {
                    self.currentSession = LiveActivitySession(
                        appName: self.currentSession!.appName,
                        windowTitle: self.currentSession!.windowTitle,
                        startTime: self.currentSession!.startTime
                    )
                }
                
                // Check for meaningful sessions and distracted periods
                self.checkSessionStatus()
            }
        }
        
        if let timer = liveActivityUpdateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // Initialize current session if app is active
        if let currentApp = NSWorkspace.shared.frontmostApplication,
           let appName = currentApp.localizedName {
            let windowTitle = monitor.getActiveWindowTitle()
            updateCurrentSession(appName: appName, windowTitle: windowTitle, timestamp: Date())
        }
    }
    
    private func updateCurrentSession(appName: String, windowTitle: String?, timestamp: Date) {
        // End previous session if switching apps
        if let _ = currentSessionStart,
           let prevApp = currentSessionAppName,
           prevApp != appName {
            endPreviousSession(endTime: timestamp)
        }
        
        // Start new session
        currentSessionStart = timestamp
        currentSessionAppName = appName
        currentSessionWindowTitle = windowTitle
        
        // Add to recent switches
        recentSwitches.append((appName: appName, time: timestamp))
        // Keep only last 20 switches
        if recentSwitches.count > 20 {
            recentSwitches.removeFirst()
        }
        
        // Update published current session
        DispatchQueue.main.async { [weak self] in
            self?.currentSession = LiveActivitySession(
                appName: appName,
                windowTitle: windowTitle,
                startTime: timestamp
            )
        }
    }
    
    private func updateCurrentSessionWindowTitle(_ title: String?) {
        guard let appName = currentSessionAppName else { return }
        
        currentSessionWindowTitle = title
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let start = self.currentSessionStart else { return }
            self.currentSession = LiveActivitySession(
                appName: appName,
                windowTitle: title,
                startTime: start
            )
        }
    }
    
    private func endPreviousSession(endTime: Date) {
        guard let start = currentSessionStart,
              let appName = currentSessionAppName else { return }
        
        let duration = endTime.timeIntervalSince(start)
        
        let session = MeaningfulSession(
            appName: appName,
            windowTitle: currentSessionWindowTitle,
            startTime: start,
            endTime: endTime
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If session lasted >= 1 minute, add to meaningful sessions
            if duration >= self.meaningfulSessionThreshold {
                self.meaningfulSessions.insert(session, at: 0)
                // Keep only last 50 meaningful sessions
                if self.meaningfulSessions.count > 50 {
                    self.meaningfulSessions.removeLast()
                }
            } else {
                // Add to recent switches (shorter sessions)
                self.recentAppSwitches.insert(session, at: 0)
                // Keep only last 20 recent switches
                if self.recentAppSwitches.count > 20 {
                    self.recentAppSwitches.removeLast()
                }
            }
        }
        
        // Reset session tracking
        currentSessionStart = nil
        currentSessionAppName = nil
        currentSessionWindowTitle = nil
    }
    
    private func checkSessionStatus() {
        let now = Date()
        
        // Check for distracted periods
        checkDistractedPeriods(now: now)
    }
    
    private func checkDistractedPeriods(now: Date) {
        // Look at recent switches - if we've been switching for 5+ minutes without a 1-minute session
        guard recentSwitches.count >= 3 else { return }
        
        // Find the start of the current switching period (when we last had a meaningful session)
        var periodStart: Date?
        var switchesInPeriod: [(appName: String, time: Date)] = []
        
        // Go backwards through meaningful sessions to find when we last settled
        for session in meaningfulSessions.reversed() {
            if session.endTime <= now {
                periodStart = session.endTime
                break
            }
        }
        
        // If no meaningful session found, use the oldest switch
        if periodStart == nil {
            periodStart = recentSwitches.first?.time
        }
        
        guard let start = periodStart else { return }
        
        // Get all switches since the last meaningful session
        switchesInPeriod = recentSwitches.filter { $0.time >= start }
        
        // If period is >= 5 minutes and we've had 3+ switches without settling
        let periodDuration = now.timeIntervalSince(start)
        if periodDuration >= distractedPeriodThreshold && switchesInPeriod.count >= 3 {
            // Check if we already logged this distracted period
            let lastDistracted = distractedPeriods.first
            if lastDistracted == nil || lastDistracted!.endTime < start {
                let distracted = DistractedPeriod(
                    startTime: start,
                    endTime: now,
                    switchCount: switchesInPeriod.count
                )
                
                DispatchQueue.main.async { [weak self] in
                    self?.distractedPeriods.insert(distracted, at: 0)
                    // Keep only last 20 distracted periods
                    if self?.distractedPeriods.count ?? 0 > 20 {
                        self?.distractedPeriods.removeLast()
                    }
                }
                
                // Log distracted period event
                let event = ActivityEvent(
                    eventType: .idleStart, // Reuse idleStart for now, or add new type
                    appBundleId: Bundle.main.bundleIdentifier,
                    appName: "System",
                    windowTitle: "Distracted Period",
                    eventData: "{\"duration\":\(periodDuration),\"switches\":\(switchesInPeriod.count)}",
                    timestamp: now
                )
                addEvent(event)
            }
        }
    }
    
    private func startSummaryUpdateTimer() {
        summaryUpdateTimer?.invalidate()
        
        // Update summaries every 2 seconds (throttled)
        summaryUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isMonitoringActive else { return }
            
            // Only update if enough time has passed (throttle)
            let now = Date()
            if now.timeIntervalSince(self.lastSummaryUpdate) >= 1.0 {
                self.updateSummaries()
                self.lastSummaryUpdate = now
            }
        }
        
        if let timer = summaryUpdateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // Initial update
        updateSummaries()
    }
    
    private func updateSummaries() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let categories = self.calculateCategorySummaries()
            let periods = self.calculateTimePeriodSummaries()
            let chartSeries = self.calculateCategoryChartSeries()
            
            DispatchQueue.main.async {
                self.categorySummaries = categories
                self.timePeriodSummaries = periods
                self.categoryChartSeries = chartSeries
            }
        }
    }
    
    func calculateCategoryChartSeries() -> [ChartSeries] {
        let today = Calendar.current.startOfDay(for: Date())
        let recentEvents = events.filter { $0.timestamp >= today }
        
        guard !recentEvents.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        var series: [ChartSeries] = []
        
        // Get top apps by total event count
        var appCounts: [String: (name: String, count: Int)] = [:]
        for event in recentEvents {
            if let bundleId = event.appBundleId,
               let appName = event.appName {
                if var existing = appCounts[bundleId] {
                    existing.count += 1
                    appCounts[bundleId] = existing
                } else {
                    appCounts[bundleId] = (name: appName, count: 1)
                }
            }
        }
        
        // Get top 8 apps
        let topApps = appCounts.sorted(by: { $0.value.count > $1.value.count }).prefix(8)
        
        // Create hourly buckets for last 24 hours
        var timeBuckets: [Date] = []
        for i in 0..<24 {
            if let hour = calendar.date(byAdding: .hour, value: -i, to: now) {
                timeBuckets.insert(hour, at: 0) // Insert at beginning for chronological order
            }
        }
        
        // Assign colors to categories
        let colors = [
            Color.brutalistAccent,
            Color(hex: "#ef4444"),
            Color(hex: "#f59e0b"),
            Color(hex: "#10b981"),
            Color(hex: "#3b82f6"),
            Color(hex: "#8b5cf6"),
            Color(hex: "#ec4899"),
            Color(hex: "#6366f1"),
        ] as [Color]
        
        // Create series for each top app
        for (index, (bundleId, data)) in topApps.enumerated() {
            var dataPoints: [ChartDataPoint] = []
            
            for (_, bucketStart) in timeBuckets.enumerated() {
                let bucketEnd = calendar.date(byAdding: .hour, value: 1, to: bucketStart) ?? bucketStart
                
                // Count events for this app in this hour
                let hourEvents = recentEvents.filter { event in
                    event.timestamp >= bucketStart &&
                    event.timestamp < bucketEnd &&
                    event.appBundleId == bundleId
                }
                
                let count = hourEvents.count
                dataPoints.append(ChartDataPoint(
                    time: bucketStart,
                    value: Double(count),
                    category: data.name
                ))
            }
            
            if !dataPoints.isEmpty {
                series.append(ChartSeries(
                    category: data.name,
                    color: colors[min(index, colors.count - 1)],
                    dataPoints: dataPoints
                ))
            }
        }
        
        return series
    }
}

