//
//  ActivityMonitor.swift
//  SolUnified
//
//  System activity monitoring using NSWorkspace and Accessibility API
//

import Foundation
import AppKit
import ApplicationServices

class ActivityMonitor {
    static let shared = ActivityMonitor()
    
    private var observers: [NSObjectProtocol] = []
    private var windowTitleTimer: Timer?
    private var lastWindowTitle: String?
    private var lastWindowTitleTime: Date?
    private var currentApp: NSRunningApplication?
    private var currentSessionStartTime: Date?
    
    // Window tracking for closure detection
    private var trackedWindows: Set<String> = [] // Track window titles we've seen
    private var windowTrackingTimer: Timer?
    
    var onAppLaunch: ((NSRunningApplication) -> Void)?
    var onAppTerminate: ((NSRunningApplication) -> Void)?
    var onAppActivate: ((NSRunningApplication, NSRunningApplication?) -> Void)?
    var onWindowTitleChange: ((String?) -> Void)?
    var onWindowClosed: ((String?) -> Void)?
    var onScreenSleep: (() -> Void)?
    var onScreenWake: (() -> Void)?
    
    private init() {}
    
    func startMonitoring() {
        stopMonitoring()
        
        let nc = NSWorkspace.shared.notificationCenter
        
        // App launch
        observers.append(nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.onAppLaunch?(app)
        })
        
        // App termination
        observers.append(nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.onAppTerminate?(app)
        })
        
        // App activation (switching)
        observers.append(nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let previousApp = self?.currentApp
            self?.currentApp = app
            self?.currentSessionStartTime = Date()
            self?.onAppActivate?(app, previousApp)
            // Reset window title tracking when switching apps
            self?.lastWindowTitle = nil
            self?.lastWindowTitleTime = nil
        })
        
        // Screen sleep
        observers.append(nc.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onScreenSleep?()
        })
        
        // Screen wake
        observers.append(nc.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onScreenWake?()
        })
        
        // Initialize current app
        currentApp = NSWorkspace.shared.frontmostApplication
        currentSessionStartTime = Date()
        
        // Start window title polling
        startWindowTitlePolling()
        
        // Start window tracking for closure detection
        startWindowTracking()
    }
    
    func stopMonitoring() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        
        windowTitleTimer?.invalidate()
        windowTitleTimer = nil
        
        windowTrackingTimer?.invalidate()
        windowTrackingTimer = nil
        
        currentApp = nil
        currentSessionStartTime = nil
        lastWindowTitle = nil
        lastWindowTitleTime = nil
        trackedWindows.removeAll()
    }
    
    private func startWindowTitlePolling() {
        windowTitleTimer?.invalidate()
        
        windowTitleTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.checkWindowTitle()
        }
        
        if let timer = windowTitleTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // Check immediately
        checkWindowTitle()
    }
    
    private func startWindowTracking() {
        windowTrackingTimer?.invalidate()
        
        // Check for closed windows every 5 seconds
        windowTrackingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkWindowClosures()
        }
        
        if let timer = windowTrackingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func checkWindowTitle() {
        let title = getActiveWindowTitle()
        
        // Only log if title changed and it's been at least 10 seconds since last log
        if let title = title, title != lastWindowTitle {
            let now = Date()
            if lastWindowTitleTime == nil || now.timeIntervalSince(lastWindowTitleTime!) >= 10 {
                // Track this window
                trackedWindows.insert(title)
                onWindowTitleChange?(title)
                lastWindowTitle = title
                lastWindowTitleTime = now
            }
        } else if title == nil && lastWindowTitle != nil {
            // Window title became unavailable (e.g., app closed)
            trackedWindows.remove(lastWindowTitle!)
            lastWindowTitle = nil
            lastWindowTitleTime = Date()
        }
    }
    
    private func checkWindowClosures() {
        guard let currentTitle = getActiveWindowTitle() else {
            // No active window, check if we had tracked windows
            if let lastTitle = lastWindowTitle {
                trackedWindows.remove(lastTitle)
                onWindowClosed?(lastTitle)
                lastWindowTitle = nil
            }
            return
        }
        
        // Check if any tracked windows are no longer accessible
        let allWindows = getAllWindows()
        let activeWindows = Set(allWindows)
        
        for trackedWindow in trackedWindows {
            if !activeWindows.contains(trackedWindow) && trackedWindow != currentTitle {
                // Window was closed
                trackedWindows.remove(trackedWindow)
                onWindowClosed?(trackedWindow)
            }
        }
    }
    
    private func getAllWindows() -> [String] {
        guard AXIsProcessTrusted() else { return [] }
        
        var windows: [String] = []
        
        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            guard app.bundleIdentifier != nil else { continue }
            
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var windowList: AnyObject?
            guard AXUIElementCopyAttributeValue(
                appElement,
                kAXWindowsAttribute as CFString,
                &windowList
            ) == .success,
            let windowsRef = windowList as? [AXUIElement] else {
                continue
            }
            
            for window in windowsRef {
                var title: AnyObject?
                if AXUIElementCopyAttributeValue(
                    window,
                    kAXTitleAttribute as CFString,
                    &title
                ) == .success,
                let titleString = title as? String,
                !titleString.isEmpty {
                    windows.append(titleString)
                }
            }
        }
        
        return windows
    }
    
    func getActiveWindowTitle() -> String? {
        // Check Accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        guard accessEnabled else {
            return nil
        }
        
        // Skip tracking Sol Unified's own window
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return nil
        }
        
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        
        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        ) == .success,
        let app = focusedApp as! AXUIElement? else {
            return nil
        }
        
        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(
            app,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        ) == .success,
        let window = focusedWindow as! AXUIElement? else {
            return nil
        }
        
        var title: AnyObject?
        guard AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &title
        ) == .success,
        let titleString = title as? String else {
            return nil
        }
        
        return titleString.isEmpty ? nil : titleString
    }
    
    func getCurrentApp() -> NSRunningApplication? {
        return currentApp
    }
    
    func getCurrentSessionStartTime() -> Date? {
        return currentSessionStartTime
    }
    
    deinit {
        stopMonitoring()
    }
}

