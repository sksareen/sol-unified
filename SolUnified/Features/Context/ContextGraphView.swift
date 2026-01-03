//
//  ContextGraphView.swift
//  SolUnified
//
//  Visualization of the context graph - work contexts, sequences, and relationships
//

import SwiftUI

struct ContextGraphView: View {
    @ObservedObject private var graphManager = ContextGraphManager.shared
    @ObservedObject private var activityStore = ActivityStore.shared
    @State private var selectedNode: ContextNode?
    @State private var timeFilter: TimeFilter = .last24h
    
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
            // Header with active context
            activeContextHeader
            
            // Time filter
            timeFilterBar
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Context Timeline
                    contextTimeline
                    
                    // Context Relationships
                    if !graphManager.edges.isEmpty {
                        contextRelationships
                    }
                    
                    // Context Stats
                    contextStats
                }
                .padding()
            }
        }
        .background(Color.brutalistBgPrimary)
    }
    
    // MARK: - Active Context Header
    
    private var activeContextHeader: some View {
        Group {
            if let active = graphManager.activeContext {
                HStack(spacing: 12) {
                    // Context type indicator
                    Circle()
                        .fill(active.type.color)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .fill(active.type.color.opacity(0.3))
                                .frame(width: 24, height: 24)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACTIVE CONTEXT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.brutalistTextMuted)
                            .tracking(0.5)
                        
                        Text(active.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.brutalistTextPrimary)
                    }
                    
                    Spacer()
                    
                    // Focus score
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("FOCUS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.brutalistTextMuted)
                            .tracking(0.5)
                        
                        Text("\(Int(active.focusScore * 100))%")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(focusColor(active.focusScore))
                    }
                    
                    // Duration
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("DURATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.brutalistTextMuted)
                            .tracking(0.5)
                        
                        Text(formatDuration(active.duration))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.brutalistTextPrimary)
                    }
                }
                .padding()
                .background(Color.brutalistBgSecondary)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.brutalistBorder),
                    alignment: .bottom
                )
            } else {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.brutalistTextMuted)
                    Text("No active context detected")
                        .font(.system(size: 13))
                        .foregroundColor(.brutalistTextSecondary)
                    Spacer()
                    
                    if !activityStore.isMonitoringActive {
                        Button("Start Monitoring") {
                            activityStore.startMonitoring()
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.brutalistAccent)
                    }
                }
                .padding()
                .background(Color.brutalistBgSecondary)
            }
        }
    }
    
    // MARK: - Time Filter
    
    private var timeFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(TimeFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        timeFilter = filter
                    }
                }) {
                    Text(filter.rawValue)
                        .font(.system(size: 11, weight: timeFilter == filter ? .bold : .medium, design: .monospaced))
                        .foregroundColor(timeFilter == filter ? .brutalistTextPrimary : .brutalistTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            timeFilter == filter ?
                                RoundedRectangle(cornerRadius: 4).fill(Color.brutalistBgTertiary) :
                                RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            Text("\(filteredNodes.count) contexts")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.brutalistTextMuted)
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
    
    // MARK: - Context Timeline
    
    private var contextTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "timeline.selection")
                    .foregroundColor(.brutalistAccent)
                Text("CONTEXT TIMELINE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.brutalistTextMuted)
                Spacer()
            }
            
            if filteredNodes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 32))
                        .foregroundColor(.brutalistTextMuted)
                    Text("No context history yet")
                        .font(.system(size: 13))
                        .foregroundColor(.brutalistTextSecondary)
                    Text("Start using apps to build your context graph")
                        .font(.system(size: 11))
                        .foregroundColor(.brutalistTextMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredNodes) { node in
                        ContextNodeRow(node: node, isActive: node.id == graphManager.activeContext?.id)
                            .onTapGesture {
                                selectedNode = node
                            }
                    }
                }
            }
        }
        .padding()
        .background(Color.brutalistBgSecondary)
        .cornerRadius(8)
        .sheet(item: $selectedNode) { node in
            ContextNodeDetailView(node: node, edges: graphManager.edges.filter { 
                $0.fromContextId == node.id || $0.toContextId == node.id 
            })
        }
    }
    
    // MARK: - Context Relationships
    
    private var contextRelationships: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.brutalistAccent)
                Text("RECENT TRANSITIONS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.brutalistTextMuted)
                Spacer()
            }
            
            LazyVStack(spacing: 6) {
                ForEach(graphManager.edges.prefix(10)) { edge in
                    ContextEdgeRow(edge: edge, nodes: graphManager.nodes)
                }
            }
        }
        .padding()
        .background(Color.brutalistBgSecondary)
        .cornerRadius(8)
    }
    
    // MARK: - Context Stats
    
    private var contextStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.brutalistAccent)
                Text("CONTEXT BREAKDOWN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.brutalistTextMuted)
                Spacer()
            }
            
            // Group by context type
            let typeGroups = Dictionary(grouping: filteredNodes, by: { $0.type })
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ContextType.allCases, id: \.self) { type in
                    let nodes = typeGroups[type] ?? []
                    let totalDuration = nodes.reduce(0) { $0 + $1.duration }
                    
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 20))
                            .foregroundColor(type.color)
                        
                        Text(type.rawValue.capitalized)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.brutalistTextSecondary)
                        
                        Text("\(nodes.count)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.brutalistTextPrimary)
                        
                        Text(formatDuration(totalDuration))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.brutalistTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.brutalistBgTertiary)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.brutalistBgSecondary)
        .cornerRadius(8)
    }
    
    // MARK: - Helpers
    
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

