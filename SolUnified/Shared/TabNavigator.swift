//
//  TabNavigator.swift
//  SolUnified
//
//  Main tab navigation controller
//

import SwiftUI

struct TabNavigator: View {
    @State private var selectedTab: AppTab = .notes
    @ObservedObject var settings = AppSettings.shared
    @FocusState private var tabFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: Spacing.md) {
                TabButton(title: "NOTES", tab: .notes, selectedTab: $selectedTab)
                    .keyboardShortcut("1", modifiers: .command)
                
                TabButton(title: "CLIPBOARD", tab: .clipboard, selectedTab: $selectedTab)
                    .keyboardShortcut("2", modifiers: .command)
                
                TabButton(title: "SCREENSHOTS", tab: .screenshots, selectedTab: $selectedTab)
                    .keyboardShortcut("3", modifiers: .command)
                
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.brutalistBgPrimary)
        .sheet(isPresented: $settings.showSettings) {
            SettingsView()
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
            selectedTab = .notes
        }
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

