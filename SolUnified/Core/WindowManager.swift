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
        self.isMovableByWindowBackground = false // Disable dragging from anywhere - we'll handle it in SwiftUI
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
    }
}

class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()
    
    @Published var isVisible = false
    private var window: BorderlessWindow?
    private let settings = AppSettings.shared
    
    private var windowWidth: CGFloat { settings.windowWidth }
    private var windowHeight: CGFloat { settings.windowHeight }
    
    private override init() {
        super.init()
    }
    
    func setup(with contentView: some View) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let xPos = screenFrame.maxX - windowWidth - 20 - 38
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
        
        // Set up window delegate to detect when window loses focus
        window?.delegate = self
        
        // Initially hide the window off-screen
        hideWindow(animated: false)
    }
    
    func toggleWindow() {
        isVisible ? hideWindow(animated: true) : showWindow(animated: true)
    }
    
    func showWindow(animated: Bool) {
        guard let window = window, let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let targetX = screenFrame.maxX - windowWidth - 20 + 20
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
        InternalAppTracker.shared.trackWindowShow()
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
        InternalAppTracker.shared.trackWindowHide()
    }
}

// MARK: - NSWindowDelegate
extension WindowManager: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        // Don't hide if settings sheet is showing
        if AppSettings.shared.showSettings {
            return
        }
        
        // Don't hide if any sheets/modals are attached to our window
        if let window = window, window.sheets.count > 0 {
            return
        }
        
        // Don't hide if the key window is a sheet attached to our window
        if let keyWindow = NSApp.keyWindow, keyWindow != window {
            // Check if it's a sheet attached to our window
            if keyWindow.isSheet, keyWindow.parent == window {
                return
            }
        }
        
        // Only hide if window is still visible and we're actually clicking outside
        // Add a small delay to distinguish between sheet appearance and actual click-outside
        if isVisible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                
                // Re-check conditions after delay
                if AppSettings.shared.showSettings {
                    return
                }
                
                if let window = self.window, window.sheets.count > 0 {
                    return
                }
                
                // Only hide if we're still not the key window and no sheets are showing
                if self.isVisible && NSApp.keyWindow != self.window {
                    // Final check: if key window is our window's child (sheet), don't hide
                    if let keyWindow = NSApp.keyWindow, keyWindow.parent == self.window {
                        return
                    }
                    self.hideWindow(animated: true)
                }
            }
        }
    }
}

