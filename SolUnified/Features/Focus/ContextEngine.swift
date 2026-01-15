//
//  ContextEngine.swift
//  SolUnified
//
//  The "One Button Revolution" - aggregates the current "State of Reality"
//  into a structured payload for AI injection.
//
//  Trigger: Opt + C
//  Output: Copies a formatted Markdown block to clipboard, optimized for LLM context windows.
//

import Foundation
import Cocoa
import Vision

class ContextEngine {
    static let shared = ContextEngine()

    private let objectiveStore = ObjectiveStore.shared
    private let clipboardStore = ClipboardStore.shared
    private let activityMonitor = ActivityMonitor.shared
    private let screenshotsStore = ScreenshotsStore.shared
    private let contextGraph = ContextGraphManager.shared

    private init() {}

    // MARK: - Main Aggregation

    /// Captures current context and copies to clipboard as formatted markdown
    func captureAndCopy() {
        Task {
            let context = await captureContext()
            let markdown = formatAsMarkdown(context)

            // Copy to system clipboard
            DispatchQueue.main.async {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(markdown, forType: .string)

                // Show confirmation
                self.showNotification()

                print("📋 Context captured and copied (\(markdown.count) chars)")
            }
        }
    }

    // MARK: - Context Capture

    private func captureContext() async -> CapturedContext {
        // 1. Active window info
        let activeWindow = captureActiveWindow()

        // 2. Currently selected text (if any)
        let selection = captureSelection()

        // 3. Recent screenshot (OCR processed)
        let recentScreenshot = await captureRecentScreenshot()

        // 4. Last 3 clipboard items
        let clipboardHistory = captureClipboardHistory()

        // 5. Current objective
        let objective = objectiveStore.currentObjective

        // 6. Work context from activity
        let workContext = captureWorkContext()

        return CapturedContext(
            timestamp: Date(),
            activeWindow: activeWindow,
            selection: selection,
            recentScreenshot: recentScreenshot,
            clipboardHistory: clipboardHistory,
            objective: objective,
            workContext: workContext
        )
    }

    private func captureActiveWindow() -> ActiveWindowInfo? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let appName = frontApp.localizedName ?? "Unknown"
        let bundleId = frontApp.bundleIdentifier ?? ""

