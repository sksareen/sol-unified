//
//  TabNavigator.swift
//  SolUnified
//
//  Main tab navigation controller
//

import SwiftUI

struct TabNavigator: View {
    @State private var selectedTab: AppTab = .notes {
        didSet {
            // Track tab switch
            InternalAppTracker.shared.trackTabSwitch(to: selectedTab)
        }
    }
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var timerStore = TimerStore.shared
    @FocusState private var tabFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar (above tab bar, only when timer is running)
            if timerStore.isRunning {
                GeometryReader { geometry in
                    let progress = timerStore.totalDuration > 0 ? 
                        max(0.0, min(1.0, timerStore.timeRemaining / timerStore.totalDuration)) : 0.0
                    
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.brutalistAccent.opacity(0.6))
                            .frame(width: geometry.size.width * progress, height: 3)
                            .animation(.linear(duration: 1.0), value: progress)
                        
                        Spacer()
                    }
                }
                .frame(height: 3)
            }
            
            // Tab Bar
            HStack(spacing: Spacing.md) {
                TabButton(title: "NOTES", tab: .notes, selectedTab: $selectedTab)
                    .keyboardShortcut("1", modifiers: .command)
                
                TabButton(title: "CLIPBOARD", tab: .clipboard, selectedTab: $selectedTab)
                    .keyboardShortcut("2", modifiers: .command)
                
                TabButton(title: "SCREENSHOTS", tab: .screenshots, selectedTab: $selectedTab)
                    .keyboardShortcut("3", modifiers: .command)
                
                TimerTabButton(selectedTab: $selectedTab, timerStore: timerStore)
                    .keyboardShortcut("4", modifiers: .command)
                
                TabButton(title: "ACTIVITY", tab: .activity, selectedTab: $selectedTab)
                    .keyboardShortcut("5", modifiers: .command)
                
                Spacer()
                
                // Settings Button
                Button(action: {
                    settings.showSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextSecondary)
                        .padding(Spacing.sm)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings (Cmd+,)")
                .keyboardShortcut(",", modifiers: .command)
            }
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            .focused($tabFocused)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Content Area
            Group {
                switch selectedTab {
                case .notes:
                    NotesView()
                case .clipboard:
                    ClipboardView()
                case .screenshots:
                    ScreenshotsView()
                case .timer:
                    TimerView()
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
        case .notes:
            selectedTab = .clipboard
        case .clipboard:
            selectedTab = .screenshots
        case .screenshots:
            selectedTab = .timer
        case .timer:
            selectedTab = .activity
        case .activity:
            selectedTab = .notes
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
            selectedTab = tab
        }) {
            Text(title)
                .font(.system(size: Typography.bodySize, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color.brutalistTextPrimary : Color.brutalistTextSecondary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    isSelected ? Color.brutalistBgTertiary : Color.clear
                )
                .cornerRadius(BorderRadius.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TimerTabButton: View {
    @Binding var selectedTab: AppTab
    @ObservedObject var timerStore: TimerStore
    
    var isSelected: Bool {
        selectedTab == .timer
    }
    
    var title: String {
        if timerStore.isRunning && timerStore.timeRemaining > 0 {
            return "TIMER (\(timerStore.formatTime(timerStore.timeRemaining)))"
        }
        return "TIMER"
    }
    
    var body: some View {
        Button(action: {
            selectedTab = .timer
        }) {
            Text(title)
                .font(.system(size: Typography.bodySize, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color.brutalistTextPrimary : Color.brutalistTextSecondary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    isSelected ? Color.brutalistBgTertiary : Color.clear
                )
                .cornerRadius(BorderRadius.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

