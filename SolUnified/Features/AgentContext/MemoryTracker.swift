//
//  MemoryTracker.swift
//  SolUnified
//
//  Token-efficient change tracking for agent memory
//

import Foundation
import Combine
import CryptoKit

struct DataSourceDelta: Codable {
    let sourceType: String
    let newCount: Int
    let changeDescription: String
    let timestamp: String
    let significanceScore: Double // 0-1, higher = more important
}

struct SmartSummary: Codable {
    let sessionType: String // "coding", "research", "communication", "idle"
    let focusAreas: [String]
    let productivityScore: Double
    let contextShifts: Int
    let keyInsights: [String]
}

class MemoryTracker: ObservableObject {
    static let shared = MemoryTracker()
    
    @Published var lastCheck: Date = Date()
    @Published var recentDeltas: [DataSourceDelta] = []
    
    private let contextPath = "/Users/savarsareen/coding/mable/sol-unified/ai_context.json"
    private let bridgePath = "/Users/savarsareen/coding/research/agent_bridge.json"
    private var cancellables = Set<AnyCancellable>()
    
    private let screenshotsStore = ScreenshotsStore.shared
    private let clipboardStore = ClipboardStore.shared
    
    private init() {
        startTracking()
    }
    
    func generateMemoryUpdate() -> [String: Any] {
        let now = Date()
        let windowStart = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
        
        // Get current counts and generate deltas
        let screenshotDelta = generateScreenshotDelta(since: windowStart)
        let clipboardDelta = generateClipboardDelta(since: windowStart)
        let noteDelta = generateNoteDelta(since: windowStart)
        let activitySummary = generateActivitySummary(since: windowStart)
        
        // Generate smart summary
        let smartSummary = generateSmartSummary([screenshotDelta, clipboardDelta, noteDelta])
        
        let memoryUpdate: [String: Any] = [
            "last_check": ISO8601DateFormatter().string(from: now),
            "change_window": "1h",
            "data_sources": [
                "screenshots": [
                    "last_count": getCurrentScreenshotCount(),
                    "last_hash": getScreenshotsHash(),
                    "new_since_check": screenshotDelta.newCount,
                    "recent_activity": screenshotDelta.changeDescription
                ],
                "clipboard": [
                    "last_count": getCurrentClipboardCount(),
                    "last_hash": getClipboardHash(),
                    "new_since_check": clipboardDelta.newCount,
                    "recent_activity": clipboardDelta.changeDescription
                ],
                "notes": [
                    "last_count": getCurrentNoteCount(),
                    "last_hash": getNotesHash(),
                    "new_since_check": noteDelta.newCount,
                    "recent_activity": noteDelta.changeDescription
                ],
                "activity": activitySummary
            ],
            "smart_summary": [
                "session_type": smartSummary.sessionType,
                "focus_areas": smartSummary.focusAreas,
                "productivity_score": smartSummary.productivityScore,
                "context_shifts": smartSummary.contextShifts,
                "key_insights": smartSummary.keyInsights
            ]
        ]
        
        return memoryUpdate
    }
    
    func updateContextFile() {
        guard let currentData = loadCurrentContext() else { return }
        
        var updatedContext = currentData
        updatedContext["memory"] = generateMemoryUpdate()
        updatedContext["last_update"] = ISO8601DateFormatter().string(from: Date())
        
        saveContextFile(updatedContext)
        updateAgentBridge()
    }
    
    func updateAgentBridge() {
        guard let bridgeData = loadAgentBridge() else { return }
        
        var updatedBridge = bridgeData
        let memoryUpdate = generateMemoryUpdate()
        
        // Add memory intelligence to the bridge
        updatedBridge["sol_unified_memory"] = [
            "data_activity": extractDataActivity(from: memoryUpdate),
            "user_context": extractUserContext(from: memoryUpdate),
            "productivity_signals": extractProductivitySignals(from: memoryUpdate),
            "opportunity_indicators": extractOpportunityIndicators(from: memoryUpdate)
        ]
        
        saveBridgeFile(updatedBridge)
    }
    
