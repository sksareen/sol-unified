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
    
    @Published var windowWidth: CGFloat {
        didSet { UserDefaults.standard.set(windowWidth, forKey: "windowWidth") }
    }
    
    @Published var windowHeight: CGFloat {
        didSet { UserDefaults.standard.set(windowHeight, forKey: "windowHeight") }
    }
    
    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }
    
    @Published var screenshotsDirectory: String {
        didSet { UserDefaults.standard.set(screenshotsDirectory, forKey: "screenshotsDirectory") }
    }
    
    @Published var showSettings: Bool = false
    
    private init() {
        self.windowWidth = UserDefaults.standard.object(forKey: "windowWidth") as? CGFloat ?? 800
        self.windowHeight = UserDefaults.standard.object(forKey: "windowHeight") as? CGFloat ?? 600
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? false
        
        // Default screenshots directory - expand tilde
        let defaultDir = (NSHomeDirectory() + "/Pictures/Pics/Screenshots")
        self.screenshotsDirectory = UserDefaults.standard.string(forKey: "screenshotsDirectory") ?? defaultDir
    }
    
    func resetToDefaults() {
        windowWidth = 800
        windowHeight = 600
        isDarkMode = false
        screenshotsDirectory = NSHomeDirectory() + "/Pictures/Pics/Screenshots"
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SETTINGS")
                    .font(.system(size: Typography.headingSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                Button("Reset") {
                    settings.resetToDefaults()
                }
                .buttonStyle(BrutalistSecondaryButtonStyle())
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(BrutalistPrimaryButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Window Size Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("WINDOW SIZE")
                            .font(.system(size: Typography.bodySize, weight: .semibold))
                            .foregroundColor(Color.brutalistTextPrimary)
                        
                        // Width Slider
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Width:")
                                    .font(.system(size: Typography.bodySize))
                                    .foregroundColor(Color.brutalistTextSecondary)
                                
                                Spacer()
                                
                                Text("\(Int(settings.windowWidth))px")
                                    .font(.system(size: Typography.bodySize, weight: .medium))
                                    .foregroundColor(Color.brutalistTextPrimary)
                            }
                            
                            Slider(value: $settings.windowWidth, in: 600...1400, step: 50)
                                .accentColor(Color.brutalistAccent)
                        }
                        .padding(Spacing.md)
                        .background(Color.brutalistBgSecondary)
                        .cornerRadius(BorderRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.sm)
                                .stroke(Color.brutalistBorder, lineWidth: 1)
                        )
                        
                        // Height Slider
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Height:")
                                    .font(.system(size: Typography.bodySize))
                                    .foregroundColor(Color.brutalistTextSecondary)
                                
                                Spacer()
                                
                                Text("\(Int(settings.windowHeight))px")
                                    .font(.system(size: Typography.bodySize, weight: .medium))
                                    .foregroundColor(Color.brutalistTextPrimary)
                            }
                            
                            Slider(value: $settings.windowHeight, in: 400...1000, step: 50)
                                .accentColor(Color.brutalistAccent)
                        }
                        .padding(Spacing.md)
                        .background(Color.brutalistBgSecondary)
                        .cornerRadius(BorderRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.sm)
                                .stroke(Color.brutalistBorder, lineWidth: 1)
                        )
                        
                        Text("Window will resize on next show")
                            .font(.system(size: Typography.smallSize))
                            .foregroundColor(Color.brutalistTextMuted)
                            .padding(.top, Spacing.xs)
                    }
                    .padding(Spacing.lg)
                    .brutalistCard()
                    
                    // Appearance Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("APPEARANCE")
                            .font(.system(size: Typography.bodySize, weight: .semibold))
                            .foregroundColor(Color.brutalistTextPrimary)
                        
                        Toggle(isOn: $settings.isDarkMode) {
                            HStack {
                                Text("Dark Mode")
                                    .font(.system(size: Typography.bodySize))
                                    .foregroundColor(Color.brutalistTextSecondary)
                                
                                Spacer()
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color.brutalistAccent))
                        .padding(Spacing.md)
                        .background(Color.brutalistBgSecondary)
                        .cornerRadius(BorderRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.sm)
                                .stroke(Color.brutalistBorder, lineWidth: 1)
                        )
                        
                        Text("Changes apply immediately")
                            .font(.system(size: Typography.smallSize))
                            .foregroundColor(Color.brutalistTextMuted)
                            .padding(.top, Spacing.xs)
                    }
                    .padding(Spacing.lg)
                    .brutalistCard()
                    
                    // Screenshots Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("SCREENSHOTS")
                            .font(.system(size: Typography.bodySize, weight: .semibold))
                            .foregroundColor(Color.brutalistTextPrimary)
                        
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Screenshot Folder:")
                                    .font(.system(size: Typography.bodySize))
                                    .foregroundColor(Color.brutalistTextSecondary)
                                
                                Spacer()
                            }
                            
                            HStack(spacing: Spacing.sm) {
                                Text(settings.screenshotsDirectory)
                                    .font(.system(size: Typography.smallSize, design: .monospaced))
                                    .foregroundColor(Color.brutalistTextPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Spacing.sm)
                                    .background(Color.brutalistBgTertiary)
                                    .cornerRadius(BorderRadius.sm)
                                
                                Button("Select...") {
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
                                .buttonStyle(BrutalistSecondaryButtonStyle())
                            }
                            
                            Text("Select the folder containing your screenshots")
                                .font(.system(size: Typography.smallSize))
                                .foregroundColor(Color.brutalistTextMuted)
                                .padding(.top, Spacing.xs)
                        }
                        .padding(Spacing.md)
                        .background(Color.brutalistBgSecondary)
                        .cornerRadius(BorderRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.sm)
                                .stroke(Color.brutalistBorder, lineWidth: 1)
                        )
                    }
                    .padding(Spacing.lg)
                    .brutalistCard()
                }
                .padding(Spacing.lg)
            }
        }
        .frame(width: 500, height: 600)
        .background(Color.brutalistBgPrimary)
    }
}

