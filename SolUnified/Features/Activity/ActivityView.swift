//
//  ActivityView.swift
//  SolUnified
//
//  Simplified: Live log + app usage chart
//

import SwiftUI
import AppKit

struct ActivityView: View {
    @ObservedObject var store = ActivityStore.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var showingClearConfirm = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text("ACTIVITY")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if store.isMonitoringActive {
                    HStack(spacing: 12) {
                        Text("\(store.eventsTodayCount) EVENTS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Button(action: { showingClearConfirm = true }) {
                            Text("CLEAR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(16)
            .background(
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Content
            if !settings.activityLoggingEnabled {
                VStack(spacing: 16) {
                    Text("Activity Logging Disabled")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Button(action: { settings.showSettings = true }) {
                        Text("OPEN SETTINGS")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(BrutalistPrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // App Usage Chart (past few hours)
                    if let stats = store.stats, !stats.topApps.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("APP USAGE (PAST FEW HOURS)")
                                .font(.system(size: 10, weight: .black))
                                .tracking(0.5)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                            
                            AppUsageChart(apps: Array(stats.topApps.prefix(8)))
                                .frame(height: 200)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }
                        .background(Color.brutalistBgSecondary)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color.brutalistBorder),
                            alignment: .bottom
                        )
                    }
                    
                    // Live Event Log
                    LiveActivityStreamView()
                        .frame(maxHeight: .infinity)
                }
            }
            
            // Error indicator
            if let error = store.monitoringError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 11))
                    Spacer()
                    Button("Dismiss") {
                        store.monitoringError = nil
                    }
                    .buttonStyle(BrutalistSecondaryButtonStyle())
                }
                .padding(12)
                .background(Color.brutalistBgTertiary)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.brutalistBorder),
                    alignment: .top
                )
            }
        }
        .alert("Clear All Activity Logs?", isPresented: $showingClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                _ = store.clearHistory()
            }
        } message: {
            Text("This will permanently delete all activity logs.")
        }
        .onAppear {
            if settings.activityLoggingEnabled && !store.isMonitoringActive {
                store.startMonitoring()
            }
            store.calculateStatsAsync()
        }
    }
    
    private var statusColor: Color {
        if !store.isMonitoringActive {
            return .gray
        } else if store.monitoringError != nil {
            return .red
        } else if let lastEvent = store.lastEventTime,
                  Date().timeIntervalSince(lastEvent) > 300 {
            return .yellow
        } else {
            return .green
        }
    }
}

// Simple horizontal bar chart for app usage
struct AppUsageChart: View {
    let apps: [ActivityStats.AppTime]
    
    private var maxTime: TimeInterval {
        apps.map { $0.totalTime }.max() ?? 1
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(apps, id: \.appBundleId) { app in
                HStack(spacing: 12) {
                    // App name
                    Text(app.appName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 120, alignment: .leading)
                        .lineLimit(1)
                    
                    // Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.brutalistBgTertiary)
                                .frame(height: 20)
                                .cornerRadius(3)
                            
                            let percentage = (app.totalTime / maxTime) * 100
                            Rectangle()
                                .fill(appColor(app.appName))
                                .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 20)
                                .cornerRadius(3)
                            
                            // Percentage label
                            if percentage > 10 {
                                Text("\(Int(percentage))%")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.leading, 6)
                            }
                        }
                    }
                    .frame(height: 20)
                    
                    // Duration
                    Text(formatDuration(app.totalTime))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
    }
    
    private func appColor(_ appName: String) -> Color {
        let colors: [Color] = [
            Color(hex: "3B82F6"), // Blue
            Color(hex: "10B981"), // Green
            Color(hex: "F59E0B"), // Orange
            Color(hex: "8B5CF6"), // Purple
            Color(hex: "EF4444"), // Red
            Color(hex: "EC4899"), // Pink
            Color(hex: "06B6D4"), // Cyan
            Color(hex: "84CC16")  // Lime
        ]
        
        let hash = abs(appName.hashValue)
        return colors[hash % colors.count]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    ActivityView()
}