    // MARK: - Delta Generation
    
    private func generateScreenshotDelta(since: Date) -> DataSourceDelta {
        // This would query the database for screenshots created since the timestamp
        let recentCount = 0 // TODO: Implement actual query
        let description = recentCount > 0 ? "\(recentCount) new screenshots" : "No new screenshots"
        let significance = min(Double(recentCount) / 10.0, 1.0) // Scale 0-1
        
        return DataSourceDelta(
            sourceType: "screenshots",
            newCount: recentCount,
            changeDescription: description,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            significanceScore: significance
        )
    }
    
    private func generateClipboardDelta(since: Date) -> DataSourceDelta {
        let recentCount = 0 // TODO: Implement actual query
        let description = recentCount > 0 ? "\(recentCount) new clipboard items" : "No new clipboard items"
        let significance = min(Double(recentCount) / 20.0, 1.0)
        
        return DataSourceDelta(
            sourceType: "clipboard",
            newCount: recentCount,
            changeDescription: description,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            significanceScore: significance
        )
    }
    
    private func generateNoteDelta(since: Date) -> DataSourceDelta {
        let recentCount = 0 // TODO: Implement actual query
        let description = recentCount > 0 ? "\(recentCount) notes updated" : "No note changes"
        let significance = min(Double(recentCount) / 5.0, 1.0)
        
        return DataSourceDelta(
            sourceType: "notes",
            newCount: recentCount,
            changeDescription: description,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            significanceScore: significance
        )
    }
    
    private func generateActivitySummary(since: Date) -> [String: Any] {
        // TODO: Query activity database for recent app usage
        return [
            "last_active_app": "",
            "session_duration": "0m",
            "key_events": []
        ]
    }
    
    private func generateSmartSummary(_ deltas: [DataSourceDelta]) -> SmartSummary {
        let totalActivity = deltas.reduce(0) { $0 + $1.significanceScore }
        
        let sessionType: String
        if totalActivity > 0.7 {
            sessionType = "active"
        } else if totalActivity > 0.3 {
            sessionType = "moderate"
        } else {
            sessionType = "idle"
        }
        
        let focusAreas = deltas
            .filter { $0.significanceScore > 0.3 }
            .map { $0.sourceType }
        
        return SmartSummary(
            sessionType: sessionType,
            focusAreas: focusAreas,
            productivityScore: min(totalActivity, 1.0),
            contextShifts: focusAreas.count,
            keyInsights: [] // TODO: Implement pattern detection
        )
    }
    
    // MARK: - Data Source Queries
    
    private func getCurrentScreenshotCount() -> Int {
        return screenshotsStore.screenshots.count
    }
    
    private func getCurrentClipboardCount() -> Int {
        return clipboardStore.items.count
    }
    
    private func getCurrentNoteCount() -> Int {
        // TODO: Implement notes count
        return 0
    }
    
    private func getScreenshotsHash() -> String {
        let data = screenshotsStore.screenshots.map { $0.filename }.joined()
        return hashString(data)
    }
    
    private func getClipboardHash() -> String {
        let data = clipboardStore.items.map { $0.contentHash }.joined()
        return hashString(data)
    }
    
    private func getNotesHash() -> String {
        // TODO: Implement notes hash
        return ""
    }
    
