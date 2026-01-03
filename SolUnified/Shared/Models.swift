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
    
    // Source context metadata (captured at copy time)
    let sourceAppBundleId: String?
    let sourceAppName: String?
    let sourceWindowTitle: String?
    
    init(id: Int = 0, contentType: ContentType, contentText: String? = nil, contentPreview: String? = nil, filePath: String? = nil, contentHash: String, createdAt: Date = Date(), sourceAppBundleId: String? = nil, sourceAppName: String? = nil, sourceWindowTitle: String? = nil) {
        self.id = id
        self.contentType = contentType
        self.contentText = contentText
        self.contentPreview = contentPreview
        self.filePath = filePath
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.sourceAppBundleId = sourceAppBundleId
        self.sourceAppName = sourceAppName
        self.sourceWindowTitle = sourceWindowTitle
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
    
    // Provenance metadata - what was active when screenshot was taken
    var sourceAppBundleId: String?
    var sourceAppName: String?
    var sourceWindowTitle: String?
    
    init(id: Int = 0, filename: String, filepath: String, fileHash: String, fileSize: Int, createdAt: Date, modifiedAt: Date, width: Int, height: Int, aiDescription: String? = nil, aiTags: String? = nil, aiTextContent: String? = nil, analyzedAt: Date? = nil, analysisModel: String? = nil, sourceAppBundleId: String? = nil, sourceAppName: String? = nil, sourceWindowTitle: String? = nil) {
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
        self.sourceAppBundleId = sourceAppBundleId
        self.sourceAppName = sourceAppName
        self.sourceWindowTitle = sourceWindowTitle
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
    
    // Data Capture - Emotional Detection & Guidance
    case biofeedbackLog // Heart rate, HRV, etc.
    case emotionLog // User self-reported emotion
    
    // Data Capture - Personalized Learning
    case learningTargetSet
    case learningTargetMet
    case learningTargetMissed
    
    // Data Capture - Productivity & Outcomes
    case outcomeLogged // Tangible achievement
    case productivityMetric // Generic metric
    
    // Data Capture - Mental Health & Wellness
    case reflectionLog
    case mindfulnessSessionStart
    case mindfulnessSessionEnd
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
    let sequenceId: String? // Optional link to a specific sequence/session
    
    init(id: Int = 0, eventType: ActivityEventType, appBundleId: String? = nil, appName: String? = nil, windowTitle: String? = nil, eventData: String? = nil, timestamp: Date = Date(), createdAt: Date = Date(), sequenceId: String? = nil) {
        self.id = id
        self.eventType = eventType
        self.appBundleId = appBundleId
        self.appName = appName
        self.windowTitle = windowTitle
        self.eventData = eventData
        self.timestamp = timestamp
        self.createdAt = createdAt
        self.sequenceId = sequenceId
    }
}

// MARK: - Sequence Models
struct Sequence: Identifiable, Codable {
    let id: String
    let type: SequenceType
    let startTime: Date
    var endTime: Date?
    var status: SequenceStatus
    var metadata: String? // JSON string for goals, context
    
    init(id: String = UUID().uuidString, type: SequenceType, startTime: Date = Date(), endTime: Date? = nil, status: SequenceStatus = .active, metadata: String? = nil) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.metadata = metadata
    }
}

enum SequenceType: String, Codable {
    case workSession
    case learningBlock
    case mindfulness
    case reflection
    case custom
}

enum SequenceStatus: String, Codable {
    case active
    case completed
    case abandoned
    case paused
}

// MARK: - Data Capture Payloads (Serialized to eventData)
struct BiofeedbackPayload: Codable {
    let type: String // "heart_rate", "hrv", "breathing_rate"
    let value: Double
    let unit: String
    let source: String?
}

struct EmotionPayload: Codable {
    let valence: Double // -1.0 to 1.0 (negative to positive)
    let arousal: Double // 0.0 to 1.0 (calm to excited)
    let label: String? // "happy", "anxious", etc.
    let note: String?
}

struct LearningTargetPayload: Codable {
    let targetId: String
    let description: String
    let targetType: String // "time_bound", "unbounded"
    let capacityRequired: Double? // Estimated capacity needed
}

struct OutcomePayload: Codable {
    let outcomeId: String
    let description: String
    let value: Double? // Quantifiable value if applicable
    let tags: [String]?
}

struct ReflectionPayload: Codable {
    let prompt: String?
    let response: String
    let tags: [String]?
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

// MARK: - Agent Task Models
struct AgentTask: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    var assignedTo: String
    var status: String
    let priority: String
    let createdAt: Date
    var updatedAt: Date
    var project: String
    
    init(id: String, title: String, description: String, assignedTo: String, status: String, priority: String, createdAt: Date, updatedAt: Date, project: String) {
        self.id = id
        self.title = title
        self.description = description
        self.assignedTo = assignedTo
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.project = project
    }
}

struct AgentStateFile: Codable {
    let version: String
    let lastUpdated: String
    let systemStatus: String
    let activeProjects: [String: ProjectInfo]
    let activeAgents: [String: AgentInfo]
    let sharedContext: SharedContext
    let tasks: [String: AgentTask]
    
    enum CodingKeys: String, CodingKey {
        case version
        case lastUpdated = "last_updated"
        case systemStatus = "system_status"
        case activeProjects = "active_projects"
        case activeAgents = "active_agents"
        case sharedContext = "shared_context"
        case tasks
    }
    
    struct ProjectInfo: Codable {
        let status: String
        let priority: String
    }
    
    struct AgentInfo: Codable {
        let lastActive: String?
        let currentFocus: String
        let status: String
        
        enum CodingKeys: String, CodingKey {
            case lastActive = "last_active"
            case currentFocus = "current_focus"
            case status
        }
    }
    
    struct SharedContext: Codable {
        let communicationSystem: String
        let messageLog: String
        let stateFile: String
        let archiveDir: String
        let joshSystem: String
        let bridgeLegacy: String
        
        enum CodingKeys: String, CodingKey {
            case communicationSystem = "communication_system"
            case messageLog = "message_log"
            case stateFile = "state_file"
            case archiveDir = "archive_dir"
            case joshSystem = "josh_system"
            case bridgeLegacy = "bridge_legacy"
        }
    }
}

// MARK: - App State
enum AppTab: String {
    case tasks
    case agents
    case vault
    case context
    case terminal
}

