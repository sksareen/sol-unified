//
//  ActivityView.swift
//  SolUnified
//
//  Activity logging UI with category summaries and time period breakdowns
//

import SwiftUI
import AppKit

struct ActivityView: View {
    @ObservedObject var store = ActivityStore.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var showingClearConfirm = false
    @State private var selectedTimeRange: DateInterval?
    @State private var timelineRange: TimeRange = .today
    @State private var timelineBuckets: [TimelineBucket] = []
    @State private var selectedCategory: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.md) {
                HStack {
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text("ACTIVITY SUMMARY")
                            .font(.system(size: Typography.headingSize, weight: .semibold))
                            .foregroundColor(Color.brutalistTextPrimary)
                    }
                    
                    Spacer()
                    
                    if store.isMonitoringActive {
                        VStack(alignment: .trailing, spacing: Spacing.xs) {
                            Text("\(store.eventsTodayCount) events")
                                .font(.system(size: Typography.smallSize))
                                .foregroundColor(Color.brutalistTextSecondary)
                            
                            if let lastEvent = store.lastEventTime {
                                Text("Last: \(formatTimeAgo(lastEvent))")
                                    .font(.system(size: Typography.smallSize))
                                    .foregroundColor(Color.brutalistTextMuted)
                            }
                        }
                    }
                    
                    Button(action: {
                        showingClearConfirm = true
                    }) {
                        Text("CLEAR")
                            .font(.system(size: Typography.bodySize, weight: .medium))
                    }
                    .buttonStyle(BrutalistSecondaryButtonStyle())
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            // Only drag if not clicking on buttons (using simultaneousGesture so buttons still work)
                            if let window = NSApplication.shared.keyWindow {
                                let currentLocation = window.frame.origin
                                // Note: SwiftUI Y is flipped, so subtract for Y
                                let newLocation = NSPoint(
                                    x: currentLocation.x + value.translation.width,
                                    y: currentLocation.y - value.translation.height
                                )
                                window.setFrameOrigin(newLocation)
                            }
                        }
                )
                
                // Quick Stats
                if let stats = store.stats {
                    HStack(spacing: Spacing.md) {
                        ActivityStatCard(
                            title: "Active Time",
                            value: formatDuration(stats.totalActiveTime)
                        )
                        
                        ActivityStatCard(
                            title: "Top App",
                            value: stats.topApps.first?.appName ?? "—"
                        )
                        
                        ActivityStatCard(
                            title: "Sessions",
                            value: "\(stats.sessionsToday)"
                        )
                        
                        ActivityStatCard(
                            title: "Total Events",
                            value: "\(stats.totalEvents)"
                        )
                    }
                }
            }
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Timeline (compact)
            if settings.activityLoggingEnabled && !timelineBuckets.isEmpty {
                ActivityTimelineView(
                    selectedTimeRange: $selectedTimeRange,
                    buckets: timelineBuckets,
                    timeRange: $timelineRange
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xs)
            }
            
            // Live Activity Stream (always shown when activity logging is enabled)
            if settings.activityLoggingEnabled {
                LiveActivityStreamView()
                    .frame(height: 250)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.xs)
            }
            
            // Content
            if !settings.activityLoggingEnabled {
                VStack(spacing: Spacing.lg) {
                    Text("Activity Logging Disabled")
                        .font(.system(size: Typography.headingSize))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("Enable activity logging in Settings to track app usage")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        settings.showSettings = true
                    }) {
                        Text("OPEN SETTINGS")
                            .font(.system(size: Typography.bodySize, weight: .medium))
                    }
                    .buttonStyle(BrutalistPrimaryButtonStyle())
                    .padding(.top, Spacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Spacing.xl)
            } else if store.categorySummaries.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Text("No Activity Data")
                        .font(.system(size: Typography.headingSize))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("Activity summaries will appear here as you use your Mac.")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        store.testEvent()
                    }) {
                        Text("TEST EVENT")
                            .font(.system(size: Typography.bodySize, weight: .medium))
                    }
                    .buttonStyle(BrutalistSecondaryButtonStyle())
                    .padding(.top, Spacing.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Spacing.xl)
            } else {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Category Chart (Stacked Area)
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("CATEGORIES OVER TIME")
                                .font(.system(size: Typography.smallSize, weight: .semibold))
                                .foregroundColor(Color.brutalistTextMuted)
                                .padding(.horizontal, Spacing.lg)
                            
                            if store.categoryChartSeries.isEmpty {
                                Text("No category data available")
                                    .font(.system(size: Typography.bodySize))
                                    .foregroundColor(Color.brutalistTextMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Spacing.xl)
                                    .padding(.horizontal, Spacing.lg)
                            } else {
                                ImprovedStackedAreaChartView(series: store.categoryChartSeries, height: 200)
                                    .padding(.horizontal, Spacing.lg)
                                    .padding(.vertical, Spacing.md)
                                    .background(Color.brutalistBgSecondary)
                                    .cornerRadius(BorderRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BorderRadius.sm)
                                            .stroke(Color.brutalistBorder, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.top, Spacing.lg)
                        
                        // Time Period Summaries
                        if !store.timePeriodSummaries.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text("HOURLY BREAKDOWN")
                                    .font(.system(size: Typography.smallSize, weight: .semibold))
                                    .foregroundColor(Color.brutalistTextMuted)
                                    .padding(.horizontal, Spacing.lg)
                                
                                LazyVStack(spacing: Spacing.md) {
                                    ForEach(store.timePeriodSummaries.prefix(12)) { period in
                                        TimePeriodSummaryCard(period: period)
                                    }
                                }
                                .padding(.horizontal, Spacing.lg)
                            }
                            .padding(.top, Spacing.lg)
                        }
                    }
                    .padding(.bottom, Spacing.lg)
                }
            }
            
            // Error indicator
            if let error = store.monitoringError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextPrimary)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        store.monitoringError = nil
                    }
                    .buttonStyle(BrutalistSecondaryButtonStyle())
                }
                .padding(Spacing.md)
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
            Text("This will permanently delete all activity logs. This action cannot be undone.")
        }
        .onAppear {
            if settings.activityLoggingEnabled && !store.isMonitoringActive {
                store.startMonitoring()
            }
            store.calculateStatsAsync()
            loadTimelineBuckets()
        }
        .onChange(of: timelineRange) { _ in
            loadTimelineBuckets()
            selectedTimeRange = nil
        }
        .onChange(of: store.events.count) { _ in
            loadTimelineBuckets()
        }
    }
    
    private func loadTimelineBuckets() {
        DispatchQueue.global(qos: .userInitiated).async {
            let buckets = store.calculateTimelineBuckets(for: timelineRange)
            
            DispatchQueue.main.async {
                self.timelineBuckets = buckets
            }
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Category Summary Card

struct CategorySummaryCard: View {
    let summary: CategorySummary
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: summary.icon)
                .foregroundColor(summary.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(summary.category)
                    .font(.system(size: Typography.bodySize, weight: .medium))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                HStack(spacing: Spacing.sm) {
                    if let duration = summary.duration {
                        Text(formatDuration(duration))
                            .font(.system(size: Typography.smallSize))
                            .foregroundColor(Color.brutalistTextSecondary)
                    }
                    
                    Text("\(summary.count) events")
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("•")
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("\(Int(summary.percentage))%")
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                }
            }
            
            Spacer()
            
            // Percentage bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.brutalistBgSecondary)
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(summary.color)
                        .frame(width: geometry.size.width * CGFloat(summary.percentage / 100), height: 4)
                }
            }
            .frame(width: 80, height: 4)
        }
        .padding(Spacing.md)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.sm)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
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

