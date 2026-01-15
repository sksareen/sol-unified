//
//  DriftMonitor.swift
//  SolUnified
//
//  The "Entropy Dampener" - passively monitors app usage and gently corrects
//  when the user drifts to distraction apps during an active objective.
//
//  Detection: User switches to "Distraction Category" app for > 30s while Objective is active.
//  Intervention: Screen dims with a glowing prompt to resume work.
//

import Foundation
import Cocoa
import SwiftUI
import Combine

class DriftMonitor: ObservableObject {
    static let shared = DriftMonitor()

    // MARK: - Configuration

    /// Apps considered distractions (bundle IDs)
    private let distractionApps: Set<String> = [
        "com.twitter.twitter-mac",
        "com.twitterinc.twitter-mac",
        "com.atebits.Tweetie2",
        "reddit.Reddit",
        "com.reddit.Reddit",
        "com.facebook.Facebook",
        "com.instagram.Instagram",
        "com.tiktok.tiktok",
        "tv.twitch.TwitchDesktop",
        "com.apple.news",
        "us.zoom.xos", // optional: meetings during deep work
    ]

    /// Keywords in app names that indicate distraction
    private let distractionKeywords: [String] = [
        "twitter", "reddit", "facebook", "instagram", "tiktok",
        "youtube", "netflix", "hulu", "twitch", "news"
    ]

    /// Time before intervention (seconds)
    let distractionThreshold: TimeInterval = 30

    // MARK: - State

    @Published var isMonitoring: Bool = false
    @Published var currentDistraction: DistractionEvent?
    @Published var isShowingOverlay: Bool = false

    private let objectiveStore = ObjectiveStore.shared
    private var distractionTimer: Timer?
    private var distractionStartTime: Date?
    private var distractionApp: String?
    private var previousWorkApp: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupObservers()
    }

    // MARK: - Public API

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        print("👀 Drift monitor started")
    }

    func stopMonitoring() {
        isMonitoring = false
        cancelDistractionTimer()
        hideOverlay()
        print("👀 Drift monitor stopped")
    }

    /// User chose to resume work
    func resumeWork() {
        hideOverlay()
        recordDriftRecovery(recovered: true)

        // Activate the previous work app
        if let bundleId = previousWorkApp,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            app.activate(options: .activateIgnoringOtherApps)
        }

        print("✓ Resumed work from drift")
    }

    /// User acknowledged they're taking a break
    func acknowledgeBreak() {
        hideOverlay()
        recordDriftRecovery(recovered: false)
        objectiveStore.pauseObjective()
        print("⏸ Break acknowledged, objective paused")
    }

    // MARK: - Private: Observation

    private func setupObservers() {
        // Watch for app activations
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivation(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Watch for objective changes
        objectiveStore.$currentObjective
            .receive(on: DispatchQueue.main)
            .sink { [weak self] objective in
                if objective == nil {
                    self?.cancelDistractionTimer()
                    self?.hideOverlay()
                }
            }
            .store(in: &cancellables)
    }

    @objc private func handleAppActivation(_ notification: Notification) {
        guard isMonitoring,
              let objective = objectiveStore.currentObjective,
              !objective.isPaused else {
            cancelDistractionTimer()
            return
        }

        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else { return }

        let isDistraction = isDistractionApp(bundleId: bundleId, appName: appName)

        if isDistraction {
            // Started using a distraction app
            if distractionStartTime == nil {
                distractionStartTime = Date()
                distractionApp = appName
                startDistractionTimer()
                print("⚠️ Distraction detected: \(appName)")
            }
        } else {
            // Switched to a non-distraction app
            if distractionStartTime != nil {
                cancelDistractionTimer()
                print("✓ Left distraction app naturally")
            }
            // Track this as potential "work app" to return to
            previousWorkApp = bundleId
        }
    }

    private func isDistractionApp(bundleId: String, appName: String) -> Bool {
        // Check bundle ID
        if distractionApps.contains(bundleId) {
            return true
        }

        // Check app name keywords
        let lowercaseName = appName.lowercased()
        for keyword in distractionKeywords {
            if lowercaseName.contains(keyword) {
                return true
            }
        }

        // Check browser URLs (if Safari or Chrome, could check URL - future enhancement)

        return false
    }

    // MARK: - Private: Timer Management

    private func startDistractionTimer() {
        cancelDistractionTimer()

        distractionTimer = Timer.scheduledTimer(withTimeInterval: distractionThreshold, repeats: false) { [weak self] _ in
            self?.triggerIntervention()
        }
    }

    private func cancelDistractionTimer() {
        distractionTimer?.invalidate()
        distractionTimer = nil
        distractionStartTime = nil
        distractionApp = nil
    }

    // MARK: - Private: Intervention

    private func triggerIntervention() {
        guard let objective = objectiveStore.currentObjective,
              let distractionApp = distractionApp else { return }

        currentDistraction = DistractionEvent(
            distractionApp: distractionApp,
            objectiveText: objective.text,
            startTime: distractionStartTime ?? Date()
        )

        DispatchQueue.main.async {
            self.showOverlay()
        }

        print("🔴 Drift intervention triggered for: \(distractionApp)")
    }

    private func showOverlay() {
        isShowingOverlay = true
        DriftOverlayController.shared.show(
            objectiveText: objectiveStore.currentObjective?.text ?? "your task",
            onResume: { [weak self] in self?.resumeWork() },
            onBreak: { [weak self] in self?.acknowledgeBreak() }
        )
    }

    private func hideOverlay() {
        isShowingOverlay = false
        DriftOverlayController.shared.hide()
        currentDistraction = nil
    }

    private func recordDriftRecovery(recovered: Bool) {
        guard let distraction = currentDistraction else { return }

        let duration = Date().timeIntervalSince(distraction.startTime)

        // Log to database for analytics
        let eventData = """
        {"distraction_app": "\(distraction.distractionApp)", "duration": \(duration), "recovered": \(recovered)}
        """

        Database.shared.execute("""
            INSERT INTO activity_log (event_type, app_name, event_data, timestamp, created_at)
            VALUES (?, ?, ?, ?, ?)
        """, parameters: [
            recovered ? "drift_recovery" : "drift_break",
            distraction.distractionApp,
            eventData,
            Database.dateToString(Date()),
            Database.dateToString(Date())
        ])
    }
}

