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
    @StateObject private var terminalPanelState = TerminalPanelState.shared
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

            TabButton(title: "Agent", tab: .agent, selectedTab: $selectedTab)
                .keyboardShortcut("4", modifiers: .command)

                // Hidden shortcut for toggling terminal panel (⌘J)
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        terminalPanelState.isVisible.toggle()
                    }
                }) {
                    EmptyView()
                }
                .keyboardShortcut("j", modifiers: .command)
                .hidden()
                
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("FocusVaultSearch"), object: nil)
                }) {
                    EmptyView()
                }
                .keyboardShortcut("p", modifiers: .command)
                .hidden()
                
                Button(action: {
                    AppSettings.shared.increaseFontSize()
                }) {
                    EmptyView()
                }
                .keyboardShortcut("=", modifiers: .command)
                .hidden()
                
                Button(action: {
                    AppSettings.shared.decreaseFontSize()
                }) {
                    EmptyView()
                }
                .keyboardShortcut("-", modifiers: .command)
                .hidden()
                
                Spacer()
                
                // Terminal toggle button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        terminalPanelState.isVisible.toggle()
                    }
                }) {
                    Image(systemName: "terminal")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(terminalPanelState.isVisible ? Color.brutalistAccent : Color.brutalistTextSecondary.opacity(0.7))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Toggle Terminal (⌘J)")
                
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
            
            // Content Area with Terminal Panel
            ZStack(alignment: .bottom) {
                // Main content
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
                    case .agent:
                        ChatView()
                    case .terminal:
                        // Legacy - redirect to vault if someone lands here
                        VaultView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Shrink content when terminal is visible
                .padding(.bottom, terminalPanelState.isVisible ? terminalPanelState.panelHeight : 0)
                
                // Terminal slide-out panel
                if terminalPanelState.isVisible {
                    TerminalPanel()
                        .frame(height: terminalPanelState.panelHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
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
                .preferredColorScheme(settings.isDarkMode ? .dark : .light)
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
        // Force color scheme based on app setting, not system
        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
    }
}

// MARK: - Terminal Panel State
class TerminalPanelState: ObservableObject {
    static let shared = TerminalPanelState()
    
    @Published var isVisible: Bool = false
    @Published var panelHeight: CGFloat = 300
    
    private init() {}
    
    func toggle() {
        isVisible.toggle()
    }
}

// MARK: - Terminal Panel View
struct TerminalPanel: View {
    @StateObject private var terminalStore = TerminalStore.shared
    @StateObject private var panelState = TerminalPanelState.shared
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brutalistTextMuted.opacity(0.5))
                    .frame(width: 40, height: 4)
                Spacer()
            }
            .frame(height: 12)
            .background(Color.brutalistBgSecondary)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newHeight = panelState.panelHeight - value.translation.height
                        // Allow terminal to expand to nearly full height (leaving room for tab bar)
                        let maxHeight = NSScreen.main?.visibleFrame.height ?? 800
                        panelState.panelHeight = max(100, min(maxHeight - 60, newHeight))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            // Header with tabs
            HStack(spacing: 8) {
                Text("TERMINAL")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Color.brutalistTextSecondary)
                
                // Tab bar (show if more than 1 tab)
                if terminalStore.tabs.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(terminalStore.tabs) { tab in
                                PanelTerminalTabButton(
                                    tab: tab,
                                    isSelected: terminalStore.selectedTabId == tab.id,
                                    onSelect: { terminalStore.selectTab(tab.id) },
                                    onClose: { terminalStore.closeTab(tab.id) }
                                )
                            }
                        }
                    }
                }
                
                Spacer()
                
                // New tab button
                Button(action: {
                    terminalStore.addTab()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("New Tab")
                
                // Close button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        panelState.isVisible = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close Terminal (⌘J)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .top
            )
            
            // Terminal content
            if let currentTab = terminalStore.currentTab {
                TerminalViewWrapper(terminal: currentTab.terminal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .id(currentTab.id)
            }
            
            // Bottom padding spacer
            Spacer()
                .frame(height: 50)
                .background(Color.black)
        }
        .background(Color.black)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.brutalistBorder),
            alignment: .top
        )
    }
}

// MARK: - Panel Terminal Tab Button (Compact)
struct PanelTerminalTabButton: View {
    let tab: TerminalTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tab.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color.brutalistTextPrimary : Color.brutalistTextMuted)
            
            if isHovering || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Color.brutalistTextMuted)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isSelected ? Color.brutalistBgTertiary : Color.clear)
        .cornerRadius(3)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

struct TabButton: View {
    let title: String
    let tab: AppTab
    @Binding var selectedTab: AppTab
    @ObservedObject private var settings = AppSettings.shared
    
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
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
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

