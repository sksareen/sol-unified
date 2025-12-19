//
//  Models.swift
//  SolUnified
//
//  Data models for all features
//

import Foundation
import SwiftUI

// MARK: - Note Model
struct Note: Identifiable, Codable {
    let id: Int
    var title: String
    var content: String
    var isGlobal: Bool
    let createdAt: Date
    var updatedAt: Date
    
    init(id: Int = 0, title: String = "", content: String = "", isGlobal: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.isGlobal = isGlobal
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Clipboard Item Model
enum ContentType: String, Codable {
    case text
    case image
    case file
}

struct ClipboardItem: Identifiable, Codable {
    let id: Int
    let contentType: ContentType
    let contentText: String?
    let contentPreview: String?
    let filePath: String?
    let contentHash: String
    let createdAt: Date
    
    init(id: Int = 0, contentType: ContentType, contentText: String? = nil, contentPreview: String? = nil, filePath: String? = nil, contentHash: String, createdAt: Date = Date()) {
        self.id = id
        self.contentType = contentType
        self.contentText = contentText
        self.contentPreview = contentPreview
        self.filePath = filePath
        self.contentHash = contentHash
        self.createdAt = createdAt
    }
}

// MARK: - Screenshot Model
struct Screenshot: Identifiable, Codable {
    let id: Int
    let filename: String
    let filepath: String
    let fileHash: String
    let fileSize: Int
    let createdAt: Date
    let modifiedAt: Date
    let width: Int
    let height: Int
    var aiDescription: String?
    var aiTags: String?
    var aiTextContent: String?
    var analyzedAt: Date?
    var analysisModel: String?
    
    init(id: Int = 0, filename: String, filepath: String, fileHash: String, fileSize: Int, createdAt: Date, modifiedAt: Date, width: Int, height: Int, aiDescription: String? = nil, aiTags: String? = nil, aiTextContent: String? = nil, analyzedAt: Date? = nil, analysisModel: String? = nil) {
        self.id = id
        self.filename = filename
        self.filepath = filepath
        self.fileHash = fileHash
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.width = width
        self.height = height
        self.aiDescription = aiDescription
        self.aiTags = aiTags
        self.aiTextContent = aiTextContent
        self.analyzedAt = analyzedAt
        self.analysisModel = analysisModel
    }
}

// MARK: - Screenshot Stats
struct ScreenshotStats: Codable {
    let totalScreenshots: Int
    let totalSizeMB: Double
    let topTags: [TagCount]
    
    struct TagCount: Codable {
        let tag: String
        let count: Int
    }
}

// MARK: - Activity Models
enum ActivityEventType: String, Codable {
    case appLaunch
    case appTerminate
    case appActivate
    case windowTitleChange
    case windowClosed
    case idleStart
    case idleEnd
    case screenSleep
    case screenWake
    case heartbeat
    case keyPress
    case mouseClick
    case mouseMove
    case mouseScroll
    case internalTabSwitch
    case internalSettingsOpen
    case internalSettingsClose
    case internalFeatureOpen
    case internalFeatureClose
    case internalNoteCreate
    case internalNoteEdit
    case internalNoteDelete
    case internalNoteView
    case internalNoteSearch
    case internalScratchpadEdit
    case internalClipboardCopy
    case internalClipboardPaste
    case internalClipboardClear
    case internalClipboardSearch
    case internalTimerStart
    case internalTimerStop
    case internalTimerReset
    case internalTimerSetDuration
    case internalScreenshotView
    case internalScreenshotSearch
    case internalScreenshotAnalyze
    case internalSettingChange
    case internalWindowShow
    case internalWindowHide
}

struct ActivityEvent: Identifiable, Codable {
    let id: Int
    let eventType: ActivityEventType
    let appBundleId: String?
    let appName: String?
    let windowTitle: String?
    let eventData: String? // JSON string for additional data
    let timestamp: Date
    let createdAt: Date
    
    init(id: Int = 0, eventType: ActivityEventType, appBundleId: String? = nil, appName: String? = nil, windowTitle: String? = nil, eventData: String? = nil, timestamp: Date = Date(), createdAt: Date = Date()) {
        self.id = id
        self.eventType = eventType
        self.appBundleId = appBundleId
        self.appName = appName
        self.windowTitle = windowTitle
        self.eventData = eventData
        self.timestamp = timestamp
        self.createdAt = createdAt
    }
}

struct AppSession: Identifiable, Codable {
    let id: String
    let appBundleId: String
    let appName: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var windowTitle: String?
    
    init(id: String = UUID().uuidString, appBundleId: String, appName: String, startTime: Date, endTime: Date? = nil, duration: TimeInterval = 0, windowTitle: String? = nil) {
        self.id = id
        self.appBundleId = appBundleId
        self.appName = appName
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.windowTitle = windowTitle
    }
}

// MARK: - Live Activity Models
struct LiveActivitySession: Identifiable {
    let id: String
    let appName: String
    let windowTitle: String?
    let startTime: Date
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    init(id: String = UUID().uuidString, appName: String, windowTitle: String? = nil, startTime: Date = Date()) {
        self.id = id
        self.appName = appName
        self.windowTitle = windowTitle
        self.startTime = startTime
    }
}

struct MeaningfulSession: Identifiable {
    let id: String
    let appName: String
    let windowTitle: String?
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    
    init(id: String = UUID().uuidString, appName: String, windowTitle: String? = nil, startTime: Date, endTime: Date) {
        self.id = id
        self.appName = appName
        self.windowTitle = windowTitle
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
    }
}

struct DistractedPeriod: Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let switchCount: Int
    
    init(id: String = UUID().uuidString, startTime: Date, endTime: Date, switchCount: Int) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.switchCount = switchCount
    }
}

