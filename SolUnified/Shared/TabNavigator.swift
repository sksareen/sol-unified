//
//  TabNavigator.swift
//  SolUnified v2.0
//
//  The "Glass" UI - essentially invisible. Sol v2 is a background service
//  that only surfaces when summoned (HUD) or when correction is needed (Drift).
//
//  This minimal view serves as a settings/status panel accessed via menu bar.
//

import SwiftUI

struct TabNavigator: View {
    @ObservedObject var objectiveStore = ObjectiveStore.shared
    @ObservedObject var driftMonitor = DriftMonitor.shared
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sol Unified")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Current Objective
                    objectiveSection

                    Divider()

                    // Quick Stats
                    statsSection

                    Divider()

                    // Hotkey Reference
                    hotkeySection

                    Divider()

                    // Settings
                    settingsSection
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                Text("v2.0 - The Prosthetic for Executive Function")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 320, height: 400)
        .background(Color.brutalistBgPrimary)
    }

    // MARK: - Status

    private var statusColor: Color {
        if let objective = objectiveStore.currentObjective {
            return objective.isPaused ? .orange : .green
        }
        return .gray
    }

    private var statusText: String {
        if let objective = objectiveStore.currentObjective {
            return objective.isPaused ? "Paused" : "Active"
        }
        return "Idle"
    }

    // MARK: - Sections

    private var objectiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT OBJECTIVE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            if let objective = objectiveStore.currentObjective {
                VStack(alignment: .leading, spacing: 4) {
                    Text(objective.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    HStack {
                        Text(objective.formattedDuration)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(objective.isPaused ? "Resume" : "Pause") {
                            if objective.isPaused {
                                objectiveStore.resumeObjective()
                            } else {
                                objectiveStore.pauseObjective()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.blue)

                        Button("Complete") {
                            objectiveStore.completeObjective()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    }
                }
                .padding(10)
                .background(Color.brutalistBgSecondary)
                .cornerRadius(6)
            } else {
                Text("No active objective")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .italic()

                Text("Press Opt+P to set one")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("\(objectiveStore.objectiveHistory.count)")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("Sessions")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading) {
                    Text(formatTotalTime())
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("Focus Time")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOTKEYS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                hotkeyRow(key: "Opt + P", action: "Set Objective (HUD)")
                hotkeyRow(key: "Opt + C", action: "Capture Context")
            }
        }
    }

    private func hotkeyRow(key: String, action: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 120, alignment: .leading)

            Text(action)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SETTINGS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            Toggle("Drift Monitor", isOn: $driftMonitor.isMonitoring)
                .toggleStyle(.switch)
                .font(.system(size: 12))

            Toggle("Launch at Login", isOn: .constant(false)) // TODO: Implement
                .toggleStyle(.switch)
                .font(.system(size: 12))
                .disabled(true)
        }
    }

    // MARK: - Helpers

    private func formatTotalTime() -> String {
        let totalSeconds = objectiveStore.objectiveHistory.reduce(0.0) { $0 + $1.duration }
            + (objectiveStore.activeWorkDuration)

        let hours = Int(totalSeconds / 3600)
        let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview

#Preview {
    TabNavigator()
}
