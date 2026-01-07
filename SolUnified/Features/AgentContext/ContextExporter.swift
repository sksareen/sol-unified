//
//  ContextExporter.swift
//  SolUnified
//
//  Exports unified context for AI agent consumption.
//  Any Claude Code instance can read ~/Documents/sol-context/ to understand:
//  - What you're currently working on
//  - Recent clipboard items with source context
//  - Screenshots taken during this session
//  - Activity patterns and focus metrics
//

import Foundation
import Combine

// MARK: - Export Models

struct ExportedContext: Codable {
    let generated_at: String
    let version: String
    let active_context: ExportedContextNode?
    let recent_contexts: [ExportedContextNode]
    let clipboard_items: [ExportedClipboardItem]
    let screenshots: [ExportedScreenshot]
    let activity_summary: ExportedActivitySummary
    let session_stats: SessionStats
}

struct ExportedContextNode: Codable {
    let id: String
    let label: String
    let type: String
    let start_time: String
    let end_time: String?
    let duration_minutes: Int
    let focus_score: Double
    let apps: [String]
    let window_titles: [String]
    let event_count: Int
    let linked_clipboard_count: Int
    let linked_screenshot_count: Int
}

struct ExportedClipboardItem: Codable {
    let timestamp: String
    let content_type: String
    let content_preview: String?
    let source_app: String?
    let source_window: String?
    let context_label: String?
}

struct ExportedScreenshot: Codable {
    let timestamp: String
    let filename: String
    let source_app: String?
    let source_window: String?
    let context_label: String?
    let ai_description: String?
}

struct ExportedActivitySummary: Codable {
    let last_hour: ActivityWindow
    let last_4_hours: ActivityWindow
    let today: ActivityWindow
}

struct ActivityWindow: Codable {
    let total_events: Int
    let unique_apps: Int
    let top_apps: [AppUsage]
    let focus_score: Double
    let context_transitions: Int
}

struct AppUsage: Codable {
    let app_name: String
    let duration_minutes: Int
    let event_count: Int
}

struct SessionStats: Codable {
    let total_contexts_today: Int
    let total_clipboard_items_today: Int
    let total_screenshots_today: Int
    let average_focus_score: Double
    let most_used_app: String?
    let primary_context_type: String?
}

// MARK: - Context Exporter

class ContextExporter: ObservableObject {
    static let shared = ContextExporter()

    @Published var lastExport: Date?
    @Published var exportCount: Int = 0

    private let exportDirectory: URL
    private let mainExportPath: URL
    private let compactExportPath: URL

    private let db = Database.shared
    private let contextGraph = ContextGraphManager.shared
    private let clipboardStore = ClipboardStore.shared
    private let screenshotsStore = ScreenshotsStore.shared

    private var exportTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        // Create export directory in Documents for easy access
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        exportDirectory = documentsURL.appendingPathComponent("sol-context", isDirectory: true)
        mainExportPath = exportDirectory.appendingPathComponent("context.json")
        compactExportPath = exportDirectory.appendingPathComponent("context-compact.md")