// MARK: - Context Node Row

struct ContextNodeRow: View {
    let node: ContextNode
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            VStack {
                Circle()
                    .fill(node.type.color)
                    .frame(width: 8, height: 8)
                
                if isActive {
                    Rectangle()
                        .fill(node.type.color.opacity(0.3))
                        .frame(width: 2, height: 30)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.label)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                        .foregroundColor(.brutalistTextPrimary)
                    
                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(node.type.color)
                            .cornerRadius(3)
                    }
                    
                    Spacer()
                    
                    Text(formatTime(node.startTime))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.brutalistTextMuted)
                }
                
                HStack(spacing: 8) {
                    // Focus score
                    HStack(spacing: 4) {
                        Image(systemName: "scope")
                            .font(.system(size: 9))
                        Text("\(Int(node.focusScore * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(.brutalistTextSecondary)
                    
                    // Event count
                    HStack(spacing: 4) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 9))
                        Text("\(node.eventCount)")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(.brutalistTextSecondary)
                    
                    // Apps count
                    HStack(spacing: 4) {
                        Image(systemName: "app")
                            .font(.system(size: 9))
                        Text("\(node.apps.count)")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(.brutalistTextSecondary)
                    
                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(formatDuration(node.duration))
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(.brutalistTextSecondary)
                    
                    // Linked content indicators
                    if !node.clipboardItemHashes.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 9))
                            Text("\(node.clipboardItemHashes.count)")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundColor(.brutalistAccent)
                    }
                    
                    if !node.screenshotFilenames.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "photo")
                                .font(.system(size: 9))
                            Text("\(node.screenshotFilenames.count)")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundColor(.brutalistAccent)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isActive ? Color.brutalistBgTertiary.opacity(0.5) : Color.clear)
        .cornerRadius(6)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MMM d HH:mm"
        }
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h\(remainingMinutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
}

// MARK: - Context Edge Row

struct ContextEdgeRow: View {
    let edge: ContextEdge
    let nodes: [ContextNode]
    
    private var fromNode: ContextNode? {
        nodes.first { $0.id == edge.fromContextId }
    }
    
    private var toNode: ContextNode? {
        nodes.first { $0.id == edge.toContextId }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // From context
            Text(fromNode?.label ?? "Unknown")
                .font(.system(size: 11))
                .foregroundColor(.brutalistTextSecondary)
                .lineLimit(1)
            
            // Edge indicator
            Image(systemName: edgeIcon)
                .font(.system(size: 10))
                .foregroundColor(edgeColor)
            
            // To context
            Text(toNode?.label ?? "Unknown")
                .font(.system(size: 11))
                .foregroundColor(.brutalistTextSecondary)
                .lineLimit(1)
            
            Spacer()
            
            // Time
            Text(formatTime(edge.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.brutalistTextMuted)
        }
        .padding(.vertical, 4)
    }
    
    private var edgeIcon: String {
        switch edge.edgeType {
        case .transitionedTo: return "arrow.right"
        case .interruptedBy: return "exclamationmark.arrow.circlepath"
        case .resumedFrom: return "arrow.uturn.backward"
        case .spawned: return "arrow.branch"
        case .related: return "link"
        case .parentChild: return "arrow.down.right"
        }
    }
    
