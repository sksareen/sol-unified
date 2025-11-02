//
//  TimelineView.swift
//  SolUnified
//
//  Timeline visualization for activity log
//

import SwiftUI

struct ActivityTimelineView: View {
    @Binding var selectedTimeRange: DateInterval?
    let buckets: [TimelineBucket]
    @Binding var timeRange: TimeRange
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Time range selector
            HStack {
                Text("Timeline:")
                    .font(.system(size: Typography.smallSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextSecondary)
                
                Picker("", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)
                
                Spacer()
                
                if let selected = selectedTimeRange {
                    Text(formatSelectedRange(selected))
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                }
            }
            
            if buckets.isEmpty {
                // Empty state
                Text("No activity data for this period")
                    .font(.system(size: Typography.bodySize))
                    .foregroundColor(Color.brutalistTextMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
            } else {
                // Timeline bars
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(buckets) { bucket in
                            TimelineBucketView(
                                bucket: bucket,
                                isSelected: isBucketSelected(bucket),
                                width: calculateWidth(for: bucket, in: geometry)
                            )
                            .onTapGesture {
                                handleBucketTap(bucket)
                            }
                        }
                    }
                    .frame(height: 40)
                }
                
                // Time labels
                if timeRange == .today {
                    // Show hour labels for today view
                    HStack {
                        ForEach(hourLabels, id: \.self) { label in
                            Text(label)
                                .font(.system(size: Typography.smallSize))
                                .foregroundColor(Color.brutalistTextMuted)
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    // Show day labels for week/month views
                    HStack {
                        ForEach(dayLabels, id: \.self) { label in
                            Text(label)
                                .font(.system(size: Typography.smallSize))
                                .foregroundColor(Color.brutalistTextMuted)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.md)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
    }
    
    private var hourLabels: [String] {
        guard timeRange == .today else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        var labels: [String] = []
        
        for hour in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: hour, to: startOfDay) {
                let formatter = DateFormatter()
                formatter.dateFormat = "ha"
                let label = formatter.string(from: date)
                labels.append(label)
            }
        }
        
        return labels
    }
    
    private var dayLabels: [String] {
        guard timeRange != .today else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.startOfDay(for: now)
        
        var labels: [String] = []
        let daysToShow = timeRange == .last7Days ? 7 : 30
        
        for dayOffset in 0..<daysToShow {
            if let date = calendar.date(byAdding: .day, value: -(daysToShow - 1 - dayOffset), to: startDate) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                labels.append(formatter.string(from: date))
            }
        }
        
        return labels
    }
    
    private func calculateWidth(for bucket: TimelineBucket, in geometry: GeometryProxy) -> CGFloat {
        let totalWidth = geometry.size.width
        let spacing: CGFloat = 2
        let totalSpacing = CGFloat(buckets.count - 1) * spacing
        return (totalWidth - totalSpacing) / CGFloat(max(buckets.count, 1))
    }
    
    private func isBucketSelected(_ bucket: TimelineBucket) -> Bool {
        guard let selected = selectedTimeRange else { return false }
        return bucket.startTime >= selected.start && bucket.endTime <= selected.end
    }
    
    private func handleBucketTap(_ bucket: TimelineBucket) {
        if let current = selectedTimeRange,
           current.start == bucket.startTime && current.end == bucket.endTime {
            // Deselect if clicking the same bucket
            selectedTimeRange = nil
        } else {
            // Select this bucket
            selectedTimeRange = DateInterval(start: bucket.startTime, end: bucket.endTime)
        }
    }
    
    private func formatSelectedRange(_ range: DateInterval) -> String {
        let formatter = DateFormatter()
        
        if timeRange == .today {
            formatter.dateFormat = "h:mm a"
            let startStr = formatter.string(from: range.start)
            formatter.dateFormat = "h:mm a"
            let endStr = formatter.string(from: range.end)
            return "Selected: \(startStr) - \(endStr)"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            let startStr = formatter.string(from: range.start)
            let endStr = formatter.string(from: range.end)
            return "Selected: \(startStr) - \(endStr)"
        }
    }
}

struct TimelineBucketView: View {
    let bucket: TimelineBucket
    let isSelected: Bool
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 2) {
            // Activity bar
            Rectangle()
                .fill(barColor)
                .frame(width: max(width, 2), height: barHeight)
                .cornerRadius(BorderRadius.sm)
            
            // Event count indicator (if there are events)
            if bucket.eventCount > 0 {
                Text("\(bucket.eventCount)")
                    .font(.system(size: 8))
                    .foregroundColor(Color.brutalistTextMuted)
                    .lineLimit(1)
            }
        }
        .overlay(
            // Selection indicator
            isSelected ?
                RoundedRectangle(cornerRadius: BorderRadius.sm)
                    .stroke(Color.brutalistAccent, lineWidth: 2)
                : nil
        )
        .help(tooltipText)
    }
    
    private var barHeight: CGFloat {
        let maxHeight: CGFloat = 40
        let minHeight: CGFloat = 4
        
        if bucket.eventCount == 0 {
            return minHeight
        }
        
        return minHeight + (maxHeight - minHeight) * CGFloat(bucket.intensity)
    }
    
    private var barColor: Color {
        if isSelected {
            return Color.brutalistAccent
        } else if bucket.eventCount == 0 {
            return Color.brutalistBorder.opacity(0.3)
        } else {
            let opacity = 0.3 + (0.7 * bucket.intensity)
            return Color.brutalistAccent.opacity(opacity)
        }
    }
    
    private var tooltipText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var text = "\(formatter.string(from: bucket.startTime))"
        if bucket.eventCount > 0 {
            text += "\n\(bucket.eventCount) events"
            if let topApp = bucket.topApp {
                text += "\nMost used: \(topApp)"
            }
        } else {
            text += "\nNo activity"
        }
        
        return text
    }
}

