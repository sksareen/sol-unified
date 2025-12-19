//
//  TabNavigator.swift
//  SolUnified
//
//  Main tab navigation controller
//

import SwiftUI

struct TabNavigator: View {
    @State private var selectedTab: AppTab = .agents {
        didSet {
            // Track tab switch
            InternalAppTracker.shared.trackTabSwitch(to: selectedTab)
        }
    }
    @ObservedObject var settings = AppSettings.shared
    @FocusState private var tabFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Tab Bar
            HStack(spacing: 4) {
                TabButton(title: "AGENTS", tab: .agents, selectedTab: $selectedTab)
                    .keyboardShortcut("1", modifiers: .command)

                TabButton(title: "NOTES", tab: .notes, selectedTab: $selectedTab)
                    .keyboardShortcut("2", modifiers: .command)
                
                TabButton(title: "CLIPBOARD", tab: .clipboard, selectedTab: $selectedTab)
                    .keyboardShortcut("3", modifiers: .command)
                
                TabButton(title: "SCREENSHOTS", tab: .screenshots, selectedTab: $selectedTab)
                    .keyboardShortcut("4", modifiers: .command)
                
                TabButton(title: "ACTIVITY", tab: .activity, selectedTab: $selectedTab)
                    .keyboardShortcut("5", modifiers: .command)
                
                Spacer()
                
                // Settings Button
                Button(action: {
                    settings.showSettings = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings (Cmd+,)")
                .keyboardShortcut(",", modifiers: .command)
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
            .focused($tabFocused)
            
            // Content Area
            Group {
                switch selectedTab {
                case .notes:
                    NotesView()
                case .clipboard:
                    ClipboardView()
                case .screenshots:
                    ScreenshotsView()
                case .agents:
                    AgentContextView()
                case .activity:
                    ActivityView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.brutalistBgPrimary)
        .sheet(isPresented: $settings.showSettings, onDismiss: {
            // Track settings close
            InternalAppTracker.shared.trackSettingsClose()
        }) {
            SettingsView()
        }
        .onChange(of: settings.showSettings) { isOpen in
            if isOpen {
                // Track settings open
                InternalAppTracker.shared.trackSettingsOpen()
            }
        }
        .onAppear {
            tabFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CycleTab"))) { _ in
            cycleTab()
        }
    }
    
    private func cycleTab() {
        switch selectedTab {
        case .agents:
            selectedTab = .notes
        case .notes:
            selectedTab = .clipboard
        case .clipboard:
            selectedTab = .screenshots
        case .screenshots:
            selectedTab = .activity
        case .activity:
            selectedTab = .agents
        }
        // Tracking happens automatically via didSet
    }
}

struct TabButton: View {
    let title: String
    let tab: AppTab
    @Binding var selectedTab: AppTab
    
    var isSelected: Bool {
        selectedTab == tab
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .tracking(0.5)
                .foregroundColor(isSelected ? Color.brutalistTextPrimary : Color.brutalistTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.brutalistBgTertiary)
                                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