    private var edgeColor: Color {
        switch edge.edgeType {
        case .transitionedTo: return .brutalistTextMuted
        case .interruptedBy: return Color(hex: "#ef4444")
        case .resumedFrom: return Color(hex: "#10b981")
        case .spawned: return Color(hex: "#8b5cf6")
        case .related: return Color(hex: "#3b82f6")
        case .parentChild: return Color(hex: "#f59e0b")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Context Node Detail View

struct ContextNodeDetailView: View {
    let node: ContextNode
    let edges: [ContextEdge]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(node.type.color)
                            .frame(width: 12, height: 12)
                        Text(node.type.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.brutalistTextMuted)
                    }
                    
                    Text(node.label)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.brutalistTextPrimary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.brutalistTextMuted)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color.brutalistBgSecondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Metrics
                    HStack(spacing: 20) {
                        metricBox(title: "FOCUS", value: "\(Int(node.focusScore * 100))%", icon: "scope")
                        metricBox(title: "EVENTS", value: "\(node.eventCount)", icon: "dot.radiowaves.left.and.right")
                        metricBox(title: "DURATION", value: formatDuration(node.duration), icon: "clock")
                    }
                    
                    // Time range
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TIME")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.brutalistTextMuted)
                        
                        HStack {
                            Text(formatDateTime(node.startTime))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.brutalistTextPrimary)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(.brutalistTextMuted)
                            
                            if let endTime = node.endTime {
                                Text(formatDateTime(endTime))
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.brutalistTextPrimary)
                            } else {
                                Text("Now")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.brutalistAccent)
                            }
                        }
                    }
                    
                    // Apps used
                    if !node.apps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APPS (\(node.apps.count))")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(.brutalistTextMuted)
                            
                            FlowLayout(spacing: 6) {
                                ForEach(Array(node.apps), id: \.self) { bundleId in
                                    Text(bundleId.components(separatedBy: ".").last ?? bundleId)
                                        .font(.system(size: 11, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.brutalistBgTertiary)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    // Window titles
                    if !node.windowTitles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WINDOWS (\(node.windowTitles.count))")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(.brutalistTextMuted)
                            
                            ForEach(node.windowTitles.prefix(5), id: \.self) { title in
                                Text(title)
                                    .font(.system(size: 12))
                                    .foregroundColor(.brutalistTextSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    // Linked content
                    if !node.clipboardItemHashes.isEmpty || !node.screenshotFilenames.isEmpty || !node.noteIds.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LINKED CONTENT")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(.brutalistTextMuted)
                            
                            HStack(spacing: 16) {
                                if !node.clipboardItemHashes.isEmpty {
                                    Label("\(node.clipboardItemHashes.count) clipboard items", systemImage: "doc.on.clipboard")
                                        .font(.system(size: 12))
                                        .foregroundColor(.brutalistTextSecondary)
                                }
                                
                                if !node.screenshotFilenames.isEmpty {
                                    Label("\(node.screenshotFilenames.count) screenshots", systemImage: "photo")
                                        .font(.system(size: 12))
                                        .foregroundColor(.brutalistTextSecondary)
                                }
                                
                                if !node.noteIds.isEmpty {
                                    Label("\(node.noteIds.count) notes", systemImage: "note.text")
                                        .font(.system(size: 12))
                                        .foregroundColor(.brutalistTextSecondary)
                                }
                            }
                        }
                    }
                    
                    // Related transitions
                    if !edges.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TRANSITIONS (\(edges.count))")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(.brutalistTextMuted)
                            
                            ForEach(edges) { edge in
                                HStack {
                                    Image(systemName: edge.fromContextId == node.id ? "arrow.right.circle" : "arrow.left.circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(.brutalistAccent)
                                    
                                    Text(edge.edgeType.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression))
                                        .font(.system(size: 12))
                                        .foregroundColor(.brutalistTextSecondary)
                                    
                                    Spacer()
                                    
                                    Text(formatTime(edge.timestamp))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.brutalistTextMuted)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(Color.brutalistBgPrimary)
    }
    
    private func metricBox(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.brutalistAccent)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.brutalistTextPrimary)
            
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.brutalistTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.brutalistBgTertiary)
        .cornerRadius(8)
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
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: ProposedViewSize(result.sizes[index]))
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)
                sizes.append(viewSize)
                
                if currentX + viewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                
                currentX += viewSize.width + spacing
                lineHeight = max(lineHeight, viewSize.height)
            }
            
            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

