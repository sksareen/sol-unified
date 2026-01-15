//
//  Models.swift
//  SolUnified v2.0
//
//  Data models - simplified for v2 focus-centric architecture
//

import Foundation
import SwiftUI

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

    // Source context metadata
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

    // Provenance metadata
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

    // Drift tracking
    case driftRecovery = "drift_recovery"
    case driftBreak = "drift_break"
}

struct ActivityEvent: Identifiable, Codable {
    let id: Int
    let eventType: ActivityEventType
    let appBundleId: String?
    let appName: String?
    let windowTitle: String?
    let eventData: String?
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

// MARK: - App Session

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

// MARK: - Context Node (for context graph)

enum ContextType: String, Codable, CaseIterable {
    case deepWork = "deep_work"
    case exploration
    case communication
    case creative
    case administrative
    case leisure
    case unknown

    var displayName: String {
        switch self {
        case .deepWork: return "Deep Work"
        case .exploration: return "Exploration"
        case .communication: return "Communication"
        case .creative: return "Creative"
        case .administrative: return "Administrative"
        case .leisure: return "Leisure"
        case .unknown: return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .deepWork: return .blue
        case .exploration: return .purple
        case .communication: return .green
        case .creative: return .orange
        case .administrative: return .gray
        case .leisure: return .pink
        case .unknown: return .secondary
        }
    }
}

struct ContextNode: Identifiable {
    let id: String
    var label: String
    var type: ContextType
    let startTime: Date
    var endTime: Date?
    var focusScore: Double
    var apps: Set<String>
    var windowTitles: Set<String>
    var eventCount: Int
    var clipboardItemHashes: Set<String>
    var screenshotFilenames: Set<String>

    var isActive: Bool { endTime == nil }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    init(
        id: String = UUID().uuidString,
        label: String = "",
        type: ContextType = .unknown,
        startTime: Date = Date(),
        endTime: Date? = nil,
        focusScore: Double = 1.0,
        apps: Set<String> = [],
        windowTitles: Set<String> = [],
        eventCount: Int = 0,
        clipboardItemHashes: Set<String> = [],
        screenshotFilenames: Set<String> = []
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.focusScore = focusScore
        self.apps = apps
        self.windowTitles = windowTitles
        self.eventCount = eventCount
        self.clipboardItemHashes = clipboardItemHashes
        self.screenshotFilenames = screenshotFilenames
    }
}

// MARK: - App Tab (minimal for v2)

enum AppTab: String {
    case settings
}
