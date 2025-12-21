//
//  IdleDetector.swift
//  SolUnified
//
//  System idle detection for activity logging
//

import Foundation
import AppKit
import CoreGraphics

class IdleDetector {
    static let shared = IdleDetector()
    
    private var timer: Timer?
    private var isIdle: Bool = false
    private let idleThreshold: TimeInterval = 300 // 5 minutes
    private let checkInterval: TimeInterval = 60 // Check every 60 seconds
    
    var onIdleStart: (() -> Void)?
    var onIdleEnd: (() -> Void)?
    
    private init() {}
    
    func startMonitoring() {
        stopMonitoring()
        
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkIdleStatus()
        }
        
        // Add to common run loop modes to keep running when app is inactive
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkIdleStatus() {
        let idleTime = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
        
        if idleTime >= idleThreshold && !isIdle {
            // User became idle
            isIdle = true
            onIdleStart?()
        } else if idleTime < idleThreshold && isIdle {
            // User returned from idle
            isIdle = false
            onIdleEnd?()
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