    private func hashString(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Intelligence Extraction
    
    private func extractDataActivity(from memoryUpdate: [String: Any]) -> [String: Any] {
        let dataSources = memoryUpdate["data_sources"] as? [String: Any] ?? [:]
        var activity: [String] = []
        
        for (source, data) in dataSources {
            if let sourceData = data as? [String: Any],
               let newCount = sourceData["new_since_check"] as? Int,
               newCount > 0 {
                activity.append("\(source): \(newCount) new items")
            }
        }
        
        return [
            "summary": activity.isEmpty ? "No recent activity" : activity.joined(separator: ", "),
            "active_sources": activity.count,
            "total_new_items": dataSources.values.compactMap { ($0 as? [String: Any])?["new_since_check"] as? Int }.reduce(0, +)
        ]
    }
    
    private func extractUserContext(from memoryUpdate: [String: Any]) -> [String: Any] {
        let smartSummary = memoryUpdate["smart_summary"] as? [String: Any] ?? [:]
        let sessionType = smartSummary["session_type"] as? String ?? "idle"
        let focusAreas = smartSummary["focus_areas"] as? [String] ?? []
        
        return [
            "session_type": sessionType,
            "focus_areas": focusAreas,
            "engagement_level": sessionType == "active" ? "high" : sessionType == "moderate" ? "medium" : "low",
            "context_stability": focusAreas.count <= 2 ? "focused" : "scattered"
        ]
    }
    
    private func extractProductivitySignals(from memoryUpdate: [String: Any]) -> [String: Any] {
        let smartSummary = memoryUpdate["smart_summary"] as? [String: Any] ?? [:]
        let productivityScore = smartSummary["productivity_score"] as? Double ?? 0.0
        let contextShifts = smartSummary["context_shifts"] as? Int ?? 0
        
        let signals: [String] = [
            productivityScore > 0.7 ? "High productivity detected" : nil,
            contextShifts > 3 ? "Multiple context switches" : nil,
            productivityScore < 0.2 ? "Low activity period" : nil
        ].compactMap { $0 }
        
        return [
            "score": productivityScore,
            "signals": signals,
            "recommended_action": productivityScore > 0.5 ? "Maintain momentum" : "Consider break or focus shift"
        ]
    }
    
    private func extractOpportunityIndicators(from memoryUpdate: [String: Any]) -> [String: Any] {
        let dataSources = memoryUpdate["data_sources"] as? [String: Any] ?? [:]
        let screenshotData = dataSources["screenshots"] as? [String: Any] ?? [:]
        let clipboardData = dataSources["clipboard"] as? [String: Any] ?? [:]
        
        let screenshotCount = screenshotData["new_since_check"] as? Int ?? 0
        let clipboardCount = clipboardData["new_since_check"] as? Int ?? 0
        
        var opportunities: [String] = []
        
        if screenshotCount > 5 {
            opportunities.append("High screenshot activity - potential design/research work")
        }
        if clipboardCount > 10 {
            opportunities.append("High clipboard usage - potential content creation")
        }
        if screenshotCount > 0 && clipboardCount > 0 {
            opportunities.append("Mixed activity - potential learning/documentation work")
        }
        
        return [
            "indicators": opportunities,
            "content_creation_signal": clipboardCount > 5 ? "high" : "low",
            "research_signal": screenshotCount > 3 ? "high" : "low"
        ]
    }
    
    // MARK: - File Operations
    
    private func loadCurrentContext() -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: contextPath) else { return nil }
        
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            print("Error loading context: \(error)")
            return nil
        }
    }
    
    private func loadAgentBridge() -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: bridgePath) else { return nil }
        
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            print("Error loading agent bridge: \(error)")
            return nil
        }
    }
    
    private func saveContextFile(_ context: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: context, options: .prettyPrinted)
            try data.write(to: URL(fileURLWithPath: contextPath))
            print("✅ Updated ai_context.json with memory deltas")
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    private func saveBridgeFile(_ bridge: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: bridge, options: .prettyPrinted)
            try data.write(to: URL(fileURLWithPath: bridgePath))
            print("✅ Updated agent_bridge.json with memory intelligence")
        } catch {
            print("Error saving bridge: \(error)")
        }
    }
    
    // MARK: - Tracking
    
    private func startTracking() {
        // Update memory every 5 minutes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.updateContextFile()
            }
            .store(in: &cancellables)
    }
}