//
//  AppDelegate.swift
//  SolUnified
//
//  App delegate for window and system event management
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: WindowManager?
    var hotkeyManager = HotkeyManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (app is menu bar only with hotkey)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize database
        if !Database.shared.initialize() {
            print("Failed to initialize database")
        }
        
        // Create main content view
        let contentView = TabNavigator()
            .environmentObject(WindowManager.shared)
        
        // Setup window manager
        windowManager = WindowManager.shared
        windowManager?.setup(with: contentView)
        
        // Register global hotkey
        let registered = hotkeyManager.register {
            DispatchQueue.main.async {
                WindowManager.shared.toggleWindow()
            }
        }
        
        if !registered {
            print("Failed to register hotkey")
        }
        
        // Setup local event monitor for Tab key (before clipboard to avoid conflicts)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 48 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [] {
                // Tab key pressed
                NotificationCenter.default.post(name: NSNotification.Name("CycleTab"), object: nil)
                return nil // Consume the event
            }
            return event
        }
        
        // Start clipboard monitoring after a small delay to ensure app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ClipboardMonitor.shared.startMonitoring()
        }
        
        print("Sol Unified started successfully")
        print("Press Option+` to show/hide the window")
        print("Press Tab to cycle through tabs")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        ClipboardMonitor.shared.stopMonitoring()
        hotkeyManager.unregister()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowManager.shared.showWindow(animated: true)
        }
        return true
    }
}

