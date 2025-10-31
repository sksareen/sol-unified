//
//  TimerView.swift
//  SolUnified
//
//  Timer countdown display
//

import SwiftUI

struct TimerView: View {
    @ObservedObject var timerStore = TimerStore.shared
    @State private var presets: [TimeInterval] = [300, 600, 900, 1200, 1800] // 5, 10, 15, 20, 30 mins
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.lg) {
                Text("TIMER")
                    .font(.system(size: Typography.headingSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                // Time Display
                Text(timerStore.formatTime(timerStore.timeRemaining))
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.brutalistTextPrimary)
                    .padding(.vertical, Spacing.xl)
                
                // Preset Buttons
                HStack(spacing: Spacing.md) {
                    ForEach(presets, id: \.self) { duration in
                        PresetButton(
                            duration: duration,
                            isSelected: timerStore.selectedDuration == duration,
                            isDisabled: timerStore.isRunning
                        ) {
                            timerStore.setDuration(duration)
                        }
                    }
                }
                .padding(.bottom, Spacing.lg)
                
                // Control Buttons
                HStack(spacing: Spacing.md) {
                    if timerStore.isRunning {
                        Button(action: {
                            timerStore.stopTimer()
                        }) {
                            Text("STOP")
                                .font(.system(size: Typography.bodySize, weight: .semibold))
                        }
                        .buttonStyle(BrutalistPrimaryButtonStyle())
                    } else {
                        Button(action: {
                            timerStore.startTimer()
                        }) {
                            Text("START")
                                .font(.system(size: Typography.bodySize, weight: .semibold))
                        }
                        .buttonStyle(BrutalistPrimaryButtonStyle())
                        .disabled(timerStore.timeRemaining <= 0)
                    }
                    
                    Button(action: {
                        timerStore.resetTimer()
                    }) {
                        Text("RESET")
                            .font(.system(size: Typography.bodySize, weight: .medium))
                    }
                    .buttonStyle(BrutalistSecondaryButtonStyle())
                    .disabled(timerStore.isRunning)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.brutalistBgPrimary)
    }
}

struct PresetButton: View {
    let duration: TimeInterval
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    private var label: String {
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: Typography.bodySize, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color.brutalistTextPrimary : Color.brutalistTextSecondary)
                .frame(width: 60, height: 40)
                .background(isSelected ? Color.brutalistBgTertiary : Color.brutalistBgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: BorderRadius.sm)
                        .stroke(isSelected ? Color.brutalistAccent : Color.brutalistBorder, lineWidth: isSelected ? 2 : 1)
                )
                .cornerRadius(BorderRadius.sm)
                .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

