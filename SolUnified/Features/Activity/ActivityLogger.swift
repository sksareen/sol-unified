//
//  ActivityLogger.swift
//  SolUnified
//
//  Compact, symbolic logging for activity monitoring
//

import Foundation

enum ActivityLogLevel {
    case info
    case event
    case warning
    case error
    case debug
}

struct ActivityLogger {
    static let shared = ActivityLogger()
    
    private let enabled = true // Could be controlled by debug flag
    
    private init() {}
    
    // Symbolic event type indicators
    private func symbol(for eventType: ActivityEventType) -> String {
        switch eventType {
        case .appLaunch: return "🚀"
        case .appTerminate: return "❌"
        case .appActivate: return "↔️"
        case .windowTitleChange: return "📑"
        case .windowClosed: return "🗙"
        case .keyPress: return "⌨️"
        case .mouseClick: return "🖱️"
        case .mouseMove: return "↗️"
        case .mouseScroll: return "⚡"
        case .idleStart: return "💤"
        case .idleEnd: return "☀️"
        case .screenSleep: return "🌙"
        case .screenWake: return "🌅"
        case .heartbeat: return "❤️"
        case .internalTabSwitch: return "📑"
        case .internalSettingsOpen: return "⚙️"
        case .internalSettingsClose: return "⚙️"
        case .internalFeatureOpen: return "→"
        case .internalFeatureClose: return "←"
        case .internalNoteCreate: return "📝"
        case .internalNoteEdit: return "✏️"
        case .internalNoteDelete: return "🗑️"
        case .internalNoteView: return "👁️"
        case .internalNoteSearch: return "🔍"
        case .internalScratchpadEdit: return "📄"
        case .internalClipboardCopy: return "📋"
        case .internalClipboardPaste: return "📌"
        case .internalClipboardClear: return "🧹"
        case .internalClipboardSearch: return "🔍"
        case .internalTimerStart: return "▶️"
        case .internalTimerStop: return "⏸️"
        case .internalTimerReset: return "⏹️"
        case .internalTimerSetDuration: return "⏱️"
        case .internalScreenshotView: return "🖼️"
        case .internalScreenshotSearch: return "🔍"
        case .internalScreenshotAnalyze: return "🤖"
        case .internalSettingChange: return "⚙️"
        case .internalWindowShow: return "👁️"
        case .internalWindowHide: return "👁️‍🗨️"
        }
    }
    
    // ANSI color codes
    private func color(_ level: ActivityLogLevel) -> String {
        guard enabled else { return "" }
        switch level {
        case .info: return "\u{001B}[36m" // Cyan
        case .event: return "\u{001B}[32m" // Green
        case .warning: return "\u{001B}[33m" // Yellow
        case .error: return "\u{001B}[31m" // Red
        case .debug: return "\u{001B}[90m" // Gray
        }
    }
    
    private func reset() -> String {
        return enabled ? "\u{001B}[0m" : ""
    }
    
    // Compact time formatter
    private func timeString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // Main logging method
    func log(_ message: String, level: ActivityLogLevel = .info) {
        guard enabled else { return }
        let time = timeString()
        let prefix = color(level)
        let suffix = reset()
        print("\(prefix)[\(time)]\(suffix) \(message)\n")
    }
    
    // Event logging with compact format
    func logEvent(_ event: ActivityEvent) {
        guard enabled else { return }
        let time = timeString(event.timestamp)
        let symbol = symbol(for: event.eventType)
        
        // Truncate long strings for compactness
        let app = truncate(event.appName ?? event.appBundleId ?? "?", maxLength: 20)
        let window = event.windowTitle.map { " \"\(truncate($0, maxLength: 30))\"" } ?? ""
        
        // Compact format: [time] symbol app window
        print("\(color(.event))[\(time)]\(reset()) \(symbol) \(app)\(window)\n")
    }
    
    // Helper to truncate strings
    private func truncate(_ str: String, maxLength: Int) -> String {
        if str.count <= maxLength {
            return str
        }
        return String(str.prefix(maxLength - 3)) + "..."
    }
    
    // Batch flush logging
    func logFlush(count: Int, success: Bool) {
        guard enabled else { return }
        if success {
            print("\(color(.info))[\(timeString())]\(reset()) 💾 +\(count)\n")
        } else {
            print("\(color(.error))[\(timeString())]\(reset()) 💾 ✗ \(count)\n")
        }
    }
    
    // Status logging
    func logStatus(_ status: String, symbol: String = "ℹ️") {
        guard enabled else { return }
        print("\(color(.info))[\(timeString())]\(reset()) \(symbol) \(status)\n")
    }
    
    // Warning logging
    func logWarning(_ message: String) {
        guard enabled else { return }
        print("\(color(.warning))[\(timeString())]\(reset()) ⚠️  \(message)\n")
    }
    
    // Error logging
    func logError(_ message: String) {
        guard enabled else { return }
        print("\(color(.error))[\(timeString())]\(reset()) ✗ \(message)\n")
    }
    
    // Skip/duplicate logging (very compact)
    func logSkip(_ reason: String, eventType: ActivityEventType? = nil) {
        guard enabled else { return }
        let sym = eventType.map { symbol(for: $0) } ?? "⊘"
        print("\(color(.debug))[\(timeString())]\(reset()) \(sym) ⊘ \(reason)\n")
    }
    
    // Stats logging
    func logStats(_ stats: String) {
        guard enabled else { return }
        print("\(color(.info))[\(timeString())]\(reset()) 📊 \(stats)\n")
    }
}

