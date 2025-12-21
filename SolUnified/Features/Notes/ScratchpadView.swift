//
//  ScratchpadView.swift
//  SolUnified
//
//  Global scratchpad - single always-available note
//

import SwiftUI

struct ScratchpadView: View {
    @ObservedObject var store = NotesStore.shared
    @State private var content: String = ""
    @State private var saveTimer: Timer?
    @State private var trackingTimer: Timer?
    @State private var lastSaved: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("SCRATCHPAD")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let lastSaved = lastSaved {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 4, height: 4)
                        Text("SAVED \(timeAgo(lastSaved).uppercased())")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Content Area - Text Editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .lineSpacing(6)
                    .foregroundColor(.primary.opacity(0.9))
                    .padding(20)
                    .background(Color.brutalistBgPrimary)
                    .scrollContentBackground(.hidden)
                    .onChange(of: content) { newValue in
                        scheduleAutoSave()
                        scheduleTracking()
                    }
                
                if content.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start typing...")
                            .font(.system(size: 13, weight: .medium))
                        Text("Your notes are auto-saved in real-time.")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary.opacity(0.4))
                    .padding(20)
                    .padding(.top, 4)
                    .allowsHitTesting(false)
                }
            }
        }
        .background(Color.brutalistBgPrimary)
        .onAppear {
            content = store.globalNote?.content ?? ""
        }
    }
    
    private func scheduleAutoSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            store.saveGlobalNote(content: content)
            lastSaved = Date()
        }
    }
    
    private func scheduleTracking() {
        // Debounce tracking: only log after user stops typing for 2 seconds
        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            InternalAppTracker.shared.trackScratchpadEdit()
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}
