//
//  ValueComputer.swift
//  SolUnified
//
//  The "Sensor" for the Causal Inference Engine.
//  Aggregates raw activity into neural values (State Vectors).
//

import Foundation
import Combine
import Vision
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

class ValueComputer: ObservableObject {
    static let shared = ValueComputer()
    
    @Published var isRunning = false
    @Published var lastState: (focus: Double, velocity: Double, context: String)?
    
    private var timer: Timer?
    private let db = Database.shared
    
    // Thresholds
    private let focusDecayPerSwitch = 0.05
    private let maxVelocity = 300.0 // approx max actions per minute
    
    // Private folder for neural snapshots
    private let snapshotDirectory: URL
    
    private init() {
        // Setup hidden directory for snapshots
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.snapshotDirectory = home.appendingPathComponent(".sol-unified/neural_snapshots")
        try? FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
    }
    
    func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        
        // Run every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.computeAndStore()
            }
        }
        print("🧠 ValueComputer started")
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    private func computeAndStore() async {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        
        // 1. Fetch Raw Events
        let events = ActivityStore.shared.getEvents(from: oneMinuteAgo, to: now)
        
        // 2. Compute Velocity & Focus (The "Body")
        let (focusScore, velocityScore, dominantApp) = computeBodyMetrics(events: events)
        
        // 3. Compute Context (The "Eyes") - Trigger Vision if needed
        var contextLabel = dominantApp
        var primaryActivity = dominantApp
        
        // If context is ambiguous (Browser/Social), use Vision to get ground truth
        // Or randomly sample every 5 mins to build dataset
        let needsVision = isAmbiguousContext(dominantApp) || Int.random(in: 0...4) == 0
        
        if needsVision {
            if let (tag, description) = await captureAndAnalyzeContext() {
                contextLabel = tag
                primaryActivity = description // Store the "OCR Summary" as the activity
            }
        }
        
        // 4. Compute Energy (The "Battery") - Inferred
        let energyLevel = inferEnergyLevel(at: now)
        
        // 5. Store
        storeValue(
            timestamp: now,
            focus: focusScore,
            velocity: velocityScore,
            energy: energyLevel,
            context: contextLabel,
            primaryActivity: primaryActivity
        )
        
        await MainActor.run {
            self.lastState = (focusScore, velocityScore, contextLabel)
        }
    }
    
    // MARK: - Metrics Logic
    
    private func computeBodyMetrics(events: [ActivityEvent]) -> (Double, Double, String) {
        if events.isEmpty {
            return (1.0, 0.0, "idle")
        }
        
        // Focus: 1.0 - (App Switches * Penalty)
        let appSwitches = events.filter { $0.eventType == .appActivate }.count
        let rawFocus = 1.0 - (Double(appSwitches) * focusDecayPerSwitch)
        let focusScore = max(0.0, min(1.0, rawFocus))
        
        // Velocity: Actions / MaxCapacity
        let actions = events.filter {
            $0.eventType == .keyPress ||
            $0.eventType == .mouseClick ||
            $0.eventType == .internalNoteEdit
        }.count
        let velocityScore = min(1.0, Double(actions) / maxVelocity)
        
        // Dominant App
        let dominantApp = events
            .compactMap { $0.appName }
            .reduce(into: [:]) { counts, app in counts[app, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key ?? "unknown"
            
        return (focusScore, velocityScore, dominantApp)
    }
    
    private func inferEnergyLevel(at date: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 9 && hour <= 11 { return 0.9 } // Morning Peak
        else if hour >= 14 && hour <= 16 { return 0.4 } // Afternoon Slump
        else if hour >= 22 || hour < 6 { return 0.3 } // Sleepy
        else { return 0.6 } // Baseline
    }
    
    private func isAmbiguousContext(_ appName: String) -> Bool {
        let ambiguousApps = ["Google Chrome", "Safari", "Arc", "Firefox", "Slack", "Discord"]
        return ambiguousApps.contains(appName)
    }
    
    // MARK: - Vision Logic
    
    private func captureAndAnalyzeContext() async -> (String, String)? {
        // 1. Capture Screen (Hidden)
        guard let screenImage = CGWindowListCreateImage(.infinite, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) else {
            return nil
        }
        
        // 2. Save to temp file (Analyzer expects file)
        // Note: Ideally Analyzer would accept CGImage directly, but for now we bridge via file
        // to match existing API, or we update Analyzer.
        // Let's assume we update Analyzer later to take CGImage, but for now we write.
        let filename = "neural_\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = snapshotDirectory.appendingPathComponent(filename)
        
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, screenImage, nil)
        if !CGImageDestinationFinalize(destination) {
            return nil
        }
        
        // 3. Analyze
        // Create a temporary Screenshot object to pass to Analyzer
        let tempScreenshot = Screenshot(
            filename: filename,
            filepath: fileURL.path,
            fileHash: "temp",
            fileSize: 0,
            createdAt: Date(),
            modifiedAt: Date(),
            width: screenImage.width,
            height: screenImage.height
        )
        
        do {
            let result = try await ScreenshotAnalyzer.shared.analyzeScreenshot(tempScreenshot)
            
            // Cleanup: We keep the file for now in .sol-unified/neural_snapshots for future auditing
            // Or delete if you want strict privacy
            // try? FileManager.default.removeItem(at: fileURL)
            
            return (result.tags, result.description) // Tags become context, Desc becomes activity
        } catch {
            print("🧠 Vision Error: \(error)")
            return nil
        }
    }
    
    // MARK: - Storage
    
    private func storeValue(timestamp: Date, focus: Double, velocity: Double, energy: Double, context: String, primaryActivity: String) {
        let sql = """
            INSERT INTO neural_values 
            (timestamp, focus_score, velocity_score, energy_level, context_label, primary_activity, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        _ = db.execute(sql, parameters: [
            Database.dateToString(timestamp),
            focus,
            velocity,
            energy,
            context,
            primaryActivity,
            Database.dateToString(Date())
        ])
        
        print("🧠 State Vector: F=\(String(format: "%.2f", focus)) V=\(String(format: "%.2f", velocity)) C=\(context)")
    }
}

