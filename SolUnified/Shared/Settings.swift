//
//  Settings.swift
//  SolUnified
//
//  App settings and preferences
//

import Foundation
import SwiftUI
import AppKit

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var windowWidthPercent: CGFloat {
        didSet {
            UserDefaults.standard.set(windowWidthPercent, forKey: "windowWidthPercent")
            InternalAppTracker.shared.trackSettingChange(key: "windowWidthPercent", value: "\(Int(windowWidthPercent))")
        }
    }
    
    @Published var windowHeightPercent: CGFloat {
        didSet {
            UserDefaults.standard.set(windowHeightPercent, forKey: "windowHeightPercent")
            InternalAppTracker.shared.trackSettingChange(key: "windowHeightPercent", value: "\(Int(windowHeightPercent))")
        }
    }
    
    @Published var globalFontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(globalFontSize, forKey: "globalFontSize")
            InternalAppTracker.shared.trackSettingChange(key: "globalFontSize", value: "\(Int(globalFontSize))")
            // Post notification for views to update
            NotificationCenter.default.post(name: NSNotification.Name("GlobalFontSizeChanged"), object: nil)
        }
    }
    
    func increaseFontSize() {
        globalFontSize = min(globalFontSize + 1, 24)
    }
    
    func decreaseFontSize() {
        globalFontSize = max(globalFontSize - 1, 10)
    }
    
    func increaseWindowSize() {
        windowWidthPercent = min(windowWidthPercent + 5, 100)
        windowHeightPercent = min(windowHeightPercent + 5, 96)
    }
    
    func decreaseWindowSize() {
        windowWidthPercent = max(windowWidthPercent - 5, 35)
        windowHeightPercent = max(windowHeightPercent - 5, 50)
    }
    
    // Computed properties for actual pixel values
    var windowWidth: CGFloat {
        guard let screen = NSScreen.main else { return 800 }
        return screen.frame.width * (windowWidthPercent / 100.0)
    }
    
    var windowHeight: CGFloat {
        guard let screen = NSScreen.main else { return 600 }
        return screen.frame.height * (windowHeightPercent / 100.0)
    }
    
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            InternalAppTracker.shared.trackSettingChange(key: "isDarkMode", value: isDarkMode ? "true" : "false")
        }
    }
    
    @Published var screenshotsDirectory: String {
        didSet {
            UserDefaults.standard.set(screenshotsDirectory, forKey: "screenshotsDirectory")
            InternalAppTracker.shared.trackSettingChange(key: "screenshotsDirectory", value: screenshotsDirectory)
        }
    }
    
    @Published var vaultRootDirectory: String {
        didSet {
            UserDefaults.standard.set(vaultRootDirectory, forKey: "vaultRootDirectory")
            InternalAppTracker.shared.trackSettingChange(key: "vaultRootDirectory", value: vaultRootDirectory)
        }
    }
    
    @Published var activityLoggingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(activityLoggingEnabled, forKey: "activityLoggingEnabled")
            if activityLoggingEnabled {
                ActivityStore.shared.startMonitoring()
            } else {
                ActivityStore.shared.stopMonitoring()
                // Also disable input monitoring when activity logging is disabled
                InputMonitor.shared.stopMonitoring()
                InputMonitor.shared.stopMouseTracking()
            }
        }
    }
    
    @Published var activityLogRetentionDays: Int {
        didSet {
            UserDefaults.standard.set(activityLogRetentionDays, forKey: "activityLogRetentionDays")
            InternalAppTracker.shared.trackSettingChange(key: "activityLogRetentionDays", value: "\(activityLogRetentionDays)")
        }
    }
    
    @Published var keyboardTrackingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(keyboardTrackingEnabled, forKey: "keyboardTrackingEnabled")
            InternalAppTracker.shared.trackSettingChange(key: "keyboardTrackingEnabled", value: keyboardTrackingEnabled ? "true" : "false")
            if !keyboardTrackingEnabled {
                InputMonitor.shared.stopMonitoring()
            } else if activityLoggingEnabled {
                InputMonitor.shared.startMonitoring()
            }
        }
    }
    
    @Published var mouseTrackingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(mouseTrackingEnabled, forKey: "mouseTrackingEnabled")
            InternalAppTracker.shared.trackSettingChange(key: "mouseTrackingEnabled", value: mouseTrackingEnabled ? "true" : "false")
            if !mouseTrackingEnabled {
                InputMonitor.shared.stopMouseTracking()
            } else if activityLoggingEnabled {
                InputMonitor.shared.startMouseTracking()
            }
        }
    }
    
    // Daily Notes settings
    @Published var dailyNoteDateFormat: String {
        didSet {
            UserDefaults.standard.set(dailyNoteDateFormat, forKey: "dailyNoteDateFormat")
            InternalAppTracker.shared.trackSettingChange(key: "dailyNoteDateFormat", value: dailyNoteDateFormat)
        }
    }
    
    @Published var dailyNoteFolder: String {
        didSet {
            UserDefaults.standard.set(dailyNoteFolder, forKey: "dailyNoteFolder")
            InternalAppTracker.shared.trackSettingChange(key: "dailyNoteFolder", value: dailyNoteFolder)
        }
    }
    
    @Published var dailyNoteTemplate: String {
        didSet {
            UserDefaults.standard.set(dailyNoteTemplate, forKey: "dailyNoteTemplate")
        }
    }
    
    @Published var openDailyNoteOnStartup: Bool {
        didSet {
            UserDefaults.standard.set(openDailyNoteOnStartup, forKey: "openDailyNoteOnStartup")
        }
    }

    // Agent settings
    @Published var claudeAPIKey: String {
        didSet {
            // Store in UserDefaults for simplicity (in production, use Keychain)
            UserDefaults.standard.set(claudeAPIKey, forKey: "claudeAPIKey")
        }
    }

    @Published var agentEnabled: Bool {
        didSet {
            UserDefaults.standard.set(agentEnabled, forKey: "agentEnabled")
        }
    }

    @Published var showSettings: Bool = false
    
    private init() {
        self.windowWidthPercent = UserDefaults.standard.object(forKey: "windowWidthPercent") as? CGFloat ?? 40.0
        self.windowHeightPercent = UserDefaults.standard.object(forKey: "windowHeightPercent") as? CGFloat ?? 85.0
        self.globalFontSize = UserDefaults.standard.object(forKey: "globalFontSize") as? CGFloat ?? 13.0
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? false
        
        // Default screenshots directory - expand tilde
        let defaultDir = (NSHomeDirectory() + "/Pictures/Pics/Screenshots")
        self.screenshotsDirectory = UserDefaults.standard.string(forKey: "screenshotsDirectory") ?? defaultDir
        
        // Default vault directory - home directory by default
        self.vaultRootDirectory = UserDefaults.standard.string(forKey: "vaultRootDirectory") ?? NSHomeDirectory()
        
        self.activityLoggingEnabled = UserDefaults.standard.bool(forKey: "activityLoggingEnabled")
        self.activityLogRetentionDays = UserDefaults.standard.object(forKey: "activityLogRetentionDays") as? Int ?? 30
        self.keyboardTrackingEnabled = UserDefaults.standard.bool(forKey: "keyboardTrackingEnabled")
        self.mouseTrackingEnabled = UserDefaults.standard.bool(forKey: "mouseTrackingEnabled")
        
        // Daily notes settings
        self.dailyNoteDateFormat = UserDefaults.standard.string(forKey: "dailyNoteDateFormat") ?? "MM-dd-yyyy"
        self.dailyNoteFolder = UserDefaults.standard.string(forKey: "dailyNoteFolder") ?? "Journal/daily_notes"
        self.dailyNoteTemplate = UserDefaults.standard.string(forKey: "dailyNoteTemplate") ?? """
##### *[my list](my-list)*
---
#### mantras


#### journal


#### lessons learned

"""
        self.openDailyNoteOnStartup = UserDefaults.standard.object(forKey: "openDailyNoteOnStartup") as? Bool ?? true

        // Agent settings
        self.claudeAPIKey = UserDefaults.standard.string(forKey: "claudeAPIKey") ?? ""
        self.agentEnabled = UserDefaults.standard.object(forKey: "agentEnabled") as? Bool ?? true
    }
    
    func resetToDefaults() {
        windowWidthPercent = 40.0
        windowHeightPercent = 85.0
        globalFontSize = 13.0
        isDarkMode = false
        screenshotsDirectory = NSHomeDirectory() + "/Pictures/Pics/Screenshots"
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case agent = "Agent"
        case activity = "Activity"
        case screenshots = "Screenshots"
        case vault = "Vault"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .agent: return "brain"
            case .activity: return "chart.line.uptrend.xyaxis"
            case .screenshots: return "camera.viewfinder"
            case .vault: return "folder"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                // Sidebar content
                VStack(spacing: 8) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16))
                                    .frame(width: 20)
                                Text(tab.rawValue)
                                    .font(.system(size: 13))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(10)
                
                Spacer()
            }
            .frame(width: 160)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content area
            VStack(spacing: 0) {
                // Toolbar with close button
                HStack {
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close (Esc)")
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(12)
                
                // Content
                ScrollView {
                    contentView
                        .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 650, height: 500)
    }
    
    @ViewBuilder
    var contentView: some View {
        switch selectedTab {
        case .general:
            generalView
        case .agent:
            agentView
        case .activity:
            activityView
        case .screenshots:
            screenshotsView
        case .vault:
            vaultView
        }
    }
    
    var generalView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.system(size: 20, weight: .bold))
            
            Form {
                // Appearance
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Toggle("Use dark mode", isOn: $settings.isDarkMode)
                        .toggleStyle(SwitchToggleStyle())
                    
                    Text("Changes apply immediately")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Font Size
                VStack(alignment: .leading, spacing: 12) {
                    Text("Font Size")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack {
                        Text("Size:")
                            .frame(width: 60, alignment: .leading)
                        Slider(value: $settings.globalFontSize, in: 10...24, step: 1)
                            .accentColor(Color.brutalistAccent)
                        Text("\(Int(settings.globalFontSize))pt")
                            .frame(width: 40, alignment: .trailing)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "command")
                            .font(.system(size: 10))
                        Text("+/- to adjust")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Window Size
                VStack(alignment: .leading, spacing: 12) {
                    Text("Window Size")
                        .font(.system(size: 13, weight: .semibold))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Width:")
                                .frame(width: 60, alignment: .leading)
                            LogSlider(
                                value: $settings.windowWidthPercent,
                                range: 35...100
                            )
                            Text("\(Int(settings.windowWidthPercent))%")
                                .frame(width: 40, alignment: .trailing)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Height:")
                                .frame(width: 60, alignment: .leading)
                            LogSlider(
                                value: $settings.windowHeightPercent,
                                range: 50...96
                            )
                            Text("\(Int(settings.windowHeightPercent))%")
                                .frame(width: 40, alignment: .trailing)
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    
                    Text("Window will resize on next show")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Reset button
                HStack {
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .formStyle(.grouped)
            
            Spacer()
        }
    }

    var agentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Agent")
                .font(.system(size: 20, weight: .bold))

            Form {
                // API Key Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude API Key")
                        .font(.system(size: 13, weight: .semibold))

                    SecureField("sk-ant-api03-...", text: $settings.claudeAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12, design: .monospaced))

                    Text("Get your API key from console.anthropic.com")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if !settings.claudeAPIKey.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("API key configured")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.vertical, 8)

                Divider()

                // Agent Settings
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable AI Agent", isOn: $settings.agentEnabled)
                        .toggleStyle(SwitchToggleStyle())

                    Text("When enabled, the Agent tab will be accessible")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)

                Divider()

                // Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("About the Agent")
                        .font(.system(size: 13, weight: .semibold))

                    VStack(alignment: .leading, spacing: 8) {
                        featureRow(icon: "person.2", text: "Manages your contacts with preferences")
                        featureRow(icon: "brain", text: "Remembers facts and learns from interactions")
                        featureRow(icon: "calendar", text: "Can schedule meetings and check availability")
                        featureRow(icon: "magnifyingglass", text: "Searches your work context intelligently")
                    }
                }
                .padding(.vertical, 8)

                Divider()

                // Privacy note
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("Conversations and context are sent to Claude API for processing. Your data is not stored by Anthropic beyond the API call.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .formStyle(.grouped)

            Spacer()
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color.brutalistAccent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color.brutalistTextSecondary)
        }
    }

    var activityView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Activity")
                .font(.system(size: 20, weight: .bold))
            
            Form {
                // Activity Logging Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable activity logging", isOn: $settings.activityLoggingEnabled)
                        .toggleStyle(SwitchToggleStyle())
                    
                    Text("Track app usage, window titles, and system events")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                if settings.activityLoggingEnabled {
                    Divider()
                    
                    // Data Retention
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Data Retention")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Picker("Keep logs for:", selection: $settings.activityLogRetentionDays) {
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("1 year").tag(365)
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Privacy note
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("All data is stored locally on your device and is never sent to the cloud.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Test button
                    HStack {
                        Button("Test Event") {
                            ActivityStore.shared.testEvent()
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .formStyle(.grouped)
            
            Spacer()
        }
    }
    
    var vaultView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Vault")
                .font(.system(size: 20, weight: .bold))
            
            Form {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vault Root Folder")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 8) {
                        Text(settings.vaultRootDirectory)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                        
                        Button("Choose...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.canCreateDirectories = true
                            
                            if panel.runModal() == .OK {
                                if let url = panel.url {
                                    settings.vaultRootDirectory = url.path
                                }
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    Text("Select the root folder for your vault notes")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Daily Notes Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Daily Notes")
                        .font(.system(size: 13, weight: .semibold))
                    
                    // Date Format
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date Format")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        TextField("MM-dd-yyyy", text: $settings.dailyNoteDateFormat)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11, design: .monospaced))
                        
                        Text("Preview: \(DailyNoteManager.shared.formatDate(Date(), format: settings.dailyNoteDateFormat))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    // Daily Notes Folder
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Notes Folder")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        TextField("Journal/daily_notes", text: $settings.dailyNoteFolder)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11, design: .monospaced))
                        
                        Text("Relative to vault root")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    // Template
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Template")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $settings.dailyNoteTemplate)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Open on Startup
                    Toggle("Open today's note on startup", isOn: $settings.openDailyNoteOnStartup)
                        .toggleStyle(SwitchToggleStyle())
                    
                    // Quick access hint
                    HStack(spacing: 4) {
                        Image(systemName: "command")
                            .font(.system(size: 10))
                        Text("T")
                            .font(.system(size: 10, weight: .semibold))
                        Text("to open today's note")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
            .formStyle(.grouped)
            
            Spacer()
        }
    }

    var screenshotsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Screenshots")
                .font(.system(size: 20, weight: .bold))
            
            Form {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screenshot Folder")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack(spacing: 8) {
                        Text(settings.screenshotsDirectory)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                        
                        Button("Choose...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.canCreateDirectories = true
                            
                            if panel.runModal() == .OK {
                                if let url = panel.url {
                                    settings.screenshotsDirectory = url.path
                                }
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    Text("Select the folder where your screenshots are stored")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            .formStyle(.grouped)
            
            Spacer()
        }
    }
}

// MARK: - Logarithmic Slider
struct LogSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    
    private var logValue: CGFloat {
        let minLog = log(range.lowerBound)
        let maxLog = log(range.upperBound)
        return (log(value) - minLog) / (maxLog - minLog)
    }
    
    var body: some View {
        Slider(
            value: Binding(
                get: { logValue },
                set: { newLogValue in
                    let minLog = log(range.lowerBound)
                    let maxLog = log(range.upperBound)
                    let actualValue = exp(minLog + newLogValue * (maxLog - minLog))
                    value = actualValue
                }
            ),
            in: 0...1
        )
        .accentColor(Color.brutalistAccent)
    }
}

