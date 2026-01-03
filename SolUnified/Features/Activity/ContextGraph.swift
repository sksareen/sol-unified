//
//  ContextGraph.swift
//  SolUnified
//
//  Context Graph: Tracks work contexts, sequences, and relationships between activities
//  This builds a semantic understanding of what the user is working on
//

import Foundation
import SwiftUI

// MARK: - Context Node

/// A context node represents a coherent unit of work or focus
struct ContextNode: Identifiable, Codable {
    let id: String
    var label: String                    // Human-readable label (e.g., "Working on Sol Unified")
    var type: ContextType                // Type of context
    var startTime: Date
    var endTime: Date?
    var isActive: Bool
    
    // Metadata
    var apps: Set<String>                // Apps used in this context
    var windowTitles: [String]           // Window titles seen
    var eventCount: Int                  // Number of events in this context
    var focusScore: Double               // 0-1 representing focus quality
    
    // Relationships
    var parentContextId: String?         // Parent context (for hierarchical contexts)
    var relatedContextIds: [String]      // Related contexts (same project, etc.)
    
    // Content links
    var clipboardItemHashes: [String]    // Linked clipboard items
    var screenshotFilenames: [String]    // Linked screenshots
    var noteIds: [Int]                   // Linked notes
    
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    init(id: String = UUID().uuidString, label: String, type: ContextType, startTime: Date = Date()) {
        self.id = id
        self.label = label
        self.type = type
        self.startTime = startTime
        self.endTime = nil
        self.isActive = true
        self.apps = []
        self.windowTitles = []
        self.eventCount = 0
        self.focusScore = 0.0
        self.parentContextId = nil
        self.relatedContextIds = []
        self.clipboardItemHashes = []
        self.screenshotFilenames = []
        self.noteIds = []
    }
}

enum ContextType: String, Codable, CaseIterable {
    case deepWork           // Focused work session (1+ app, 10+ min)
    case exploration        // Browsing, researching (many tabs/apps)
    case communication      // Email, Slack, Messages
    case creative           // Design, writing, coding
    case administrative     // Settings, system tasks
    case leisure            // Entertainment, social media
    case unknown            // Unclassified
    
    var icon: String {
        switch self {
        case .deepWork: return "brain.head.profile"
        case .exploration: return "safari"
        case .communication: return "bubble.left.and.bubble.right"
        case .creative: return "paintbrush"
        case .administrative: return "gearshape.2"
        case .leisure: return "gamecontroller"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .deepWork: return Color(hex: "#10b981")      // Green
        case .exploration: return Color(hex: "#3b82f6")    // Blue
        case .communication: return Color(hex: "#8b5cf6")  // Purple
        case .creative: return Color(hex: "#ec4899")       // Pink
        case .administrative: return Color(hex: "#6b7280") // Gray
        case .leisure: return Color(hex: "#f59e0b")        // Amber
        case .unknown: return Color(hex: "#9ca3af")        // Light gray
        }
    }
}

// MARK: - Context Edge

/// An edge represents a transition or relationship between contexts
struct ContextEdge: Identifiable, Codable {
    let id: String
    let fromContextId: String
    let toContextId: String
    let edgeType: ContextEdgeType
    let timestamp: Date
    var metadata: [String: String]
    
    init(from: String, to: String, type: ContextEdgeType, metadata: [String: String] = [:]) {
        self.id = UUID().uuidString
        self.fromContextId = from
        self.toContextId = to
        self.edgeType = type
        self.timestamp = Date()
        self.metadata = metadata
    }
}

enum ContextEdgeType: String, Codable {
    case transitionedTo     // User switched from one context to another
    case interruptedBy      // Context was interrupted
    case resumedFrom        // Context resumed from previous
    case spawned            // One context spawned another (e.g., research -> coding)
    case related            // Contexts are semantically related
    case parentChild        // Hierarchical relationship
}

// MARK: - Enhanced Event Metadata

/// Extended metadata captured for richer context building
struct EnhancedEventMetadata: Codable {
    // URL Context
    var url: String?                     // Current URL if browser
    var urlDomain: String?               // Domain of URL
    
    // Document Context
    var documentPath: String?            // Path to open document
    var documentName: String?            // Name of document
    
    // Selection Context
    var hasSelection: Bool               // Whether text is selected
    var selectionPreview: String?        // First 100 chars of selection
    
    // Content Hashes (for correlation)
    var contentHash: String?             // Hash of clipboard/screenshot content
    
    // Input Metrics
    var keyPressCount: Int               // Keys pressed in this window session
    var mouseClickCount: Int             // Clicks in this window session
    var scrollDistance: Double           // Total scroll distance
    
