//
//  ContextView.swift
//  SolUnified
//
//  Unified context view combining Activity, Screenshots, and Clipboard
//

import SwiftUI

struct ContextView: View {
    @AppStorage("lastContextSection") private var lastSectionRaw: String = ContextSection.clipboard.rawValue
    @State private var selectedSection: ContextSection = .clipboard
    
    enum ContextSection: String, CaseIterable {
        case scratchpad = "SCRATCHPAD"
        case clipboard = "CLIPBOARD"
        case screenshots = "SCREENSHOTS"
        case activity = "ACTIVITY"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Selector
            HStack(spacing: 4) {
                ForEach(ContextSection.allCases, id: \.self) { section in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSection = section
                        }
                    }) {
                        Text(section.rawValue)
                            .font(.system(size: 11, weight: selectedSection == section ? .bold : .medium))
                            .tracking(0.5)
                            .foregroundColor(selectedSection == section ? .brutalistTextPrimary : .brutalistTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                ZStack {
                                    if selectedSection == section {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.brutalistBgTertiary)
                                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                    }
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Content
            Group {
                switch selectedSection {
                case .scratchpad:
                    ScratchpadView()
                case .clipboard:
                    ClipboardView()
                case .screenshots:
                    ScreenshotsView()
                case .activity:
                    ActivityView()
                }
            }
        }
        .background(Color.brutalistBgPrimary)
        .onAppear {
            if let savedSection = ContextSection(rawValue: lastSectionRaw) {
                selectedSection = savedSection
            }
        }
        .onChange(of: selectedSection) { newSection in
            lastSectionRaw = newSection.rawValue
        }
    }
}
