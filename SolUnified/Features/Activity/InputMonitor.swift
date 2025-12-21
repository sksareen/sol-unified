//
//  InputMonitor.swift
//  SolUnified
//
//  Keyboard and mouse input monitoring using CGEventTap
//

import Foundation
import AppKit
import CoreGraphics

// Compact logging
private let log = ActivityLogger.shared

class InputMonitor {
    static let shared = InputMonitor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyboardEnabled = false
    private var mouseEnabled = false
    
    // Aggregation for high-volume events
    private var keyPressCount = 0
    private var mouseClickCount = 0
    private var mouseMoveCount = 0
    private var mouseScrollCount = 0
    private var lastAggregationTime = Date()
    private let aggregationInterval: TimeInterval = 5.0 // Aggregate every 5 seconds
    
    var onKeyPress: ((String?, CGKeyCode) -> Void)?
    var onMouseClick: ((NSPoint, Int) -> Void)? // position, button
    var onMouseMove: ((NSPoint) -> Void)?
    var onMouseScroll: ((NSPoint, Double) -> Void)? // position, delta
    
    private init() {}
    
    func startMonitoring() {
        guard !keyboardEnabled else { return }
        
        // Check Input Monitoring permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        guard accessEnabled else {
            log.logError("keyboard: no permission")
            return
        }
        
        // Create event tap for keyboard events using new API
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        guard let eventTap = eventTap else {
            log.logError("keyboard: tap failed")
            return
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        keyboardEnabled = true
        lastAggregationTime = Date()
        
        log.logStatus("Keyboard: ON", symbol: "⌨️")
    }
    
    func stopMonitoring() {
        guard keyboardEnabled else { return }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        
        keyboardEnabled = false
        log.logStatus("Keyboard: OFF", symbol: "⌨️")
    }
    
    func startMouseTracking() {
        guard !mouseEnabled else { return }
        
        // Check Input Monitoring permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        guard accessEnabled else {
            log.logError("mouse: no permission")
            return
        }
        
        // Create event tap for mouse events if not already created
        if eventTap == nil {
            let eventMask = CGEventMask(
                (1 << CGEventType.leftMouseDown.rawValue) |
                (1 << CGEventType.rightMouseDown.rawValue) |
                (1 << CGEventType.otherMouseDown.rawValue) |
                (1 << CGEventType.mouseMoved.rawValue) |
                (1 << CGEventType.scrollWheel.rawValue)
            )
            
            eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: eventCallback,
                userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )
            
            guard let eventTap = eventTap else {
                log.logError("mouse: tap failed")
                return
            }
            
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            self.runLoopSource = runLoopSource
            
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        
        mouseEnabled = true
        log.logStatus("Mouse: ON", symbol: "🖱️")
    }
    
    func stopMouseTracking() {
        guard mouseEnabled else { return }
        
        mouseEnabled = false
        
        // Only stop event tap if keyboard is also disabled
        if !keyboardEnabled {
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                self.runLoopSource = nil
            }
            
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: false)
                CFMachPortInvalidate(eventTap)
                self.eventTap = nil
            }
        }
        
        log.logStatus("Mouse: OFF", symbol: "🖱️")
    }
    
    func handleKeyPress(_ event: CGEvent) {
        guard keyboardEnabled else { return }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Skip modifier keys (Shift, Ctrl, Option, Cmd)
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        if flags.intersection(modifiers) == flags {
            return
        }
        
        keyPressCount += 1
        
        // Aggregate and call callback periodically
        let now = Date()
        if now.timeIntervalSince(lastAggregationTime) >= aggregationInterval {
            onKeyPress?("\(keyPressCount) keys", CGKeyCode(keyCode))
            keyPressCount = 0
            lastAggregationTime = now
        }
    }
    
    func handleMouseClick(_ event: CGEvent) {
        guard mouseEnabled else { return }
        
        let location = event.location
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        
        mouseClickCount += 1
        
        // Aggregate clicks
        let now = Date()
        if now.timeIntervalSince(lastAggregationTime) >= aggregationInterval {
            onMouseClick?(NSPoint(x: location.x, y: location.y), Int(buttonNumber))
            mouseClickCount = 0
        }
    }
    
    func handleMouseMove(_ event: CGEvent) {
        guard mouseEnabled else { return }
        
        let location = event.location
        mouseMoveCount += 1
        
        // Only log mouse moves every 10 seconds to avoid spam
        let now = Date()
        if mouseMoveCount >= 100 || now.timeIntervalSince(lastAggregationTime) >= 10.0 {
            onMouseMove?(NSPoint(x: location.x, y: location.y))
            mouseMoveCount = 0
            lastAggregationTime = now
        }
    }
    
    func handleMouseScroll(_ event: CGEvent) {
        guard mouseEnabled else { return }
        
        let location = event.location
        let scrollDelta = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        
        mouseScrollCount += 1
        
        // Aggregate scrolls
        let now = Date()
        if now.timeIntervalSince(lastAggregationTime) >= aggregationInterval {
            onMouseScroll?(NSPoint(x: location.x, y: location.y), scrollDelta)
            mouseScrollCount = 0
        }
    }
}

// C callback for CGEventTap
private func eventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }
    
    let monitor = Unmanaged<InputMonitor>.fromOpaque(refcon).takeUnretainedValue()
    
    switch type {
    case .keyDown:
        monitor.handleKeyPress(event)
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
        monitor.handleMouseClick(event)
    case .mouseMoved:
        monitor.handleMouseMove(event)
    case .scrollWheel:
        monitor.handleMouseScroll(event)
    default:
        break
    }
    
    // Return event unchanged (don't intercept)
    return Unmanaged.passUnretained(event)
}