// MARK: - Models

struct DistractionEvent {
    let distractionApp: String
    let objectiveText: String
    let startTime: Date

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

// MARK: - Drift Overlay Controller

class DriftOverlayController {
    static let shared = DriftOverlayController()

    private var overlayWindow: NSWindow?
    private var onResume: (() -> Void)?
    private var onBreak: (() -> Void)?

    private init() {}

    func show(objectiveText: String, onResume: @escaping () -> Void, onBreak: @escaping () -> Void) {
        self.onResume = onResume
        self.onBreak = onBreak

        // Create full-screen overlay
        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = DriftOverlayView(
            objectiveText: objectiveText,
            onResume: { [weak self] in
                self?.onResume?()
            },
            onBreak: { [weak self] in
                self?.onBreak?()
            }
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        overlayWindow = window

        // Monitor for Enter and Escape keys
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 36 { // Enter
                self?.onResume?()
                return nil
            } else if event.keyCode == 53 { // Escape
                self?.onBreak?()
                return nil
            }
            return event
        }
    }

    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}

// MARK: - Drift Overlay View

struct DriftOverlayView: View {
    let objectiveText: String
    let onResume: () -> Void
    let onBreak: () -> Void

    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black
                .opacity(0.85)
                .edgesIgnoringSafeArea(.all)

            // Content
            VStack(spacing: 24) {
                // Glowing text
                Text("We were working on")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.6))

                Text(objectiveText)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .white.opacity(0.3), radius: 20)

                Text("Resume?")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.6))

                // Keyboard hints
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("↵ Enter")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.green)
                        Text("Resume work")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    VStack(spacing: 4) {
                        Text("Esc")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange)
                        Text("Take a break")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.top, 20)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1
            }
        }
    }
}
