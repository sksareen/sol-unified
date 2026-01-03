//
//  UnifiedActivityView.swift
//  SolUnified
//
//  Combined Activity + Context Graph view
//  Shows semantic context by default, with drill-down to raw events
//

import SwiftUI

struct UnifiedActivityView: View {
    @ObservedObject private var graphManager = ContextGraphManager.shared
    @ObservedObject private var activityStore = ActivityStore.shared
    @ObservedObject private var settings = AppSettings.shared
    
    @State private var viewMode: ViewMode = .context
    @State private var selectedNode: ContextNode?
    @State private var timeFilter: TimeFilter = .last4h
    @State private var showingClearConfirm = false
    
    enum ViewMode: String, CaseIterable {
        case context = "CONTEXT"
        case events = "EVENTS"
    }
    
    enum TimeFilter: String, CaseIterable {
        case last1h = "1H"
        case last4h = "4H"
        case last24h = "24H"
        case last7d = "7D"
        
        var hours: Int {
            switch self {
            case .last1h: return 1
            case .last4h: return 4
            case .last24h: return 24
            case .last7d: return 168
            }
        }
    }
    
    private var filteredNodes: [ContextNode] {
        graphManager.getRecentContexts(hours: timeFilter.hours)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content based on enabled state
            if !settings.activityLoggingEnabled {
                disabledView
            } else {
                // Mode toggle + time filter
                controlBar
                
                // Main content
                switch viewMode {
                case .context:
                    contextView
                case .events:
                    eventsView
                }
            }
        }
        .background(Color.brutalistBgPrimary)
        .alert("Clear All Activity Logs?", isPresented: $showingClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                _ = activityStore.clearHistory()
            }
        } message: {
            Text("This will permanently delete all activity logs and context history.")
        }
        .onAppear {
            if settings.activityLoggingEnabled && !activityStore.isMonitoringActive {
                activityStore.startMonitoring()
            }
            activityStore.calculateStatsAsync()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
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
            
            if activityStore.isMonitoringActive {
                HStack(spacing: 12) {
                    // Active context indicator
                    if let active = graphManager.activeContext {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(active.type.color)
                                .frame(width: 6, height: 6)
                            Text(active.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.brutalistTextSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: 150)
                    }
                    
                    Text("\(activityStore.eventsTodayCount) EVENTS")
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
    }
    
    // MARK: - Control Bar
    
    private var controlBar: some View {
        HStack(spacing: 12) {
            // View mode toggle
            HStack(spacing: 4) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewMode = mode
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(.system(size: 10, weight: viewMode == mode ? .bold : .medium))
                            .foregroundColor(viewMode == mode ? .brutalistTextPrimary : .brutalistTextSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                viewMode == mode ?
                                    RoundedRectangle(cornerRadius: 4).fill(Color.brutalistBgTertiary) :
                                    RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(2)
            .background(Color.brutalistBgSecondary)
            .cornerRadius(6)
            
            Divider()
                .frame(height: 16)
            
            // Time filter (only for context mode)
            if viewMode == .context {
                HStack(spacing: 4) {
                    ForEach(TimeFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                timeFilter = filter
                            }
                        }) {
                            Text(filter.rawValue)
                                .font(.system(size: 10, weight: timeFilter == filter ? .bold : .medium, design: .monospaced))
                                .foregroundColor(timeFilter == filter ? .brutalistTextPrimary : .brutalistTextMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    timeFilter == filter ?
                                        RoundedRectangle(cornerRadius: 3).fill(Color.brutalistBgTertiary) :
                                        RoundedRectangle(cornerRadius: 3).fill(Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Spacer()
            
            // Stats
            if viewMode == .context {
                Text("\(filteredNodes.count) contexts")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.brutalistTextMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.brutalistBgPrimary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.brutalistBorder),
            alignment: .bottom
        )
    }
    
    // MARK: - Context View (Semantic)
    
    private var contextView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Active context card
                if let active = graphManager.activeContext {
                    activeContextCard(active)
                }
                
                // Focus stats
                focusStatsRow
                
                // Context timeline
                contextTimeline
                
                // Context breakdown
                if !filteredNodes.isEmpty {
                    contextBreakdown
                }
            }
            .padding()
        }
        .sheet(item: $selectedNode) { node in
            ContextNodeDetailView(node: node, edges: graphManager.edges.filter { 
                $0.fromContextId == node.id || $0.toContextId == node.id 
            })
        }
    }
    
    private func activeContextCard(_ active: ContextNode) -> some View {
        HStack(spacing: 16) {
            // Type icon
            VStack {
                Image(systemName: active.type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(active.type.color)
                
                Text("ACTIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(active.type.color)
                    .cornerRadius(3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(active.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.brutalistTextPrimary)
                
                HStack(spacing: 12) {
                    Label("\(Int(active.focusScore * 100))%", systemImage: "scope")
                        .font(.system(size: 11))
                        .foregroundColor(focusColor(active.focusScore))
                    
                    Label(formatDuration(active.duration), systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.brutalistTextSecondary)
                    
                    Label("\(active.eventCount)", systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 11))
                        .foregroundColor(.brutalistTextSecondary)
                }
            }
            
            Spacer()
            
            // Quick stats
            VStack(alignment: .trailing, spacing: 2) {
                if !active.clipboardItemHashes.isEmpty {
                    Label("\(active.clipboardItemHashes.count)", systemImage: "doc.on.clipboard")
                        .font(.system(size: 10))
                        .foregroundColor(.brutalistAccent)
                }
                if !active.screenshotFilenames.isEmpty {
                    Label("\(active.screenshotFilenames.count)", systemImage: "photo")
                        .font(.system(size: 10))
                        .foregroundColor(.brutalistAccent)
                }
            }
        }
        .padding()
        .background(Color.brutalistBgSecondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(active.type.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var focusStatsRow: some View {
        HStack(spacing: 12) {
            // Today's focus score (average)
            let avgFocus = filteredNodes.isEmpty ? 0 : filteredNodes.reduce(0) { $0 + $1.focusScore } / Double(filteredNodes.count)
            statCard(title: "AVG FOCUS", value: "\(Int(avgFocus * 100))%", color: focusColor(avgFocus))
            
            // Total active time
            let totalTime = filteredNodes.reduce(0) { $0 + $1.duration }
            statCard(title: "ACTIVE TIME", value: formatDuration(totalTime), color: .brutalistAccent)
            
            // Context switches
            statCard(title: "SWITCHES", value: "\(max(0, filteredNodes.count - 1))", color: .brutalistTextSecondary)
        }
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.brutalistTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(8)
    }
    
    private var contextTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "timeline.selection")
                    .foregroundColor(.brutalistAccent)
                Text("CONTEXT HISTORY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.brutalistTextMuted)
                Spacer()
            }
            
            if filteredNodes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 28))
                        .foregroundColor(.brutalistTextMuted)
                    Text("No context history yet")
                        .font(.system(size: 12))
                        .foregroundColor(.brutalistTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(filteredNodes.prefix(15)) { node in
                        CompactContextRow(node: node, isActive: node.id == graphManager.activeContext?.id)
                            .onTapGesture { selectedNode = node }
                    }
                    
                    if filteredNodes.count > 15 {
                        Text("+ \(filteredNodes.count - 15) more")
                            .font(.system(size: 10))
                            .foregroundColor(.brutalistTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .padding()
        .background(Color.brutalistBgSecondary)
        .cornerRadius(8)
    }
    
    private var contextBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundColor(.brutalistAccent)
                Text("BY TYPE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.brutalistTextMuted)
                Spacer()
            }
            
            let typeGroups = Dictionary(grouping: filteredNodes, by: { $0.type })
            let totalDuration = filteredNodes.reduce(0) { $0 + $1.duration }
            
            // Only show types that have data
            let activeTypes = ContextType.allCases.filter { (typeGroups[$0]?.count ?? 0) > 0 }
            
            ForEach(activeTypes, id: \.self) { type in
                let nodes = typeGroups[type] ?? []
                let typeDuration = nodes.reduce(0) { $0 + $1.duration }
                let percentage = totalDuration > 0 ? typeDuration / totalDuration : 0
                
                HStack(spacing: 10) {
                    Image(systemName: type.icon)
                        .font(.system(size: 12))
                        .foregroundColor(type.color)
                        .frame(width: 20)
                    
                    Text(type.rawValue.capitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.brutalistTextPrimary)
                        .frame(width: 80, alignment: .leading)
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.brutalistBgTertiary)
                            Rectangle()
                                .fill(type.color)
                                .frame(width: geo.size.width * CGFloat(percentage))
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
                    Text(formatDuration(typeDuration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.brutalistTextMuted)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color.brutalistBgSecondary)
        .cornerRadius(8)
    }
    
    // MARK: - Events View (Raw)
    
    private var eventsView: some View {
        VStack(spacing: 0) {
            // App Usage Chart (compact)
            if let stats = activityStore.stats, !stats.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("APP USAGE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.brutalistTextMuted)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    
                    CompactAppUsageChart(apps: Array(stats.topApps.prefix(5)))
                        .frame(height: 100)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                .background(Color.brutalistBgSecondary)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.brutalistBorder),
                    alignment: .bottom
                )
            }
            
            // Live event stream
            LiveActivityStreamView()
                .frame(maxHeight: .infinity)
        }
    }
    
    // MARK: - Disabled View
    
    private var disabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(.brutalistTextMuted)
            
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
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        if !activityStore.isMonitoringActive {
            return .gray
        } else if activityStore.monitoringError != nil {
            return .red
        } else if let lastEvent = activityStore.lastEventTime,
                  Date().timeIntervalSince(lastEvent) > 300 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
    
    private func focusColor(_ score: Double) -> Color {
        if score >= 0.7 { return Color(hex: "#10b981") }
        if score >= 0.4 { return Color(hex: "#f59e0b") }
        return Color(hex: "#ef4444")
    }
}

// MARK: - Compact Context Row

struct CompactContextRow: View {
    let node: ContextNode
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(node.type.color)
                .frame(width: 6, height: 6)
            
            Text(node.label)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundColor(.brutalistTextPrimary)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(Int(node.focusScore * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.brutalistTextMuted)
            
            Text(formatDuration(node.duration))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.brutalistTextMuted)
            
            Text(formatTime(node.startTime))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.brutalistTextMuted)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isActive ? Color.brutalistBgTertiary.opacity(0.5) : Color.clear)
        .cornerRadius(4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        return "\(minutes / 60)h\(minutes % 60)m"
    }
}

// MARK: - Compact App Usage Chart

struct CompactAppUsageChart: View {
    let apps: [ActivityStats.AppTime]
    
    private var maxTime: TimeInterval {
        apps.map { $0.totalTime }.max() ?? 1
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(apps, id: \.appBundleId) { app in
                VStack(spacing: 4) {
                    // Bar
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.brutalistBgTertiary)
                            .frame(width: 24)
                        
                        Rectangle()
                            .fill(appColor(app.appName))
                            .frame(width: 24, height: CGFloat(app.totalTime / maxTime) * 70)
                    }
                    .frame(height: 70)
                    .cornerRadius(4)
                    
                    // Label
                    Text(shortName(app.appName))
                        .font(.system(size: 8))
                        .foregroundColor(.brutalistTextMuted)
                        .lineLimit(1)
                        .frame(width: 40)
                }
            }
            Spacer()
        }
    }
    
    private func shortName(_ name: String) -> String {
        let words = name.components(separatedBy: " ")
        if words.count > 1 {
            return words.map { String($0.prefix(1)) }.joined()
        }
        return String(name.prefix(5))
    }
    
    private func appColor(_ appName: String) -> Color {
        let colors: [Color] = [
            Color(hex: "3B82F6"),
            Color(hex: "10B981"),
            Color(hex: "F59E0B"),
            Color(hex: "8B5CF6"),
            Color(hex: "EF4444")
        ]
        let hash = abs(appName.hashValue)
        return colors[hash % colors.count]
    }
}

