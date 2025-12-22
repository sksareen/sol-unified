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
            
            // Tab Bar - Nordic Minimalist Style
            HStack(spacing: 0) {
            TabButton(title: "Tasks", tab: .tasks, selectedTab: $selectedTab)
                .keyboardShortcut("1", modifiers: .command)
            
            /*
            TabButton(title: "Agents", tab: .agents, selectedTab: $selectedTab)
                //.keyboardShortcut("2", modifiers: .command)
            */

            TabButton(title: "Vault", tab: .vault, selectedTab: $selectedTab)
                .keyboardShortcut("2", modifiers: .command)
            
            TabButton(title: "Context", tab: .context, selectedTab: $selectedTab)
                .keyboardShortcut("3", modifiers: .command)
            
            TabButton(title: "Terminal", tab: .terminal, selectedTab: $selectedTab)
                .keyboardShortcut("4", modifiers: .command)
                
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
                
                Spacer()
                
                // Settings Button
                Button(action: {
                    settings.showSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.brutalistTextSecondary.opacity(0.7))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings")
                .keyboardShortcut(",", modifiers: .command)
                .disabled(settings.showSettings)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 0)
            .frame(height: 44)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.15)),
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
        .clipShape(RoundedRectangle(cornerRadius: BorderRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.md)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
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
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 0) {
                Spacer()
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? Color.primary : Color.secondary.opacity(0.6))
                    .padding(.bottom, 10)
                
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
    }
}

