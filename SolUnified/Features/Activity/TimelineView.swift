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
        VStack(spacing: 4) {
            // Compact time range selector
            HStack {
                Picker("", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 120, height: 20)
                
                Spacer()
            }
            
            if buckets.isEmpty {
                // Empty state
                Text("No activity data")
                    .font(.system(size: Typography.smallSize))
                    .foregroundColor(Color.brutalistTextMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
            } else {
                // Timeline bars only (no labels)
                GeometryReader { geometry in
                    HStack(spacing: 1) {
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
                    .frame(height: 20)
                }
                .frame(height: 20)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
    }
    
    private func calculateWidth(for bucket: TimelineBucket, in geometry: GeometryProxy) -> CGFloat {
        let totalWidth = geometry.size.width
        let spacing: CGFloat = 1
        let totalSpacing = CGFloat(buckets.count - 1) * spacing
        return (totalWidth - totalSpacing) / CGFloat(max(buckets.count, 1))
    }
    
    private func formatSelectedRange(_ range: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let startStr = formatter.string(from: range.start)
        let endStr = formatter.string(from: range.end)
        return "\(startStr) - \(endStr)"
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
}

struct TimelineBucketView: View {
    let bucket: TimelineBucket
    let isSelected: Bool
    let width: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(barColor)
            .frame(width: max(width, 2), height: barHeight)
            .cornerRadius(2)
            .overlay(
                // Selection indicator
                isSelected ?
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.brutalistAccent, lineWidth: 1.5)
                    : nil
            )
            .help(tooltipText)
    }
    
    private var barHeight: CGFloat {
        let maxHeight: CGFloat = 18
        let minHeight: CGFloat = 2
        
        if bucket.eventCount == 0 {
            return minHeight
        }
        
        return minHeight + (maxHeight - minHeight) * CGFloat(bucket.intensity)
    }
    
    private var barColor: Color {
        if isSelected {
            return Color.brutalistAccent
        } else if bucket.eventCount == 0 {
            return Color.brutalistBorder.opacity(0.2)
        } else {
            let opacity = 0.4 + (0.6 * bucket.intensity)
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
                text += "\n\(topApp)"
            }
        }
        
        return text
    }
}

