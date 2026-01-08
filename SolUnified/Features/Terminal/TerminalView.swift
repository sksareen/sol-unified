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
                        TerminalPane(tab: leftTab, isActive: terminalStore.selectedTabId == leftTab.id, onActivate: {
                            terminalStore.selectTab(leftTab.id)
                        })
                    }
                    if let rightTab = terminalStore.rightTab {
                        TerminalPane(tab: rightTab, isActive: terminalStore.selectedTabId == rightTab.id, onActivate: {
                            terminalStore.selectTab(rightTab.id)
                        })
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
    var onActivate: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Pane header - clicking here activates the pane
            HStack {
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isActive ? Color.brutalistAccent : Color.brutalistTextMuted)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.brutalistAccent.opacity(0.1) : Color.black.opacity(0.3))
            .onTapGesture {
                onActivate?()
            }
            
            TerminalViewWrapper(terminal: tab.terminal, onActivate: onActivate)
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
    var onActivate: (() -> Void)? = nil
    
    func makeNSView(context: Context) -> NSView {
        // Wrap in a container that handles keyboard events properly
        let container = TerminalContainerView(terminal: terminal, onActivate: onActivate)
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Ensure terminal stays first responder when view updates
        if let container = nsView as? TerminalContainerView {
            container.window?.makeFirstResponder(container.terminal)
        }
    }
}

/// Container view that ensures the terminal becomes first responder and receives keyboard events
class TerminalContainerView: NSView {
    let terminal: SolTerminalView
    var onActivate: (() -> Void)?
    
    init(terminal: SolTerminalView, onActivate: (() -> Void)? = nil) {
        self.terminal = terminal
        self.onActivate = onActivate
        super.init(frame: .zero)
        self.autoresizesSubviews = true
        terminal.translatesAutoresizingMaskIntoConstraints = false
        addSubview(terminal)
        
        NSLayoutConstraint.activate([
            terminal.topAnchor.constraint(equalTo: topAnchor),
            terminal.bottomAnchor.constraint(equalTo: bottomAnchor),
            terminal.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        // When container becomes first responder, forward to terminal
        window?.makeFirstResponder(terminal)
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(terminal)
        onActivate?()
        terminal.mouseDown(with: event)
    }
    
    // Forward keyboard events to terminal
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        return terminal.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        terminal.keyDown(with: event)
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
        menu.addItem(withTitle: "Copy", action: #selector(doCopy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(doPaste(_:)), keyEquivalent: "v")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "a")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Clear", action: #selector(clearTerminal), keyEquivalent: "k")
        self.menu = menu
    }
    
    // Validate menu items - enable our custom actions
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(doCopy(_:)):
            // Always enable - copy does nothing if no selection
            return true
        case #selector(doPaste(_:)):
            // Enable if clipboard has text
            return NSPasteboard.general.string(forType: .string) != nil
        case #selector(clearTerminal):
            return true
        case #selector(selectAll(_:)):
            return true
        default:
            return super.validateUserInterfaceItem(item)
        }
    }
    
    @objc func clearTerminal() {
        self.send(txt: "clear\n")
    }
    
    @objc func doCopy(_ sender: Any?) {
        // Call the parent class's copy method which handles selection and clipboard
        super.copy(sender as Any)
    }
    
    @objc func doPaste(_ sender: Any?) {
        // Get text from clipboard and send directly to terminal
        if let text = NSPasteboard.general.string(forType: .string) {
            self.send(txt: text)
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        
        if let chars = event.charactersIgnoringModifiers {
            switch chars {
            case "c":
                doCopy(self)
                return true
            case "v":
                doPaste(self)
                return true
            case "a":
                selectAll(self)
                return true
            case "k":
                clearTerminal()
                return true
            default:
                break
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
    
    init(title: String = "zsh", workingDirectory: String? = nil) {
        self.id = UUID()
        self.terminal = SolTerminalView(frame: .zero)
        self.title = title

        let fontSize = AppSettings.shared.globalFontSize
        terminal.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminal.nativeForegroundColor = NSColor.white
        terminal.nativeBackgroundColor = NSColor.black
        terminal.configureNativeColors()
        terminal.getTerminal().silentLog = true

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        terminal.startProcess(executable: shell, args: ["-l"])

        // Change to context directory so Claude Code has immediate access to context
        // Default to ~/Documents/sol-context where the CLAUDE.md and context.json live
        let contextDir = workingDirectory ?? NSString("~/Documents/sol-context").expandingTildeInPath
        if FileManager.default.fileExists(atPath: contextDir) {
            let terminalRef = terminal  // Capture terminal, not self (struct)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                terminalRef.send(txt: "cd \"\(contextDir)\" && clear\n")
            }
        }
        
        // Listen for font size changes
        NotificationCenter.default.addObserver(forName: NSNotification.Name("GlobalFontSizeChanged"), object: nil, queue: .main) { [weak terminal] _ in
            let newSize = AppSettings.shared.globalFontSize
            terminal?.font = NSFont.monospacedSystemFont(ofSize: newSize, weight: .regular)
        }
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
    
    func cycleToNextTab() {
        guard tabs.count > 1,
              let currentIndex = tabs.firstIndex(where: { $0.id == selectedTabId }) else {
            return
        }
        let nextIndex = (currentIndex + 1) % tabs.count
        selectedTabId = tabs[nextIndex].id
    }
    
    func cycleToPreviousTab() {
        guard tabs.count > 1,
              let currentIndex = tabs.firstIndex(where: { $0.id == selectedTabId }) else {
            return
        }
        let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
        selectedTabId = tabs[prevIndex].id
    }
}