// MARK: - Time Period Summary Card

struct TimePeriodSummaryCard: View {
    let period: TimePeriodSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(period.period)
                    .font(.system(size: Typography.bodySize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                Text("\(period.totalEvents) events")
                    .font(.system(size: Typography.smallSize))
                    .foregroundColor(Color.brutalistTextMuted)
            }
            
            if !period.appSummaries.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Top Apps:")
                        .font(.system(size: Typography.smallSize, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                    
                    HStack(spacing: Spacing.sm) {
                        ForEach(period.appSummaries.prefix(3)) { app in
                            HStack(spacing: 4) {
                                Text(app.category)
                                    .font(.system(size: Typography.smallSize))
                                    .foregroundColor(Color.brutalistTextSecondary)
                                
                                Text("\(Int(app.percentage))%")
                                    .font(.system(size: Typography.smallSize))
                                    .foregroundColor(Color.brutalistTextMuted)
                            }
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.brutalistBgSecondary)
                            .cornerRadius(4)
                        }
                    }
                }
            }
            
            if !period.eventTypeSummaries.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Event Types:")
                        .font(.system(size: Typography.smallSize, weight: .medium))
                        .foregroundColor(Color.brutalistTextSecondary)
                    
                    HStack(spacing: Spacing.sm) {
                        ForEach(period.eventTypeSummaries.prefix(3)) { eventType in
                            HStack(spacing: 4) {
                                Image(systemName: eventType.icon)
                                    .font(.system(size: 10))
                                    .foregroundColor(eventType.color)
                                
                                Text(eventType.category)
                                    .font(.system(size: Typography.smallSize))
                                    .foregroundColor(Color.brutalistTextSecondary)
                                
                                Text("\(Int(eventType.percentage))%")
                                    .font(.system(size: Typography.smallSize))
                                    .foregroundColor(Color.brutalistTextMuted)
                            }
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.brutalistBgSecondary)
                            .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.sm)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
    }
}

// MARK: - Stat Card

struct ActivityStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.system(size: Typography.smallSize))
                .foregroundColor(Color.brutalistTextMuted)
            
            Text(value)
                .font(.system(size: Typography.headingSize, weight: .semibold))
                .foregroundColor(Color.brutalistTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.brutalistBgPrimary)
        .cornerRadius(BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.sm)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
    }
}
