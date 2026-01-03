//
//  TerminalView.swift
//  SolUnified
//
//  Terminal emulator using SwiftTerm with tab support and split view
//

import SwiftUI
import SwiftTerm
import UniformTypeIdentifiers

struct TerminalView: View {
    @StateObject private var terminalStore = TerminalStore.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("TERMINAL")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(Color.brutalistTextPrimary)
                    
                    Spacer()
                    
                    // Split view toggle (only show if 2+ tabs)
                    if terminalStore.tabs.count > 1 {
                        Button(action: {
                            terminalStore.toggleSplitView()
                        }) {
                            Image(systemName: terminalStore.isSplitView ? "rectangle" : "rectangle.split.2x1")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(terminalStore.isSplitView ? Color.brutalistAccent : Color.brutalistTextSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(terminalStore.isSplitView ? "Single View" : "Split View")
                    }
                    
                    Button(action: {
                        terminalStore.addTab()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.brutalistTextSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("New Tab")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // Tab bar (always show if more than 1 tab)
                if terminalStore.tabs.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(terminalStore.tabs) { tab in
                                TerminalTabButton(
                                    tab: tab,
                                    isSelected: terminalStore.selectedTabIds.contains(tab.id),
                                    isPrimary: terminalStore.selectedTabId == tab.id,
                                    isSplitView: terminalStore.isSplitView,
                                    onSelect: { terminalStore.selectTab(tab.id) },
                                    onClose: { terminalStore.closeTab(tab.id) },
                                    onMove: { fromId, toId in terminalStore.moveTab(from: fromId, to: toId) }
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 8)
                }
            }
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Terminal content - single or split view
            if terminalStore.isSplitView && terminalStore.tabs.count > 1 {
                // Split view - show two terminals side by side
                HSplitView {
                    if let leftTab = terminalStore.leftTab {
                        TerminalPane(tab: leftTab, isActive: terminalStore.selectedTabId == leftTab.id)
                            .onTapGesture { terminalStore.selectTab(leftTab.id) }
                    }
                    if let rightTab = terminalStore.rightTab {
                        TerminalPane(tab: rightTab, isActive: terminalStore.selectedTabId == rightTab.id)
                            .onTapGesture { terminalStore.selectTab(rightTab.id) }
                    }
                }
            } else {
                // Single view
                if let currentTab = terminalStore.currentTab {
                    TerminalViewWrapper(terminal: currentTab.terminal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .id(currentTab.id)
                }
            }
        }
    }
}

struct TerminalPane: View {
    let tab: TerminalTab
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Pane header
            HStack {
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isActive ? Color.brutalistAccent : Color.brutalistTextMuted)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.brutalistAccent.opacity(0.1) : Color.black.opacity(0.3))
            
            TerminalViewWrapper(terminal: tab.terminal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? Color.brutalistAccent.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

struct TerminalTabButton: View {
    let tab: TerminalTab
    let isSelected: Bool
    let isPrimary: Bool
    let isSplitView: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onMove: (UUID, UUID) -> Void
    
    @State private var isHovering = false
    @State private var isDragTarget = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Show indicator for split view position
            if isSplitView && isSelected {
                Circle()
                    .fill(isPrimary ? Color.brutalistAccent : Color.brutalistAccent.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
            
            Text(tab.title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color.brutalistTextPrimary : Color.brutalistTextSecondary)
            
            if isHovering || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color.brutalistTextMuted)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color.brutalistBgTertiary : (isDragTarget ? Color.brutalistAccent.opacity(0.2) : Color.clear))
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .onDrag {
            NSItemProvider(object: tab.id.uuidString as NSString)
        }
        .onDrop(of: [.text], isTargeted: $isDragTarget) { providers in
            guard let provider = providers.first else { return false }
            provider.loadObject(ofClass: NSString.self) { item, _ in
                if let uuidString = item as? String, let fromId = UUID(uuidString: uuidString) {
                    DispatchQueue.main.async {
                        onMove(fromId, tab.id)
                    }
                }
            }
            return true
        }
    }
}

struct TerminalViewWrapper: NSViewRepresentable {
    let terminal: SolTerminalView
    
    func makeNSView(context: Context) -> SolTerminalView {
        return terminal
    }
    
    func updateNSView(_ nsView: SolTerminalView, context: Context) {
    }
}

class SolTerminalView: LocalProcessTerminalView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupContextMenu()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContextMenu()
    }
    
