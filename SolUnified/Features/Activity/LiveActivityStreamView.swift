//
//  LiveActivityStreamView.swift
//  SolUnified
//
//  Live activity stream showing current activity with progress bar and meaningful sessions
//

import SwiftUI

struct LiveActivityStreamView: View {
    @ObservedObject var store = ActivityStore.shared
    @State private var animationProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LIVE ACTIVITY")
                    .font(.system(size: Typography.smallSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextSecondary)
                
                Spacer()
                
                if store.currentSession != nil {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    
                    Text("LIVE")
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    
                    // BRAIN PULSE (Real-time Neural State)
                    if let state = ValueComputer.shared.lastState {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("BRAIN PULSE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.brutalistTextMuted)
                                Spacer()
                                Text(state.context.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.brutalistBgSecondary)
                                    .cornerRadius(4)
                            }
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("FOCUS")
                                        .font(.system(size: 9))
                                        .foregroundColor(.brutalistTextSecondary)
                                    GeometryReader { g in
                                        ZStack(alignment: .leading) {
                                            Rectangle().fill(Color.brutalistBgSecondary)
                                            Rectangle()
                                                .fill(Color.green)
                                                .frame(width: g.size.width * state.focus)
                                        }
                                    }
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("VELOCITY")
                                        .font(.system(size: 9))
                                        .foregroundColor(.brutalistTextSecondary)
                                    GeometryReader { g in
                                        ZStack(alignment: .leading) {
                                            Rectangle().fill(Color.brutalistBgSecondary)
                                            Rectangle()
                                                .fill(Color.blue)
                                                .frame(width: g.size.width * state.velocity)
                                        }
                                    }
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.brutalistBgTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.brutalistBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                    }
                    
                    // Current Activity (with animated progress bar)
                    if let current = store.currentSession {
                        CurrentActivityCard(session: current)
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.sm)
                    }
                    
                    // Meaningful Sessions History (>= 1 minute, limited to 5 most recent)
                    if !store.meaningfulSessions.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("RECENT ACTIVITIES")
                                .font(.system(size: Typography.smallSize, weight: .semibold))
                                .foregroundColor(Color.brutalistTextMuted)
                                .padding(.horizontal, Spacing.md)
                            
                            ForEach(store.meaningfulSessions.prefix(5)) { session in
                                MeaningfulSessionRow(session: session)
                                    .padding(.horizontal, Spacing.md)
                            }
                        }
                        .padding(.top, Spacing.xs)
                    }
                    
                    // Recent App Switches (shorter sessions, limited to 10 most recent)
                    if !store.recentAppSwitches.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("RECENT SWITCHES")
                                .font(.system(size: Typography.smallSize, weight: .semibold))
                                .foregroundColor(Color.brutalistTextMuted)
                                .padding(.horizontal, Spacing.md)
                            
                            ForEach(store.recentAppSwitches.prefix(10)) { session in
                                MeaningfulSessionRow(session: session)
                                    .padding(.horizontal, Spacing.md)
                                    .opacity(0.7) // Slightly dimmed to show they're shorter sessions
                            }
                        }
                        .padding(.top, Spacing.xs)
                    }
                    
                    // Distracted Periods (limited to 3 most recent)
                    if !store.distractedPeriods.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("DISTRACTED PERIODS")
                                .font(.system(size: Typography.smallSize, weight: .semibold))
                                .foregroundColor(Color.brutalistTextMuted)
                                .padding(.horizontal, Spacing.md)
                            
                            ForEach(store.distractedPeriods.prefix(3)) { period in
                                DistractedPeriodRow(period: period)
                                    .padding(.horizontal, Spacing.md)
                            }
                        }
                        .padding(.top, Spacing.xs)
                    }
                    
                    if store.currentSession == nil && store.meaningfulSessions.isEmpty && store.recentAppSwitches.isEmpty {
                        Text("No activity data yet")
                            .font(.system(size: Typography.bodySize))
                            .foregroundColor(Color.brutalistTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.lg)
                    }
                }
                .padding(.bottom, Spacing.sm)
            }
            .background(Color.brutalistBgPrimary)
        }
        .background(Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.sm)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
    }
}

struct CurrentActivityCard: View {
    let session: LiveActivitySession
    @State private var progress: Double = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("CURRENTLY")
                    .font(.system(size: Typography.smallSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextMuted)
                
                Spacer()
                
                Text(formatDuration(session.duration))
                    .font(.system(size: Typography.smallSize, design: .monospaced))
                    .foregroundColor(Color.brutalistTextSecondary)
            }
            
            Text(session.appName)
                .font(.system(size: Typography.bodySize, weight: .semibold))
                .foregroundColor(Color.brutalistTextPrimary)
            
            if let windowTitle = session.windowTitle, !windowTitle.isEmpty {
                Text(windowTitle)
                    .font(.system(size: Typography.smallSize))
                    .foregroundColor(Color.brutalistTextSecondary)
                    .lineLimit(1)
            }
            
            // Animated progress bar (shows progress within current minute)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.brutalistBgSecondary)
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.brutalistAccent)
                        .frame(width: geometry.size.width * min(progress, 1.0), height: 4)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 4)
            .onAppear {
                updateProgress()
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    updateProgress()
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
        .padding(Spacing.sm)
        .background(Color.brutalistBgPrimary)
        .cornerRadius(BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.sm)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
    }
    
    private func updateProgress() {
        let totalSeconds = session.duration
        let secondsInMinute = totalSeconds.truncatingRemainder(dividingBy: 60.0)
        progress = secondsInMinute / 60.0 // Progress within current minute (0-1)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

struct MeaningfulSessionRow: View {
    let session: MeaningfulSession
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            // Duration badge
            Text(formatDuration(session.duration))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color.brutalistTextPrimary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2)
                .background(Color.brutalistAccent.opacity(0.2))
                .cornerRadius(4)
                .frame(width: 50, alignment: .leading)
            
            // App name
            Text(session.appName)
                .font(.system(size: Typography.smallSize))
                .foregroundColor(Color.brutalistTextPrimary)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)
            
            // Window title
            if let windowTitle = session.windowTitle, !windowTitle.isEmpty {
                Text(windowTitle)
                    .font(.system(size: Typography.smallSize))
                    .foregroundColor(Color.brutalistTextSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Time
            Text(formatTime(session.startTime))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color.brutalistTextMuted)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 2)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct DistractedPeriodRow: View {
    let period: DistractedPeriod
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 10))
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Distracted Period")
                    .font(.system(size: Typography.smallSize, weight: .medium))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Text("\(formatDuration(period.duration)) • \(period.switchCount) switches")
                    .font(.system(size: 9))
                    .foregroundColor(Color.brutalistTextMuted)
            }
            
            Spacer()
            
            Text(formatTime(period.startTime))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color.brutalistTextMuted)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 2)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