    // Timing
    var windowFocusDuration: TimeInterval // How long this window has been focused
    var idleTimeInWindow: TimeInterval   // Time spent idle in this window
    
    init() {
        self.url = nil
        self.urlDomain = nil
        self.documentPath = nil
        self.documentName = nil
        self.hasSelection = false
        self.selectionPreview = nil
        self.contentHash = nil
        self.keyPressCount = 0
        self.mouseClickCount = 0
        self.scrollDistance = 0
        self.windowFocusDuration = 0
        self.idleTimeInWindow = 0
    }
}

// MARK: - Context Graph Manager

class ContextGraphManager: ObservableObject {
    static let shared = ContextGraphManager()
    
    @Published var nodes: [ContextNode] = []
    @Published var edges: [ContextEdge] = []
    @Published var activeContext: ContextNode?
    @Published var currentMetadata = EnhancedEventMetadata()
    
    private let db = Database.shared
    private var contextDetectionTimer: Timer?
    
    // Pattern detection state
    private var recentApps: [(bundleId: String, appName: String, time: Date)] = []
    private var windowSessionStart: Date?
    private var windowKeyPresses: Int = 0
    private var windowMouseClicks: Int = 0
    private var windowScrollDistance: Double = 0
    
    // App categorization for context type inference
    private let appCategories: [String: ContextType] = [
        // Deep work / Creative
        "com.microsoft.VSCode": .creative,
        "com.apple.dt.Xcode": .creative,
        "com.jetbrains.intellij": .creative,
        "com.sublimetext": .creative,
        "com.figma.Desktop": .creative,
        "com.adobe.Photoshop": .creative,
        "com.adobe.illustrator": .creative,
        "com.notion.id": .creative,
        "com.obsidian": .creative,
        
        // Communication
        "com.apple.MobileSMS": .communication,
        "com.apple.mail": .communication,
        "com.tinyspeck.slackmacgap": .communication,
        "com.microsoft.Outlook": .communication,
        "us.zoom.xos": .communication,
        "com.microsoft.teams2": .communication,
        "com.hnc.Discord": .communication,
        
        // Exploration
        "com.apple.Safari": .exploration,
        "com.google.Chrome": .exploration,
        "com.brave.Browser": .exploration,
        "org.mozilla.firefox": .exploration,
        "com.microsoft.edgemac": .exploration,
        
        // Administrative
        "com.apple.systempreferences": .administrative,
        "com.apple.finder": .administrative,
        "com.apple.ActivityMonitor": .administrative,
        
        // Leisure
        "com.spotify.client": .leisure,
        "com.apple.Music": .leisure,
        "com.netflix": .leisure,
        "com.apple.TV": .leisure,
        "tv.twitch": .leisure
    ]
    
    private init() {
        loadContextGraph()
    }
    
    // MARK: - Context Detection
    
    func startContextDetection() {
        contextDetectionTimer?.invalidate()
        
        contextDetectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.analyzeAndUpdateContext()
        }
        
