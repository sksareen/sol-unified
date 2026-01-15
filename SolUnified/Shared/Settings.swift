//
//  Settings.swift
//  SolUnified v2.0
//
//  Simplified settings for the focused v2 architecture
//

import Foundation
import SwiftUI
import AppKit
import EventKit

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Window Settings

    @Published var windowWidthPercent: CGFloat {
        didSet {
            UserDefaults.standard.set(windowWidthPercent, forKey: "windowWidthPercent")
        }
    }

    @Published var windowHeightPercent: CGFloat {
        didSet {
            UserDefaults.standard.set(windowHeightPercent, forKey: "windowHeightPercent")
        }
    }

    var windowWidth: CGFloat {
        guard let screen = NSScreen.main else { return 320 }
        return screen.frame.width * (windowWidthPercent / 100.0)
    }

    var windowHeight: CGFloat {
        guard let screen = NSScreen.main else { return 400 }
        return screen.frame.height * (windowHeightPercent / 100.0)
    }

    // MARK: - Appearance

    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }

    @Published var globalFontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(globalFontSize, forKey: "globalFontSize")
        }
    }

    func increaseFontSize() {
        globalFontSize = min(globalFontSize + 1, 24)
    }

    func decreaseFontSize() {
        globalFontSize = max(globalFontSize - 1, 10)
    }

    // MARK: - Background Services

    @Published var screenshotsDirectory: String {
        didSet {
            UserDefaults.standard.set(screenshotsDirectory, forKey: "screenshotsDirectory")
        }
    }

    @Published var activityLoggingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(activityLoggingEnabled, forKey: "activityLoggingEnabled")
            if activityLoggingEnabled {
                ActivityStore.shared.startMonitoring()
            } else {
                ActivityStore.shared.stopMonitoring()
            }
        }
    }

    @Published var activityLogRetentionDays: Int {
        didSet {
            UserDefaults.standard.set(activityLogRetentionDays, forKey: "activityLogRetentionDays")
        }
    }

    // MARK: - Drift Monitor Settings

    @Published var driftMonitorEnabled: Bool {
        didSet {
            UserDefaults.standard.set(driftMonitorEnabled, forKey: "driftMonitorEnabled")
            if driftMonitorEnabled {
                DriftMonitor.shared.startMonitoring()
            } else {
                DriftMonitor.shared.stopMonitoring()
            }
        }
    }

    @Published var driftThresholdSeconds: Int {
        didSet {
            UserDefaults.standard.set(driftThresholdSeconds, forKey: "driftThresholdSeconds")
        }
    }

    // MARK: - UI State

    @Published var showSettings: Bool = false

    // MARK: - Init

    private init() {
        // Window
        self.windowWidthPercent = UserDefaults.standard.object(forKey: "windowWidthPercent") as? CGFloat ?? 20.0
        self.windowHeightPercent = UserDefaults.standard.object(forKey: "windowHeightPercent") as? CGFloat ?? 50.0

        // Appearance
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
        self.globalFontSize = UserDefaults.standard.object(forKey: "globalFontSize") as? CGFloat ?? 13.0

        // Screenshots
        let defaultDir = NSHomeDirectory() + "/Pictures/Screenshots"
        self.screenshotsDirectory = UserDefaults.standard.string(forKey: "screenshotsDirectory") ?? defaultDir

        // Activity
        self.activityLoggingEnabled = UserDefaults.standard.object(forKey: "activityLoggingEnabled") as? Bool ?? true
        self.activityLogRetentionDays = UserDefaults.standard.object(forKey: "activityLogRetentionDays") as? Int ?? 30

        // Drift Monitor
        self.driftMonitorEnabled = UserDefaults.standard.object(forKey: "driftMonitorEnabled") as? Bool ?? true
        self.driftThresholdSeconds = UserDefaults.standard.object(forKey: "driftThresholdSeconds") as? Int ?? 30
    }

    func resetToDefaults() {
        windowWidthPercent = 20.0
        windowHeightPercent = 50.0
        isDarkMode = true
        globalFontSize = 13.0
        driftMonitorEnabled = true
        driftThresholdSeconds = 30
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var driftMonitor = DriftMonitor.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Focus Settings
                    focusSection

                    Divider()

                    // Activity Settings
                    activitySection

                    Divider()

                    // Appearance
                    appearanceSection

                    Divider()

                    // About
                    aboutSection
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 500)
    }

    // MARK: - Sections

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FOCUS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            Toggle("Drift Monitor", isOn: $settings.driftMonitorEnabled)
                .toggleStyle(.switch)

            Text("Gently reminds you to get back on task when you drift to distraction apps")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if settings.driftMonitorEnabled {
                HStack {
                    Text("Threshold:")
                    Picker("", selection: $settings.driftThresholdSeconds) {
                        Text("15 sec").tag(15)
                        Text("30 sec").tag(30)
                        Text("60 sec").tag(60)
                        Text("120 sec").tag(120)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
                .font(.system(size: 12))
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BACKGROUND SERVICES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            Toggle("Activity Monitoring", isOn: $settings.activityLoggingEnabled)
                .toggleStyle(.switch)

            Text("Tracks app usage for context and drift detection")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Screenshots directory
            VStack(alignment: .leading, spacing: 4) {
                Text("Screenshots folder:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack {
                    Text(settings.screenshotsDirectory)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)

                    Button("Change") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            settings.screenshotsDirectory = url.path
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                }
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPEARANCE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            Toggle("Dark Mode", isOn: $settings.isDarkMode)
                .toggleStyle(.switch)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ABOUT")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            Text("Sol Unified v2.0")
                .font(.system(size: 13, weight: .medium))

            Text("\"The Prosthetic for Executive Function\"")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .italic()

            VStack(alignment: .leading, spacing: 4) {
                hotkeyInfo(key: "Opt + P", desc: "Set Objective")
                hotkeyInfo(key: "Opt + C", desc: "Capture Context")
            }
            .padding(.top, 8)

            Button("Reset to Defaults") {
                settings.resetToDefaults()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(.blue)
            .padding(.top, 8)
        }
    }

    private func hotkeyInfo(key: String, desc: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(3)

            Text(desc)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
