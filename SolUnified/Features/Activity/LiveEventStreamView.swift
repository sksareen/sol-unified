//
//  LiveEventStreamView.swift
//  SolUnified
//
//  Real-time event stream viewer showing live activity events
//

import SwiftUI

struct LiveEventStreamView: View {
    let events: [ActivityEvent]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LIVE EVENT STREAM")
                    .font(.system(size: Typography.smallSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextSecondary)
                
                Spacer()
                
                Text("\(events.count) events")
                    .font(.system(size: Typography.smallSize))
                    .foregroundColor(Color.brutalistTextMuted)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Event log (reverse order - newest first)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(events.prefix(200).enumerated()), id: \.element.id) { index, event in
                            LiveEventRow(event: event)
                                .id(index)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                }
                .onChange(of: events.count) { _ in
                    // Auto-scroll to top when new events arrive
                    if !events.isEmpty {
                        withAnimation {
                            proxy.scrollTo(0, anchor: .top)
                        }
                    }
                }
            }
            .background(Color.brutalistBgPrimary)
        }
        .background(Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.sm)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
    }
}

struct LiveEventRow: View {
    let event: ActivityEvent
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Time
            Text(formatTime(event.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.brutalistTextMuted)
                .frame(width: 70, alignment: .leading)
            
            // Symbol
            Text(eventSymbol)
                .font(.system(size: 12))
                .frame(width: 24)
            
            // App name
            Text(event.appName ?? event.appBundleId ?? "?")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.brutalistTextSecondary)
                .frame(width: 150, alignment: .leading)
                .lineLimit(1)
            
            // Window title or event details
            if let windowTitle = event.windowTitle, !windowTitle.isEmpty {
                Text("\"\(windowTitle)\"")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.brutalistTextMuted)
                    .lineLimit(1)
            } else if let eventData = event.eventData,
                      let data = eventData.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Show event data for keyboard/mouse events or internal events
                if let keyCount = json["keyCount"] as? String {
                    Text(keyCount)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.brutalistTextMuted)
                } else if let x = json["x"] as? Double, let y = json["y"] as? Double {
                    Text("(\(Int(x)), \(Int(y)))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.brutalistTextMuted)
                } else if let tab = json["tab"] as? String {
                    Text("→ \(tab)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.brutalistTextMuted)
                } else if let feature = json["feature"] as? String {
                    Text("→ \(feature)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.brutalistTextMuted)
                } else {
                    Text(eventTypeLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.brutalistTextMuted)
                }
            } else {
                Text(eventTypeLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.brutalistTextMuted)
            }
            
            Spacer()
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 2)
    }
    
    private var eventSymbol: String {
        switch event.eventType {
        case .appLaunch: return "🚀"
        case .appTerminate: return "❌"
        case .appActivate: return "↔️"
        case .windowTitleChange: return "📑"
        case .windowClosed: return "🗙"
        case .keyPress: return "⌨️"
        case .mouseClick: return "🖱️"
        case .mouseMove: return "↗️"
        case .mouseScroll: return "⚡"
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
        case .idleStart: return "💤"
        case .idleEnd: return "☀️"
        case .screenSleep: return "🌙"
        case .screenWake: return "🌅"
        case .heartbeat: return "❤️"
        }
    }
    
    private var eventTypeLabel: String {
        switch event.eventType {
        case .appLaunch: return "Launch"
        case .appTerminate: return "Terminate"
        case .appActivate: return "Switch"
        case .windowTitleChange: return "Window"
        case .windowClosed: return "Closed"
        case .keyPress: return "Keyboard"
        case .mouseClick: return "Click"
        case .mouseMove: return "Move"
        case .mouseScroll: return "Scroll"
        case .internalTabSwitch: return "Tab"
        case .internalSettingsOpen: return "Settings+"
        case .internalSettingsClose: return "Settings-"
        case .internalFeatureOpen: return "Open"
        case .internalFeatureClose: return "Close"
        case .internalNoteCreate: return "Note+"
        case .internalNoteEdit: return "Note✏️"
        case .internalNoteDelete: return "Note-"
        case .internalNoteView: return "Note👁️"
        case .internalNoteSearch: return "Search"
        case .internalScratchpadEdit: return "Scratchpad"
        case .internalClipboardCopy: return "Copy"
        case .internalClipboardPaste: return "Paste"
        case .internalClipboardClear: return "Clear"
        case .internalClipboardSearch: return "Search"
        case .internalTimerStart: return "Timer▶️"
        case .internalTimerStop: return "Timer⏸️"
        case .internalTimerReset: return "Timer⏹️"
        case .internalTimerSetDuration: return "Duration"
        case .internalScreenshotView: return "View"
        case .internalScreenshotSearch: return "Search"
        case .internalScreenshotAnalyze: return "Analyze"
        case .internalSettingChange: return "Setting"
        case .internalWindowShow: return "Show"
        case .internalWindowHide: return "Hide"
        case .idleStart: return "Idle"
        case .idleEnd: return "Active"
        case .screenSleep: return "Sleep"
        case .screenWake: return "Wake"
        case .heartbeat: return "Heartbeat"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

