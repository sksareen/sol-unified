//
//  TimerStore.swift
//  SolUnified
//
//  Timer state management
//

import Foundation
import AppKit
import AudioToolbox

class TimerStore: ObservableObject {
    static let shared = TimerStore()
    
    @Published var isRunning: Bool = false
    @Published var timeRemaining: TimeInterval = 300 // default 5 minutes
    @Published var totalDuration: TimeInterval = 0 // in seconds
    @Published var selectedDuration: TimeInterval = 300 // default 5 minutes
    
    private var timer: Timer?
    private var chimeTimer: Timer?
    private var sound: NSSound?
    private var chimePlayCount: Int = 0
    
    private init() {}
    
    func startTimer() {
        guard !isRunning else { return }
        
        // If timer was reset or stopped, use selected duration
        if timeRemaining == 0 || totalDuration == 0 {
            timeRemaining = selectedDuration
            totalDuration = selectedDuration
        }
        
        isRunning = true
        
        // Create timer that persists across view lifecycle
        // Ensure timer runs on main thread to keep it active when app is hidden
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            
            // Add timer to common run loop modes to keep it running when app is hidden
            RunLoop.main.add(self.timer!, forMode: .common)
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    func resetTimer() {
        stopTimer()
        timeRemaining = selectedDuration
        totalDuration = 0
    }
    
    func setDuration(_ duration: TimeInterval) {
        guard !isRunning else { return }
        selectedDuration = duration
        timeRemaining = duration
        totalDuration = duration
    }
    
    private func tick() {
        // Ensure UI updates happen on main thread
        guard timeRemaining > 0 else {
            completeTimer()
            return
        }
        
        timeRemaining -= 1.0
    }
    
    private func completeTimer() {
        stopTimer()
        playChime()
    }
    
    private func playChime() {
        // Play system chime sound continuously for 5 seconds
        if let chimeSound = NSSound(named: "Glass") {
            sound = chimeSound
            chimeSound.loops = true
            chimeSound.play()
            
            // Stop chime after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.sound?.stop()
                self?.sound = nil
            }
        } else {
            // Fallback: use system sound - play multiple times for 5 seconds
            chimePlayCount = 0
            let maxPlays = 10 // Play every 0.5 seconds for 5 seconds
            
            chimeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                self.chimePlayCount += 1
                AudioServicesPlaySystemSound(1016)
                
                if self.chimePlayCount >= maxPlays {
                    timer.invalidate()
                    self.chimeTimer = nil
                    self.chimePlayCount = 0
                }
            }
        }
    }
    
    func formatTime(_ seconds: TimeInterval) -> String {
        let clampedSeconds = max(0, Int(seconds))
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    deinit {
        timer?.invalidate()
        chimeTimer?.invalidate()
        sound?.stop()
    }
}