        if let timer = contextDetectionTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("🧠 Context graph detection started")
    }
    
    func stopContextDetection() {
        contextDetectionTimer?.invalidate()
        contextDetectionTimer = nil
        
        // Close active context
        if var active = activeContext {
            active.endTime = Date()
            active.isActive = false
            updateNode(active)
            activeContext = nil
        }
        
        print("🧠 Context graph detection stopped")
    }
    
    // MARK: - Event Processing
    
    /// Process an activity event and update context graph
    func processEvent(_ event: ActivityEvent) {
        // Update recent apps tracking
        if let bundleId = event.appBundleId, let appName = event.appName {
            recentApps.append((bundleId: bundleId, appName: appName, time: event.timestamp))
            // Keep last 50 events
            if recentApps.count > 50 {
                recentApps.removeFirst()
            }
        }
        
        // Update window-level metrics
        switch event.eventType {
        case .keyPress:
            windowKeyPresses += 1
            currentMetadata.keyPressCount = windowKeyPresses
        case .mouseClick:
            windowMouseClicks += 1
            currentMetadata.mouseClickCount = windowMouseClicks
        case .mouseScroll:
            if let data = event.eventData,
               let json = try? JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: Any],
               let delta = json["delta"] as? Double {
                windowScrollDistance += abs(delta)
                currentMetadata.scrollDistance = windowScrollDistance
            }
        case .appActivate, .windowTitleChange:
            // Reset window metrics on app/window switch
            windowKeyPresses = 0
            windowMouseClicks = 0
            windowScrollDistance = 0
            windowSessionStart = event.timestamp
            
            // Extract URL from window title if browser
            if let bundleId = event.appBundleId, isBrowser(bundleId) {
                if let title = event.windowTitle {
                    currentMetadata.url = extractURLFromTitle(title)
                    currentMetadata.urlDomain = extractDomain(from: currentMetadata.url)
                }
            }
            
            // Update active context
            updateActiveContext(for: event)
        default:
            break
        }
        
        // Update window focus duration
        if let start = windowSessionStart {
            currentMetadata.windowFocusDuration = Date().timeIntervalSince(start)
        }
    }
    
    /// Link a clipboard item to the current context
    func linkClipboardItem(hash: String) {
        guard var active = activeContext else { return }
        if !active.clipboardItemHashes.contains(hash) {
            active.clipboardItemHashes.append(hash)
            updateNode(active)
        }
    }
    
    /// Link a screenshot to the current context
    func linkScreenshot(filename: String) {
        guard var active = activeContext else { return }
        if !active.screenshotFilenames.contains(filename) {
            active.screenshotFilenames.append(filename)
            updateNode(active)
        }
    }
    
    /// Link a note to the current context
    func linkNote(id: Int) {
        guard var active = activeContext else { return }
        if !active.noteIds.contains(id) {
            active.noteIds.append(id)
            updateNode(active)
        }
    }
    
    // MARK: - Context Analysis
    
    private func analyzeAndUpdateContext() {
        guard !recentApps.isEmpty else { return }
        
        let now = Date()
        let last5Min = recentApps.filter { now.timeIntervalSince($0.time) <= 300 }
        
        guard !last5Min.isEmpty else { return }
        
        // Analyze app usage patterns
        let uniqueApps = Set(last5Min.map { $0.bundleId })
        let dominantApp = findDominantApp(in: last5Min)
        let contextType = inferContextType(apps: uniqueApps, dominantApp: dominantApp)
        
        // Calculate focus score (fewer app switches = higher focus)
        let switchCount = countAppSwitches(in: last5Min)
        let focusScore = max(0, 1.0 - (Double(switchCount) / 10.0))
        
        // Generate context label
        let label = generateContextLabel(dominantApp: dominantApp, type: contextType, apps: uniqueApps)
        
        // Check if context changed
        if let active = activeContext {
            let sameContext = active.type == contextType && 
                              active.apps.intersection(uniqueApps).count > uniqueApps.count / 2
            
            if !sameContext {
                // Context switched - close old, create new
                var closedContext = active
                closedContext.endTime = now
                closedContext.isActive = false
                updateNode(closedContext)
                
                let newContext = createContext(label: label, type: contextType, apps: uniqueApps, focusScore: focusScore)
                
                // Create transition edge
                let edge = ContextEdge(
                    from: active.id,
                    to: newContext.id,
                    type: .transitionedTo,
                    metadata: ["trigger": "app_switch"]
                )
                addEdge(edge)
                
                activeContext = newContext
            } else {
                // Same context - update metrics
                var updated = active
                updated.apps = updated.apps.union(uniqueApps)
                updated.eventCount += last5Min.count
                updated.focusScore = (updated.focusScore + focusScore) / 2
                updateNode(updated)
                activeContext = updated
            }
        } else {
            // No active context - create new
            activeContext = createContext(label: label, type: contextType, apps: uniqueApps, focusScore: focusScore)
        }
    }
    
    private func updateActiveContext(for event: ActivityEvent) {
        guard var active = activeContext else { return }
        
        if let bundleId = event.appBundleId {
            active.apps.insert(bundleId)
        }
        
        if let title = event.windowTitle, !title.isEmpty {
            if !active.windowTitles.contains(title) {
                active.windowTitles.append(title)
                // Keep last 10 window titles
                if active.windowTitles.count > 10 {
                    active.windowTitles.removeFirst()
                }
            }
        }
        
        active.eventCount += 1
        updateNode(active)
        activeContext = active
    }
    
    private func createContext(label: String, type: ContextType, apps: Set<String>, focusScore: Double) -> ContextNode {
        var node = ContextNode(label: label, type: type)
        node.apps = apps
        node.focusScore = focusScore
        addNode(node)
        return node
    }
    
    // MARK: - Helper Methods
    
    private func findDominantApp(in events: [(bundleId: String, appName: String, time: Date)]) -> (bundleId: String, appName: String)? {
        var counts: [String: (name: String, count: Int)] = [:]
        
        for event in events {
            if var existing = counts[event.bundleId] {
                existing.count += 1
                counts[event.bundleId] = existing
            } else {
                counts[event.bundleId] = (name: event.appName, count: 1)
            }
        }
        
        guard let top = counts.max(by: { $0.value.count < $1.value.count }) else { return nil }
        return (bundleId: top.key, appName: top.value.name)
    }
    
    private func countAppSwitches(in events: [(bundleId: String, appName: String, time: Date)]) -> Int {
        var switches = 0
        var lastApp: String?
        
        for event in events {
            if let last = lastApp, last != event.bundleId {
                switches += 1
            }
            lastApp = event.bundleId
        }
        
        return switches
    }
    
    private func inferContextType(apps: Set<String>, dominantApp: (bundleId: String, appName: String)?) -> ContextType {
        guard let dominant = dominantApp else { return .unknown }
        
        // Check if dominant app has a category
        if let category = appCategories[dominant.bundleId] {
            return category
        }
        
        // Infer from app mix
        let categoryScores: [ContextType: Int] = apps.reduce(into: [:]) { scores, bundleId in
            if let category = appCategories[bundleId] {
                scores[category, default: 0] += 1
            }
        }
        
        return categoryScores.max(by: { $0.value < $1.value })?.key ?? .unknown
    }
    
    private func generateContextLabel(dominantApp: (bundleId: String, appName: String)?, type: ContextType, apps: Set<String>) -> String {
        guard let dominant = dominantApp else { return "Unknown Activity" }
        
        switch type {
        case .deepWork:
            return "Deep work in \(dominant.appName)"
        case .exploration:
            return "Browsing in \(dominant.appName)"
        case .communication:
            return "Communication via \(dominant.appName)"
        case .creative:
            return "Creating in \(dominant.appName)"
        case .administrative:
            return "System tasks"
        case .leisure:
            return "Entertainment"
        case .unknown:
            return "Working in \(dominant.appName)"
        }
    }
    
    private func isBrowser(_ bundleId: String) -> Bool {
        let browsers = ["com.apple.Safari", "com.google.Chrome", "com.brave.Browser", "org.mozilla.firefox", "com.microsoft.edgemac"]
        return browsers.contains(bundleId)
    }
    
    private func extractURLFromTitle(_ title: String) -> String? {
        // Common browser title patterns: "Page Title - Browser Name" or "Page Title | Site"
        // For GitHub: "username/repo: description · GitHub"
        // This is a heuristic - real URL extraction would need browser integration
        return nil
    }
    
    private func extractDomain(from url: String?) -> String? {
        guard let url = url, let urlObj = URL(string: url) else { return nil }
        return urlObj.host
    }
    
    // MARK: - Persistence
    
    private func loadContextGraph() {
        // Load recent nodes from database
        let results = db.query("""
            SELECT * FROM context_nodes 
            WHERE start_time > datetime('now', '-7 days')
            ORDER BY start_time DESC
            LIMIT 100
        """)
        
        nodes = results.compactMap { nodeFromRow($0) }
        
        // Load edges
        let edgeResults = db.query("""
            SELECT * FROM context_edges
            WHERE timestamp > datetime('now', '-7 days')
            ORDER BY timestamp DESC
            LIMIT 200
        """)
        
        edges = edgeResults.compactMap { edgeFromRow($0) }
        
        // Find active context
        activeContext = nodes.first { $0.isActive }
    }
    
    private func addNode(_ node: ContextNode) {
        nodes.insert(node, at: 0)
        
        // Persist to database
        guard let appsJson = try? JSONEncoder().encode(Array(node.apps)),
              let appsString = String(data: appsJson, encoding: .utf8),
              let windowsJson = try? JSONEncoder().encode(node.windowTitles),
              let windowsString = String(data: windowsJson, encoding: .utf8) else {
            return
        }
        
        _ = db.execute("""
            INSERT INTO context_nodes 
            (id, label, type, start_time, end_time, is_active, apps, window_titles, event_count, focus_score, parent_context_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            node.id,
            node.label,
            node.type.rawValue,
            Database.dateToString(node.startTime),
            node.endTime.map { Database.dateToString($0) } ?? NSNull(),
            node.isActive ? 1 : 0,
            appsString,
            windowsString,
            node.eventCount,
            node.focusScore,
            node.parentContextId ?? NSNull()
        ])
    }
    
    private func updateNode(_ node: ContextNode) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index] = node
        }
        
        guard let appsJson = try? JSONEncoder().encode(Array(node.apps)),
              let appsString = String(data: appsJson, encoding: .utf8),
              let windowsJson = try? JSONEncoder().encode(node.windowTitles),
              let windowsString = String(data: windowsJson, encoding: .utf8) else {
            return
        }
        
        _ = db.execute("""
            UPDATE context_nodes SET
                label = ?,
                end_time = ?,
                is_active = ?,
                apps = ?,
                window_titles = ?,
                event_count = ?,
                focus_score = ?
            WHERE id = ?
        """, parameters: [
            node.label,
            node.endTime.map { Database.dateToString($0) } ?? NSNull(),
            node.isActive ? 1 : 0,
            appsString,
            windowsString,
            node.eventCount,
            node.focusScore,
            node.id
        ])
    }
    
    private func addEdge(_ edge: ContextEdge) {
        edges.insert(edge, at: 0)
        
        guard let metadataJson = try? JSONEncoder().encode(edge.metadata),
              let metadataString = String(data: metadataJson, encoding: .utf8) else {
            return
        }
        
        _ = db.execute("""
            INSERT INTO context_edges 
            (id, from_context_id, to_context_id, edge_type, timestamp, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
        """, parameters: [
            edge.id,
            edge.fromContextId,
            edge.toContextId,
            edge.edgeType.rawValue,
            Database.dateToString(edge.timestamp),
            metadataString
        ])
    }
    
    private func nodeFromRow(_ row: [String: Any]) -> ContextNode? {
        guard let id = row["id"] as? String,
              let label = row["label"] as? String,
              let typeRaw = row["type"] as? String,
              let type = ContextType(rawValue: typeRaw),
              let startTimeStr = row["start_time"] as? String,
              let startTime = Database.stringToDate(startTimeStr) else {
            return nil
        }
        
        var node = ContextNode(id: id, label: label, type: type, startTime: startTime)
        
        if let endTimeStr = row["end_time"] as? String {
            node.endTime = Database.stringToDate(endTimeStr)
        }
        
        node.isActive = (row["is_active"] as? Int ?? 0) == 1
        node.eventCount = row["event_count"] as? Int ?? 0
        node.focusScore = row["focus_score"] as? Double ?? 0
        node.parentContextId = row["parent_context_id"] as? String
        
        if let appsStr = row["apps"] as? String,
           let appsData = appsStr.data(using: .utf8),
           let appsArray = try? JSONDecoder().decode([String].self, from: appsData) {
            node.apps = Set(appsArray)
        }
        
        if let windowsStr = row["window_titles"] as? String,
           let windowsData = windowsStr.data(using: .utf8),
           let windowsArray = try? JSONDecoder().decode([String].self, from: windowsData) {
            node.windowTitles = windowsArray
        }
        
        return node
    }
    
    private func edgeFromRow(_ row: [String: Any]) -> ContextEdge? {
        guard let id = row["id"] as? String,
              let fromId = row["from_context_id"] as? String,
              let toId = row["to_context_id"] as? String,
              let typeRaw = row["edge_type"] as? String,
              let type = ContextEdgeType(rawValue: typeRaw),
              let timestampStr = row["timestamp"] as? String,
              let timestamp = Database.stringToDate(timestampStr) else {
            return nil
        }
        
        var edge = ContextEdge(from: fromId, to: toId, type: type)
        
        if let metadataStr = row["metadata"] as? String,
           let metadataData = metadataStr.data(using: .utf8),
           let metadata = try? JSONDecoder().decode([String: String].self, from: metadataData) {
            edge.metadata = metadata
        }
        
        return edge
    }
    
    // MARK: - Query Methods
    
    /// Get contexts from the last N hours
    func getRecentContexts(hours: Int = 24) -> [ContextNode] {
        let cutoff = Date().addingTimeInterval(-TimeInterval(hours * 3600))
        return nodes.filter { $0.startTime >= cutoff }
    }
    
    /// Get contexts for a specific app
    func getContextsForApp(bundleId: String) -> [ContextNode] {
        return nodes.filter { $0.apps.contains(bundleId) }
    }
    
    /// Get the context graph as a summary for AI agents
    func getContextSummary() -> String {
        let recentContexts = getRecentContexts(hours: 4)
        
        var summary = "## Recent Context Graph (Last 4 Hours)\n\n"
        
        if let active = activeContext {
            summary += "### Active Context\n"
            summary += "- **\(active.label)** (\(active.type.rawValue))\n"
            summary += "  - Duration: \(formatDuration(active.duration))\n"
            summary += "  - Focus Score: \(Int(active.focusScore * 100))%\n"
            summary += "  - Apps: \(active.apps.joined(separator: ", "))\n\n"
        }
        
        summary += "### Context History\n"
        for context in recentContexts.prefix(10) where context.id != activeContext?.id {
            summary += "- **\(context.label)** (\(formatDuration(context.duration)))\n"
        }
        
        summary += "\n### Context Transitions: \(edges.count) in last 24h\n"
        
        return summary
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