        setupExportDirectory()
    }

    private func setupExportDirectory() {
        try? FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        // Create a README for the context directory
        let readmePath = exportDirectory.appendingPathComponent("README.md")
        if !FileManager.default.fileExists(atPath: readmePath.path) {
            let readme = """
            # Sol Unified Context

            This directory contains real-time context exported from Sol Unified.

            ## Files

            - `context.json` - Full structured context (updated every 30s)
            - `context-compact.md` - Markdown summary for quick reading

            ## Usage with Claude Code

            Add this to your project's `CLAUDE.md`:

            ```markdown
            ## Context
            For real-time context about what I'm working on, read:
            ~/Documents/sol-context/context.json
            ```

            Or read the compact version for a quick summary:
            ```
            Read ~/Documents/sol-context/context-compact.md
            ```

            ## Data Included

            - **Active Context**: Current work session (type, focus score, apps)
            - **Recent Contexts**: Last 24h of work sessions
            - **Clipboard Items**: Recent copies with source app/window
            - **Screenshots**: Recent screenshots with metadata
            - **Activity Summary**: App usage and focus patterns
            """
            try? readme.write(to: readmePath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Public API

    func startAutoExport(interval: TimeInterval = 30.0) {
        stopAutoExport()

        // Export immediately
        exportContext()

        // Then export on interval
        exportTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.exportContext()
        }

        if let timer = exportTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("📤 Context export started (interval: \(Int(interval))s)")
    }

    func stopAutoExport() {
        exportTimer?.invalidate()
        exportTimer = nil
    }

    func exportContext() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.performExport()
        }
    }

    // MARK: - Export Implementation

    private func performExport() {
        let now = Date()

        // Build the full context
        let context = ExportedContext(
            generated_at: dateFormatter.string(from: now),
            version: "1.0",
            active_context: buildActiveContext(),
            recent_contexts: buildRecentContexts(),
            clipboard_items: buildClipboardItems(),
            screenshots: buildScreenshots(),
            activity_summary: buildActivitySummary(),
            session_stats: buildSessionStats()
        )

        // Export JSON
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(context)
            try jsonData.write(to: mainExportPath, options: .atomic)
        } catch {
            print("❌ Failed to export context JSON: \(error)")
        }

        // Export compact markdown
        let markdown = buildCompactMarkdown(context)
        try? markdown.write(to: compactExportPath, atomically: true, encoding: .utf8)

        DispatchQueue.main.async { [weak self] in
            self?.lastExport = now
            self?.exportCount += 1
        }
    }

    // MARK: - Context Building

    private func buildActiveContext() -> ExportedContextNode? {
        guard let active = contextGraph.activeContext else { return nil }
        return exportContextNode(active)
    }

    private func buildRecentContexts() -> [ExportedContextNode] {
        let recent = contextGraph.getRecentContexts(hours: 24)
        return recent
            .filter { $0.id != contextGraph.activeContext?.id }
            .prefix(20)
            .map { exportContextNode($0) }
    }

    private func exportContextNode(_ node: ContextNode) -> ExportedContextNode {
        return ExportedContextNode(
            id: node.id,
            label: node.label,
            type: node.type.rawValue,
            start_time: dateFormatter.string(from: node.startTime),
            end_time: node.endTime.map { dateFormatter.string(from: $0) },
            duration_minutes: Int(node.duration / 60),
            focus_score: round(node.focusScore * 100) / 100,
            apps: Array(node.apps),
            window_titles: Array(node.windowTitles.prefix(5)),
            event_count: node.eventCount,
            linked_clipboard_count: node.clipboardItemHashes.count,
            linked_screenshot_count: node.screenshotFilenames.count
        )
    }

    private func buildClipboardItems() -> [ExportedClipboardItem] {
        // Get recent clipboard items from store
        let items = clipboardStore.items.prefix(30)

        return items.map { item in
            // Find context active at this time
            let contextLabel = findContextLabel(at: item.createdAt)

            return ExportedClipboardItem(
                timestamp: dateFormatter.string(from: item.createdAt),
                content_type: item.contentType.rawValue,
                content_preview: truncate(item.contentPreview ?? item.contentText, maxLength: 200),
                source_app: item.sourceAppName,
                source_window: truncate(item.sourceWindowTitle, maxLength: 100),
                context_label: contextLabel
            )
        }
    }

    private func buildScreenshots() -> [ExportedScreenshot] {
        let screenshots = screenshotsStore.screenshots.prefix(20)

        return screenshots.map { screenshot in
            let contextLabel = findContextLabel(at: screenshot.createdAt)

            return ExportedScreenshot(
                timestamp: dateFormatter.string(from: screenshot.createdAt),
                filename: screenshot.filename,
                source_app: screenshot.sourceAppName,
                source_window: truncate(screenshot.sourceWindowTitle, maxLength: 100),
                context_label: contextLabel,
                ai_description: screenshot.aiDescription
            )
        }
    }

    private func buildActivitySummary() -> ExportedActivitySummary {
        return ExportedActivitySummary(
            last_hour: buildActivityWindow(hours: 1),
            last_4_hours: buildActivityWindow(hours: 4),
            today: buildActivityWindow(hours: 24)
        )
    }

    private func buildActivityWindow(hours: Int) -> ActivityWindow {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        let cutoffStr = Database.dateToString(cutoff)

        // Query activity events
        let events = db.query("""
            SELECT app_name, app_bundle_id, COUNT(*) as count
            FROM activity_log
            WHERE timestamp > ? AND app_name IS NOT NULL
            GROUP BY app_bundle_id
            ORDER BY count DESC
            LIMIT 10
        """, parameters: [cutoffStr])

        let totalEvents = events.reduce(0) { $0 + ($1["count"] as? Int ?? 0) }
        let uniqueApps = events.count

        let topApps: [AppUsage] = events.prefix(5).compactMap { row in
            guard let appName = row["app_name"] as? String,
                  let count = row["count"] as? Int else { return nil }
            return AppUsage(
                app_name: appName,
                duration_minutes: count / 2, // Rough estimate: 2 events per minute
                event_count: count
            )
        }

        // Get context transitions in this window
        let transitions = contextGraph.edges.filter { edge in
            edge.timestamp >= cutoff
        }.count

        // Calculate average focus score
        let contextsInWindow = contextGraph.nodes.filter { $0.startTime >= cutoff }
        let avgFocus = contextsInWindow.isEmpty ? 0.0 :
            contextsInWindow.reduce(0.0) { $0 + $1.focusScore } / Double(contextsInWindow.count)

        return ActivityWindow(
            total_events: totalEvents,
            unique_apps: uniqueApps,
            top_apps: topApps,
            focus_score: round(avgFocus * 100) / 100,
            context_transitions: transitions
        )
    }

    private func buildSessionStats() -> SessionStats {
        let todayStart = Calendar.current.startOfDay(for: Date())

        let contextsToday = contextGraph.nodes.filter { $0.startTime >= todayStart }
        let avgFocus = contextsToday.isEmpty ? 0.0 :
            contextsToday.reduce(0.0) { $0 + $1.focusScore } / Double(contextsToday.count)

        // Count context types
        var typeCounts: [String: Int] = [:]
        for ctx in contextsToday {
            typeCounts[ctx.type.rawValue, default: 0] += 1
        }
        let primaryType = typeCounts.max(by: { $0.value < $1.value })?.key

        // Count today's clipboard items
        let clipboardToday = clipboardStore.items.filter { $0.createdAt >= todayStart }.count

        // Count today's screenshots
        let screenshotsToday = screenshotsStore.screenshots.filter {
            $0.createdAt >= todayStart
        }.count

        // Find most used app today
        let todayStr = Database.dateToString(todayStart)
        let appResults = db.query("""
            SELECT app_name, COUNT(*) as count
            FROM activity_log
            WHERE timestamp > ? AND app_name IS NOT NULL
            GROUP BY app_name
            ORDER BY count DESC
            LIMIT 1
        """, parameters: [todayStr])
        let mostUsedApp = appResults.first?["app_name"] as? String

        return SessionStats(
            total_contexts_today: contextsToday.count,
            total_clipboard_items_today: clipboardToday,
            total_screenshots_today: screenshotsToday,
            average_focus_score: round(avgFocus * 100) / 100,
            most_used_app: mostUsedApp,
            primary_context_type: primaryType
        )
    }

    // MARK: - Compact Markdown Export

    private func buildCompactMarkdown(_ context: ExportedContext) -> String {
        var md = """
        # Sol Unified Context

        *Generated: \(formatTime(context.generated_at))*

        """

        // Active Context
        if let active = context.active_context {
            md += """
            ## Currently Active

            **\(active.label)**
            - Type: \(active.type)
            - Duration: \(active.duration_minutes)m
            - Focus: \(Int(active.focus_score * 100))%
            - Apps: \(active.apps.joined(separator: ", "))

            """
        } else {
            md += """
            ## Currently Active

            *No active context detected*

            """
        }

        // Recent Clipboard
        md += "## Recent Clipboard (\(context.clipboard_items.count) items)\n\n"
        for item in context.clipboard_items.prefix(5) {
            let preview = item.content_preview ?? "(no preview)"
            let source = item.source_app ?? "unknown"
            let truncatedPreview = truncate(preview, maxLength: 60) ?? ""
            md += "- **\(formatTime(item.timestamp))** [\(source)]: \(truncatedPreview)\n"
        }
        md += "\n"

        // Activity Summary
        let lastHour = context.activity_summary.last_hour
        md += """
        ## Activity (Last Hour)

        - Events: \(lastHour.total_events)
        - Apps: \(lastHour.unique_apps)
        - Focus: \(Int(lastHour.focus_score * 100))%
        - Top: \(lastHour.top_apps.prefix(3).map { $0.app_name }.joined(separator: ", "))

        """

        // Session Stats
        let stats = context.session_stats
        md += """
        ## Today's Stats

        - Contexts: \(stats.total_contexts_today)
        - Clipboard items: \(stats.total_clipboard_items_today)
        - Screenshots: \(stats.total_screenshots_today)
        - Avg focus: \(Int(stats.average_focus_score * 100))%
        - Most used: \(stats.most_used_app ?? "N/A")
        - Primary type: \(stats.primary_context_type ?? "N/A")
        """

        return md
    }

    // MARK: - Helpers

    private func findContextLabel(at date: Date) -> String? {
        return contextGraph.nodes.first { node in
            date >= node.startTime && (node.endTime == nil || date <= node.endTime!)
        }?.label
    }

    private func truncate(_ string: String?, maxLength: Int) -> String? {
        guard let string = string else { return nil }
        if string.count <= maxLength { return string }
        return String(string.prefix(maxLength - 3)) + "..."
    }

    private func formatTime(_ isoString: String) -> String {
        guard let date = dateFormatter.date(from: isoString) else { return isoString }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
