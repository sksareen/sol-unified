//
//  ActivityView.swift
//  SolUnified
//
//  Activity logging UI with stats, events, and filters
//

import SwiftUI
import AppKit

struct ActivityView: View {
    @ObservedObject var store = ActivityStore.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedEventType: ActivityEventType?
    @State private var selectedApp: String?
    @State private var showingClearConfirm = false
    
    var filteredEvents: [ActivityEvent] {
        var events = store.events
        
        if let eventType = selectedEventType {
            events = events.filter { $0.eventType == eventType }
        }
        
        if let appBundleId = selectedApp {
            events = events.filter { $0.appBundleId == appBundleId }
        }
        
        return events
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Status
            VStack(spacing: Spacing.md) {
                HStack {
                    HStack(spacing: Spacing.sm) {
                        // Status indicator
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text("ACTIVITY LOG")
                            .font(.system(size: Typography.headingSize, weight: .semibold))
                            .foregroundColor(Color.brutalistTextPrimary)
                    }
                    
                    Spacer()
                    
                    if store.isMonitoringActive {
                        VStack(alignment: .trailing, spacing: Spacing.xs) {
                            Text("\(store.eventsTodayCount) events today")
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
                        store.loadRecentEvents(limit: 100)
                        store.calculateStatsAsync()
                    }) {
                        Text("REFRESH")
                            .font(.system(size: Typography.bodySize, weight: .medium))
                    }
                    .buttonStyle(BrutalistSecondaryButtonStyle())
                    
                    Button(action: {
                        showingClearConfirm = true
                    }) {
                        Text("CLEAR")
                            .font(.system(size: Typography.bodySize, weight: .medium))
                    }
                    .buttonStyle(BrutalistSecondaryButtonStyle())
                }
                
                // Quick Stats
                if let stats = store.stats {
                    HStack(spacing: Spacing.md) {
                        ActivityStatCard(
                            title: "Active Time",
                            value: formatDuration(stats.totalActiveTime)
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
                
                // Filters
                HStack(spacing: Spacing.md) {
                    Text("FILTERS:")
                        .font(.system(size: Typography.smallSize, weight: .semibold))
                        .foregroundColor(Color.brutalistTextSecondary)
                    
                    Picker("Event Type", selection: $selectedEventType) {
                        Text("All Events").tag(nil as ActivityEventType?)
                        ForEach([ActivityEventType.appActivate, .appLaunch, .appTerminate, .windowTitleChange, .idleStart, .idleEnd], id: \.self) { type in
                            Text(typeLabel(type)).tag(type as ActivityEventType?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: 150)
                    
                    Spacer()
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
            
            // Content
            if !settings.activityLoggingEnabled {
                // Not enabled
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
            } else if filteredEvents.isEmpty {
                // Empty state
                VStack(spacing: Spacing.lg) {
                    Text("No Activity Events")
                        .font(.system(size: Typography.headingSize))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("Activity logging is enabled. Events will appear here as you use your Mac.")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextSecondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Switch apps, open windows, and activity will be tracked.")
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
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
                // Event list
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(groupedEvents) { group in
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(group.title)
                                    .font(.system(size: Typography.smallSize, weight: .semibold))
                                    .foregroundColor(Color.brutalistTextMuted)
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.top, Spacing.sm)
                                
                                ForEach(group.events) { event in
                                    ActivityEventCard(event: event)
                                }
                            }
                        }
                    }
                    .padding(Spacing.lg)
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
    
    private var groupedEvents: [EventGroup] {
        let calendar = Calendar.current
        var groups: [EventGroup] = []
        var currentGroup: EventGroup?
        
        for event in filteredEvents {
            let date = event.timestamp
            let groupTitle: String
            
            if calendar.isDateInToday(date) {
                groupTitle = "Today"
            } else if calendar.isDateInYesterday(date) {
                groupTitle = "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                groupTitle = formatter.string(from: date)
            }
            
            if let existing = currentGroup, existing.title == groupTitle {
                currentGroup?.events.append(event)
            } else {
                if let existing = currentGroup {
                    groups.append(existing)
                }
                currentGroup = EventGroup(title: groupTitle, events: [event])
            }
        }
        
        if let last = currentGroup {
            groups.append(last)
        }
        
        return groups
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
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
    
    private func typeLabel(_ type: ActivityEventType) -> String {
        switch type {
        case .appLaunch: return "App Launch"
        case .appTerminate: return "App Terminate"
        case .appActivate: return "App Switch"
        case .windowTitleChange: return "Window Change"
        case .idleStart: return "Idle Start"
        case .idleEnd: return "Idle End"
        case .screenSleep: return "Screen Sleep"
        case .screenWake: return "Screen Wake"
        case .heartbeat: return "Heartbeat"
        }
    }
}

struct EventGroup: Identifiable {
    let id = UUID()
    let title: String
    var events: [ActivityEvent]
}

struct ActivityStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.system(size: Typography.smallSize))
                .foregroundColor(Color.brutalistTextMuted)
            
            Text(value)
                .font(.system(size: Typography.bodySize, weight: .semibold))
                .foregroundColor(Color.brutalistTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.brutalistBgTertiary)
        .cornerRadius(BorderRadius.sm)
    }
}

struct ActivityEventCard: View {
    let event: ActivityEvent
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Event type icon
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            // Event details
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(eventDescription)
                    .font(.system(size: Typography.bodySize))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                if let windowTitle = event.windowTitle {
                    Text(windowTitle)
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(eventTypeLabel)
                        .font(.system(size: Typography.smallSize, weight: .medium))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("•")
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text(formatTime(event.timestamp))
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                }
            }
            
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.sm)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
    }
    
    private var iconName: String {
        switch event.eventType {
        case .appLaunch: return "arrow.up.circle.fill"
        case .appTerminate: return "xmark.circle.fill"
        case .appActivate: return "app.badge.fill"
        case .windowTitleChange: return "square.stack.3d.up.fill"
        case .idleStart: return "moon.fill"
        case .idleEnd: return "sun.max.fill"
        case .screenSleep: return "moon.zzz.fill"
        case .screenWake: return "sunrise.fill"
        case .heartbeat: return "heart.fill"
        }
    }
    
    private var iconColor: Color {
        switch event.eventType {
        case .appLaunch, .appActivate, .screenWake, .idleEnd:
            return Color.brutalistAccent
        case .appTerminate, .screenSleep, .idleStart:
            return Color.brutalistTextMuted
        case .windowTitleChange, .heartbeat:
            return Color.brutalistTextSecondary
        }
    }
    
    private var eventDescription: String {
        if let appName = event.appName {
            switch event.eventType {
            case .appLaunch: return "\(appName) launched"
            case .appTerminate: return "\(appName) terminated"
            case .appActivate: return "Switched to \(appName)"
            case .windowTitleChange: return "Window changed in \(appName)"
            case .idleStart: return "User idle"
            case .idleEnd: return "User active"
            case .screenSleep: return "Screen slept"
            case .screenWake: return "Screen woke"
            case .heartbeat: return "Heartbeat"
            }
        } else {
            return eventTypeLabel
        }
    }
    
    private var eventTypeLabel: String {
        switch event.eventType {
        case .appLaunch: return "Launch"
        case .appTerminate: return "Terminate"
        case .appActivate: return "Switch"
        case .windowTitleChange: return "Window"
        case .idleStart: return "Idle"
        case .idleEnd: return "Active"
        case .screenSleep: return "Sleep"
        case .screenWake: return "Wake"
        case .heartbeat: return "Heartbeat"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