    private func setupContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(paste(_:)), keyEquivalent: "v")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Clear", action: #selector(clearTerminal), keyEquivalent: "k")
        self.menu = menu
    }
    
    @objc func clearTerminal() {
        self.send(txt: "clear\n")
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers {
                if chars == "c" {
                    copy(self)
                    return true
                } else if chars == "v" {
                    paste(self)
                    return true
                } else if chars == "k" {
                    clearTerminal()
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Terminal Tab Model

struct TerminalTab: Identifiable {
    let id: UUID
    let terminal: SolTerminalView
    var title: String
    
    init(title: String = "zsh") {
        self.id = UUID()
        self.terminal = SolTerminalView(frame: .zero)
        self.title = title
        
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminal.nativeForegroundColor = NSColor.white
        terminal.nativeBackgroundColor = NSColor.black
        terminal.configureNativeColors()
        terminal.getTerminal().silentLog = true
        
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        terminal.startProcess(executable: shell, args: ["-l"])
    }
}

// MARK: - Terminal Store with Tab Support and Split View

class TerminalStore: ObservableObject {
    static let shared = TerminalStore()
    
    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabId: UUID?
    @Published var secondaryTabId: UUID?  // For split view
    @Published var isSplitView: Bool = false
    
    var currentTab: TerminalTab? {
        tabs.first { $0.id == selectedTabId }
    }
    
    var leftTab: TerminalTab? {
        tabs.first { $0.id == selectedTabId }
    }
    
    var rightTab: TerminalTab? {
        if let secondaryId = secondaryTabId {
            return tabs.first { $0.id == secondaryId }
        }
        // Default to second tab if no secondary selected
        if tabs.count > 1, let primaryIndex = tabs.firstIndex(where: { $0.id == selectedTabId }) {
            let secondIndex = (primaryIndex + 1) % tabs.count
            return tabs[secondIndex]
        }
        return nil
    }
    
    var selectedTabIds: Set<UUID> {
        var ids: Set<UUID> = []
        if let id = selectedTabId { ids.insert(id) }
        if isSplitView, let id = secondaryTabId ?? rightTab?.id { ids.insert(id) }
        return ids
    }
    
    private init() {
        // Create initial tab
        addTab()
    }
    
    func addTab() {
        let tabNumber = tabs.count + 1
        let newTab = TerminalTab(title: "zsh \(tabNumber)")
        tabs.append(newTab)
        selectedTabId = newTab.id
    }
    
    func selectTab(_ id: UUID) {
        if isSplitView {
            // In split view, clicking a tab that's already shown does nothing
            // Clicking a different tab replaces the primary selection
            if id != selectedTabId && id != secondaryTabId {
                selectedTabId = id
            } else if id == secondaryTabId {
                // Swap: make secondary the primary
                secondaryTabId = selectedTabId
                selectedTabId = id
            }
        } else {
            selectedTabId = id
        }
    }
    
    func closeTab(_ id: UUID) {
        // Don't close if it's the last tab
        guard tabs.count > 1 else { return }
        
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: index)
            
            // If we closed the selected tab, select another
            if selectedTabId == id {
                selectedTabId = tabs.first?.id
            }
            
            // If we closed the secondary tab, clear it
            if secondaryTabId == id {
                secondaryTabId = nil
            }
            
            // If only one tab left, disable split view
            if tabs.count == 1 {
                isSplitView = false
            }
        }
    }
    
    func moveTab(from fromId: UUID, to toId: UUID) {
        guard fromId != toId,
              let fromIndex = tabs.firstIndex(where: { $0.id == fromId }),
              let toIndex = tabs.firstIndex(where: { $0.id == toId }) else {
            return
        }
        
        let tab = tabs.remove(at: fromIndex)
        tabs.insert(tab, at: toIndex)
    }
    
    func toggleSplitView() {
        isSplitView.toggle()
        
        if isSplitView && tabs.count > 1 {
            // Set secondary to first non-primary tab
            secondaryTabId = tabs.first { $0.id != selectedTabId }?.id
        } else {
            secondaryTabId = nil
        }
    }
    
    func clearCurrentTerminal() {
        currentTab?.terminal.send(txt: "clear\n")
    }
}
