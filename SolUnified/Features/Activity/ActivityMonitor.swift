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
    
    var onAppLaunch: ((NSRunningApplication) -> Void)?
    var onAppTerminate: ((NSRunningApplication) -> Void)?
    var onAppActivate: ((NSRunningApplication, NSRunningApplication?) -> Void)?
    var onWindowTitleChange: ((String?) -> Void)?
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
    }
    
    func stopMonitoring() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        
        windowTitleTimer?.invalidate()
        windowTitleTimer = nil
        
        currentApp = nil
        currentSessionStartTime = nil
        lastWindowTitle = nil
        lastWindowTitleTime = nil
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
    
    private func checkWindowTitle() {
        let title = getActiveWindowTitle()
        
        // Only log if title changed and it's been at least 10 seconds since last log
        if let title = title, title != lastWindowTitle {
            let now = Date()
            if lastWindowTitleTime == nil || now.timeIntervalSince(lastWindowTitleTime!) >= 10 {
                onWindowTitleChange?(title)
                lastWindowTitle = title
                lastWindowTitleTime = now
            }
        } else if title == nil && lastWindowTitle != nil {
            // Window title became unavailable (e.g., app closed)
            lastWindowTitle = nil
            lastWindowTitleTime = Date()
        }
    }
    
    func getActiveWindowTitle() -> String? {
        // Check Accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        guard accessEnabled else {
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

