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
    @State private var lastSaved: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("SCRATCHPAD")
                    .font(.system(size: Typography.headingSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                if let lastSaved = lastSaved {
                    Text("• Saved \(timeAgo(lastSaved))")
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                }
            }
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Content Area - Text Editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .font(.system(size: Typography.bodySize, design: .monospaced))
                    .lineSpacing(Typography.lineHeight * Typography.bodySize - Typography.bodySize)
                    .foregroundColor(Color.brutalistTextPrimary)
                    .padding(Spacing.lg)
                    .background(Color.brutalistBgSecondary)
                    .scrollContentBackground(.hidden)
                    .onChange(of: content) { newValue in
                        scheduleAutoSave()
                    }
                
                if content.isEmpty {
                    Text("Start typing...\n\nYour notes are auto-saved")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextMuted)
                        .padding(Spacing.lg)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.brutalistBgSecondary)
        }
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
