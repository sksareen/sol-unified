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
    var memoryTracker = MemoryTracker.shared
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (app is menu bar only with hotkey)
        NSApp.setActivationPolicy(.accessory)
        
        // Create menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Sol-Unified")
            button.action = #selector(toggleWindow)
            button.target = self
        }
        
        // Create menu for status item
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide (⌥`)", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        // Initialize database
        if !Database.shared.initialize() {
            print("Failed to initialize database")
        }
        
        // Initialize activity store
        let activityStore = ActivityStore.shared
        
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
        
        // Removed Tab key cycling - using individual tab shortcuts instead
        
        // Start monitoring after a small delay to ensure app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ClipboardMonitor.shared.startMonitoring()
            
            // Start screenshot auto-monitoring
            let screenshotsDir = AppSettings.shared.screenshotsDirectory
            ScreenshotScanner.shared.startMonitoring(directory: screenshotsDir)
            
            // Start activity monitoring if enabled
            if AppSettings.shared.activityLoggingEnabled {
                activityStore.startMonitoring()
            }
            
            // Start memory tracking for agent intelligence
            print("🧠 Starting memory tracking for agent bridge")
            self.memoryTracker.updateContextFile() // Initial update
            
            // Cleanup old activity logs based on retention setting
            let retentionDays = AppSettings.shared.activityLogRetentionDays
            _ = Database.shared.cleanupOldActivityLogs(olderThan: retentionDays)
        }
        
        print("Sol Unified started successfully")
        print("Press Option+` to show/hide the window")
    }
    
    @objc func toggleWindow() {
        WindowManager.shared.toggleWindow()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        ClipboardMonitor.shared.stopMonitoring()
        ScreenshotScanner.shared.stopMonitoring()
        ActivityStore.shared.stopMonitoring()
        hotkeyManager.unregister()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowManager.shared.showWindow(animated: true)
        }
        return true
    }
}

