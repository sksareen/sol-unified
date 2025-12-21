//
//  TabNavigator.swift
//  SolUnified
//
//  Main tab navigation controller
//

import SwiftUI

struct TabNavigator: View {
    @State private var selectedTab: AppTab = .tasks {
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
                TabButton(title: "TASKS", tab: .tasks, selectedTab: $selectedTab)
                    .keyboardShortcut("1", modifiers: .command)
                
                TabButton(title: "AGENTS", tab: .agents, selectedTab: $selectedTab)
                    .keyboardShortcut("2", modifiers: .command)

                TabButton(title: "VAULT", tab: .vault, selectedTab: $selectedTab)
                    .keyboardShortcut("3", modifiers: .command)
                
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("FocusVaultSearch"), object: nil)
                }) {
                    EmptyView()
                }
                .keyboardShortcut("p", modifiers: .command)
                .hidden()
                
                Button(action: {
                    AppSettings.shared.increaseWindowSize()
                }) {
                    EmptyView()
                }
                .keyboardShortcut("=", modifiers: .command)
                .hidden()
                
                Button(action: {
                    AppSettings.shared.decreaseWindowSize()
                }) {
                    EmptyView()
                }
                .keyboardShortcut("-", modifiers: .command)
                .hidden()
                
                // Cmd+B handled by VaultView directly
                
                TabButton(title: "CONTEXT", tab: .context, selectedTab: $selectedTab)
                    .keyboardShortcut("4", modifiers: .command)
                
                TabButton(title: "TERMINAL", tab: .terminal, selectedTab: $selectedTab)
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
                .disabled(settings.showSettings)
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
                case .tasks:
                    TasksView()
                case .agents:
                    AgentContextView()
                case .vault:
                    VaultView()
                case .context:
                    ContextView()
                case .terminal:
                    TerminalView()
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

