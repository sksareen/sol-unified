//
//  WindowManager.swift
//  SolUnified
//
//  Custom NSWindow subclass for borderless window with keyboard support
//

import Cocoa
import SwiftUI

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .fullSizeContentView], backing: backingStoreType, defer: flag)
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
    }
}

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var isVisible = false
    private var window: BorderlessWindow?
    private let settings = AppSettings.shared
    
    private var windowWidth: CGFloat { settings.windowWidth }
    private var windowHeight: CGFloat { settings.windowHeight }
    
    private init() {}
    
    func setup(with contentView: some View) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let xPos = screenFrame.maxX - windowWidth - 20
        let yPos = screenFrame.maxY - windowHeight - 20
        
        let frame = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        
        window = BorderlessWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window?.contentView = NSHostingView(rootView: contentView)
        window?.setFrameTopLeftPoint(NSPoint(x: xPos, y: yPos + windowHeight))
        
        // Initially hide the window off-screen
        hideWindow(animated: false)
    }
    
    func toggleWindow() {
        isVisible ? hideWindow(animated: true) : showWindow(animated: true)
    }
    
    func showWindow(animated: Bool) {
        guard let window = window, let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let targetX = screenFrame.maxX - windowWidth - 20
        let targetY = screenFrame.maxY - windowHeight - 20
        let targetFrame = NSRect(x: targetX, y: targetY, width: windowWidth, height: windowHeight)
        
        if animated {
            // Slide in animation - 210ms with easeOut
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.21
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    func hideWindow(animated: Bool) {
        guard let window = window, let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let hiddenX = screenFrame.maxX + 50 // Off-screen to the right
        let targetY = screenFrame.maxY - windowHeight - 20
        let hiddenFrame = NSRect(x: hiddenX, y: targetY, width: windowWidth, height: windowHeight)
        
        if animated {
            // Slide out animation - 150ms with easeIn
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().setFrame(hiddenFrame, display: true)
            }) {
                window.orderOut(nil)
            }
        } else {
            window.setFrame(hiddenFrame, display: true)
            window.orderOut(nil)
        }
        
        isVisible = false
    }
}