struct ActivityStats: Codable {
    let totalEvents: Int
    let totalActiveTime: TimeInterval
    let topApps: [AppTime]
    let sessionsToday: Int
    
    struct AppTime: Codable {
        let appBundleId: String
        let appName: String
        let totalTime: TimeInterval
        let sessionCount: Int
    }
}

// MARK: - Timeline Models
enum TimeRange: String, CaseIterable {
    case today
    case last7Days
    case last30Days
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .last7Days: return "7 Days"
        case .last30Days: return "30 Days"
        }
    }
}

// MARK: - Category Summary Models
struct CategorySummary: Identifiable {
    let id: String
    let category: String
    let count: Int
    let duration: TimeInterval?
    let percentage: Double
    let icon: String
    let color: Color
    
    init(id: String = UUID().uuidString, category: String, count: Int, duration: TimeInterval? = nil, percentage: Double, icon: String, color: Color = .brutalistAccent) {
        self.id = id
        self.category = category
        self.count = count
        self.duration = duration
        self.percentage = percentage
        self.icon = icon
        self.color = color
    }
}

struct TimePeriodSummary: Identifiable {
    let id: String
    let period: String
    let startTime: Date
    let endTime: Date
    let appSummaries: [CategorySummary]
    let eventTypeSummaries: [CategorySummary]
    let totalEvents: Int
    
    init(id: String = UUID().uuidString, period: String, startTime: Date, endTime: Date, appSummaries: [CategorySummary], eventTypeSummaries: [CategorySummary], totalEvents: Int) {
        self.id = id
        self.period = period
        self.startTime = startTime
        self.endTime = endTime
        self.appSummaries = appSummaries
        self.eventTypeSummaries = eventTypeSummaries
        self.totalEvents = totalEvents
    }
}

// MARK: - Chart Data Models
struct ChartDataPoint: Identifiable {
    let id: String
    let time: Date
    let value: Double
    let category: String
    
    init(id: String = UUID().uuidString, time: Date, value: Double, category: String) {
        self.id = id
        self.time = time
        self.value = value
        self.category = category
    }
}

struct ChartSeries: Identifiable {
    let id: String
    let category: String
    let color: Color
    let dataPoints: [ChartDataPoint]
    
    init(id: String = UUID().uuidString, category: String, color: Color, dataPoints: [ChartDataPoint]) {
        self.id = id
        self.category = category
        self.color = color
        self.dataPoints = dataPoints
    }
}

struct TimelineBucket: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let eventCount: Int
    let activeMinutes: Int
    let topApp: String?
    let intensity: Double // 0.0-1.0 for visual weight
    
    init(startTime: Date, endTime: Date, eventCount: Int, activeMinutes: Int = 0, topApp: String? = nil, intensity: Double = 0.0) {
        self.startTime = startTime
        self.endTime = endTime
        self.eventCount = eventCount
        self.activeMinutes = activeMinutes
        self.topApp = topApp
        self.intensity = intensity
    }
}

// MARK: - App State
enum AppTab: String {
    case notes
    case clipboard
    case screenshots
    case agents
    case activity
}