        // Get window title using Accessibility API
        var windowTitle: String?

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var value: AnyObject?

        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let windowElement = value {
            var titleValue: AnyObject?
            if AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXTitleAttribute as CFString, &titleValue) == .success {
                windowTitle = titleValue as? String
            }
        }

        return ActiveWindowInfo(
            appName: appName,
            bundleId: bundleId,
            windowTitle: windowTitle
        )
    }

    private func captureSelection() -> String? {
        // Try to get selected text via Accessibility API
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var value: AnyObject?

        // Try to get focused element
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &value) == .success,
           let focusedElement = value {
            var selectedText: AnyObject?
            if AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success {
                if let text = selectedText as? String, !text.isEmpty {
                    return text
                }
            }
        }

        return nil
    }

    private func captureRecentScreenshot() async -> ScreenshotInfo? {
        // Get most recent screenshot from last 30 seconds
        let thirtySecondsAgo = Date().addingTimeInterval(-30)

        let recentScreenshots = screenshotsStore.screenshots.filter {
            $0.createdAt >= thirtySecondsAgo
        }

        guard let screenshot = recentScreenshots.first else { return nil }

        // Perform OCR on the screenshot
        var ocrText: String?
        if let image = NSImage(contentsOfFile: screenshot.filepath),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            ocrText = await performOCR(on: cgImage)
        }

        return ScreenshotInfo(
            filename: screenshot.filename,
            timestamp: screenshot.createdAt,
            sourceApp: screenshot.sourceAppName,
            ocrText: ocrText
        )
    }

    private func performOCR(on image: CGImage) async -> String? {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text.isEmpty ? nil : text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    private func captureClipboardHistory() -> [ClipboardHistoryItem] {
        return clipboardStore.items.prefix(3).map { item in
            ClipboardHistoryItem(
                content: truncate(item.contentText ?? item.contentPreview ?? "", maxLength: 500),
                sourceApp: item.sourceAppName,
                timestamp: item.createdAt
            )
        }
    }

    private func captureWorkContext() -> WorkContextInfo? {
        guard let activeContext = contextGraph.activeContext else { return nil }

        return WorkContextInfo(
            contextType: activeContext.type.rawValue,
            focusScore: activeContext.focusScore,
            duration: activeContext.duration,
            apps: Array(activeContext.apps),
            eventCount: activeContext.eventCount
        )
    }

    // MARK: - Markdown Formatting

    private func formatAsMarkdown(_ context: CapturedContext) -> String {
        var sections: [String] = []

        // Header
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        sections.append("# Context Snapshot")
        sections.append("*Captured: \(dateFormatter.string(from: context.timestamp))*")

        // Objective (if set)
        if let objective = context.objective {
            sections.append("""
            ## Current Objective
            **\(objective.text)**
            - Duration: \(objective.formattedDuration)
            - Status: \(objective.isPaused ? "Paused" : "Active")
            """)
        }

        // Active Window
        if let window = context.activeWindow {
            var windowSection = "## Active Window\n"
            windowSection += "- App: **\(window.appName)**\n"
            if let title = window.windowTitle, !title.isEmpty {
                windowSection += "- Window: \(title)\n"
            }
            sections.append(windowSection)
        }

        // Selection
        if let selection = context.selection, !selection.isEmpty {
            let truncated = truncate(selection, maxLength: 1000)
            sections.append("""
            ## Selected Text
            ```
            \(truncated)
            ```
            """)
        }

        // Recent Screenshot (OCR)
        if let screenshot = context.recentScreenshot {
            var screenshotSection = "## Recent Screenshot\n"
            screenshotSection += "- File: \(screenshot.filename)\n"
            if let app = screenshot.sourceApp {
                screenshotSection += "- Source: \(app)\n"
            }
            if let ocr = screenshot.ocrText, !ocr.isEmpty {
                let truncatedOCR = truncate(ocr, maxLength: 800)
                screenshotSection += "\n**Visible Text (OCR):**\n```\n\(truncatedOCR)\n```"
            }
            sections.append(screenshotSection)
        }

        // Clipboard History
        if !context.clipboardHistory.isEmpty {
            var clipSection = "## Recent Clipboard\n"
            for (index, item) in context.clipboardHistory.enumerated() {
                let source = item.sourceApp ?? "unknown"
                let preview = truncate(item.content, maxLength: 200)
                clipSection += "\n**\(index + 1). [\(source)]**\n```\n\(preview)\n```\n"
            }
            sections.append(clipSection)
        }

        // Work Context
        if let workContext = context.workContext {
            sections.append("""
            ## Work Context
            - Type: \(workContext.contextType)
            - Focus Score: \(Int(workContext.focusScore * 100))%
            - Duration: \(Int(workContext.duration / 60))m
            - Apps: \(workContext.apps.joined(separator: ", "))
            """)
        }

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Helpers

    private func truncate(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength - 3)) + "..."
    }

    private func showNotification() {
        // Play a subtle sound
        NSSound(named: "Pop")?.play()

        // Could also show a notification banner, but keeping it minimal
    }
}

// MARK: - Models

struct CapturedContext {
    let timestamp: Date
    let activeWindow: ActiveWindowInfo?
    let selection: String?
    let recentScreenshot: ScreenshotInfo?
    let clipboardHistory: [ClipboardHistoryItem]
    let objective: Objective?
    let workContext: WorkContextInfo?
}

struct ActiveWindowInfo {
    let appName: String
    let bundleId: String
    let windowTitle: String?
}

struct ScreenshotInfo {
    let filename: String
    let timestamp: Date
    let sourceApp: String?
    let ocrText: String?
}

struct ClipboardHistoryItem {
    let content: String
    let sourceApp: String?
    let timestamp: Date
}

struct WorkContextInfo {
    let contextType: String
    let focusScore: Double
    let duration: TimeInterval
    let apps: [String]
    let eventCount: Int
}
