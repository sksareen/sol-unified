//
//  AppDelegate.swift
//  SolUnified v2.0
//
//  "The Prosthetic for Executive Function"
//
//  App delegate for the invisible background service.
//  Sol v2 is menu-bar only with global hotkeys:
//  - Opt+P: Toggle HUD (set objective)
//  - Opt+C: Capture context to clipboard
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // Core managers
    var windowManager: WindowManager?
    var hotkeyManager = HotkeyManager.shared

    // v2 Features
    var objectiveStore = ObjectiveStore.shared
    var contextEngine = ContextEngine.shared
    var driftMonitor = DriftMonitor.shared

    // Background services
    var contextExporter = ContextExporter.shared
    var contextAPIServer = ContextAPIServer.shared

    // Menu bar
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (pure menu bar app)
        NSApp.setActivationPolicy(.accessory)

        // Create menu bar icon
        setupMenuBar()

        // Initialize database
        if !Database.shared.initialize() {
            print("Failed to initialize database")
        }

        // Ensure objectives table exists
        createObjectivesTable()

        // Create main settings panel (accessed via menu bar)
        let contentView = TabNavigator()
            .environmentObject(WindowManager.shared)
            .preferredColorScheme(AppSettings.shared.isDarkMode ? .dark : .light)

        // Setup window manager for settings panel
        windowManager = WindowManager.shared
        windowManager?.setup(with: contentView)

        // Register global hotkeys
        let registered = hotkeyManager.registerAll(
            onHUD: {
                HUDWindowController.shared.toggle()
            },
            onContext: {
                ContextEngine.shared.captureAndCopy()
            }
        )

        if !registered {
            print("Failed to register hotkeys")
        }

        // Start background services
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Clipboard monitoring (for context engine)
            ClipboardMonitor.shared.startMonitoring()

            // Screenshot monitoring (for context engine)
            let screenshotsDir = AppSettings.shared.screenshotsDirectory
            ScreenshotScanner.shared.startMonitoring(directory: screenshotsDir)

            // Activity monitoring (for drift detection and context)
            if AppSettings.shared.activityLoggingEnabled {
                ActivityStore.shared.startMonitoring()
            }

            // Start drift monitor
            self.driftMonitor.startMonitoring()

            // Context export for external AI agents
            self.contextExporter.startAutoExport(interval: 30.0)

            // HTTP API server for real-time context access
            self.contextAPIServer.start(port: 7654)

            // Cleanup old logs
            let retentionDays = AppSettings.shared.activityLogRetentionDays
            _ = Database.shared.cleanupOldActivityLogs(olderThan: retentionDays)
        }

        print("Sol Unified v2.0 started")
        print("Hotkeys:")
        print("  Opt+P: Set Objective (HUD)")
        print("  Opt+C: Capture Context")
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use a sun icon (Sol = Sun)
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Sol Unified")
            button.action = #selector(toggleSettingsPanel)
            button.target = self

            // Update appearance based on objective state
            updateMenuBarIcon()
        }

        // Create context menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Set Objective (⌥P)", action: #selector(showHUD), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Context (⌘⇧C)", action: #selector(captureContext), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Current objective (if any)
        if let objective = objectiveStore.currentObjective {
            let objectiveItem = NSMenuItem(title: "📍 \(objective.text)", action: nil, keyEquivalent: "")
            objectiveItem.isEnabled = false
            menu.addItem(objectiveItem)

            menu.addItem(NSMenuItem(title: "Complete Objective", action: #selector(completeObjective), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Clear Objective", action: #selector(clearObjective), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(toggleSettingsPanel), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Sol", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu

        // Observe objective changes to update menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(objectiveDidChange),
            name: NSNotification.Name("ObjectiveDidChange"),
            object: nil
        )
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        if let objective = objectiveStore.currentObjective {
            // Show active state
            button.image = NSImage(systemSymbolName: objective.isPaused ? "sun.max" : "sun.max.fill",
                                   accessibilityDescription: "Sol Unified")
            button.contentTintColor = objective.isPaused ? .orange : .systemGreen
        } else {
            // Idle state
            button.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "Sol Unified")
            button.contentTintColor = nil
        }
    }

    @objc private func objectiveDidChange() {
        setupMenuBar() // Rebuild menu
        updateMenuBarIcon()
    }

    // MARK: - Actions

    @objc func toggleSettingsPanel() {
        WindowManager.shared.toggleWindow()
    }

    @objc func showHUD() {
        HUDWindowController.shared.show()
    }

    @objc func captureContext() {
        ContextEngine.shared.captureAndCopy()
    }

    @objc func completeObjective() {
        objectiveStore.completeObjective()
    }

    @objc func clearObjective() {
        objectiveStore.abandonObjective()
    }

    // MARK: - Database Setup

    private func createObjectivesTable() {
        Database.shared.execute("""
            CREATE TABLE IF NOT EXISTS objectives (
                id TEXT PRIMARY KEY,
                text TEXT NOT NULL,
                start_time TEXT NOT NULL,
                end_time TEXT,
                end_reason TEXT,
                is_paused INTEGER DEFAULT 0,
                total_paused_time REAL DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // Index for querying active objectives
        Database.shared.execute("""
            CREATE INDEX IF NOT EXISTS idx_objectives_active ON objectives(end_time)
        """)
    }

    // MARK: - Lifecycle

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        ClipboardMonitor.shared.stopMonitoring()
        ScreenshotScanner.shared.stopMonitoring()
        ActivityStore.shared.stopMonitoring()
        driftMonitor.stopMonitoring()
        contextExporter.stopAutoExport()
        contextAPIServer.stop()
        hotkeyManager.unregisterAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowManager.shared.showWindow(animated: true)
        }
        return true
    }
}
