//
//  StackedAreaChartView.swift
//  SolUnified
//
//  Stacked area chart for category visualization over time
//

import SwiftUI

struct StackedAreaChartView: View {
    let series: [ChartSeries]
    let height: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Draw stacked areas
                ForEach(Array(series.enumerated()), id: \.element.id) { index, series in
                    StackedAreaShape(
                        dataPoints: series.dataPoints,
                        seriesIndex: index,
                        allSeries: series.dataPoints.map { $0.time },
                        maxValue: maxValue,
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .fill(series.color.opacity(0.6))
                    .overlay(
                        StackedAreaShape(
                            dataPoints: series.dataPoints,
                            seriesIndex: index,
                            allSeries: series.dataPoints.map { $0.time },
                            maxValue: maxValue,
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .stroke(series.color, lineWidth: 1)
                    )
                }
                
                // X-axis labels (hours)
                if !series.isEmpty && !series[0].dataPoints.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(series[0].dataPoints.enumerated()), id: \.offset) { index, point in
                            if index % 4 == 0 || index == series[0].dataPoints.count - 1 {
                                Text(formatHour(point.time))
                                    .font(.system(size: 9))
                                    .foregroundColor(Color.brutalistTextMuted)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 16)
                    .offset(y: geometry.size.height + 4)
                }
            }
        }
        .frame(height: height)
    }
    
    private var maxValue: Double {
        guard !series.isEmpty, !series[0].dataPoints.isEmpty else { return 1 }
        
        var max = 0.0
        let timePoints = series[0].dataPoints.map { $0.time }
        
        for timePoint in timePoints {
            var sum = 0.0
            for series in series {
                if let point = series.dataPoints.first(where: { $0.time == timePoint }) {
                    sum += point.value
                }
            }
            max = Swift.max(max, sum)
        }
        
        return max > 0 ? max : 1
    }
    
    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }
}

struct StackedAreaShape: Shape {
    let dataPoints: [ChartDataPoint]
    let seriesIndex: Int
    let allSeries: [Date]
    let maxValue: Double
    let width: CGFloat
    let height: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !dataPoints.isEmpty else { return path }
        
        let stepX = width / CGFloat(max(dataPoints.count - 1, 1))
        
        // Calculate cumulative values for stacking
        var points: [(x: CGFloat, y: CGFloat)] = []
        
        for (index, point) in dataPoints.enumerated() {
            let x = CGFloat(index) * stepX
            
            // Calculate cumulative value up to this series
            var cumulativeValue = 0.0
            for i in 0...seriesIndex {
                // This is simplified - in a real implementation, we'd need all series data
                // For now, we'll use the point's value directly
                if i == seriesIndex {
                    cumulativeValue += point.value
                }
            }
            
            // For proper stacking, we need to calculate from bottom
            // This is a simplified version - would need access to all series
            let normalizedValue = cumulativeValue / maxValue
            let y = height - (CGFloat(normalizedValue) * height)
            
            points.append((x: x, y: y))
        }
        
        // Create area path
        if let firstPoint = points.first {
            path.move(to: CGPoint(x: firstPoint.x, y: height))
            
            for point in points {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            
            if let lastPoint = points.last {
                path.addLine(to: CGPoint(x: lastPoint.x, y: height))
                path.closeSubpath()
            }
        }
        
        return path
    }
}

// Improved version that properly handles stacking
struct ImprovedStackedAreaChartView: View {
    let series: [ChartSeries]
    let height: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Calculate cumulative values for proper stacking
                let stackedData = calculateStackedData()
                
                // Draw stacked areas bottom to top
                ForEach(Array(stackedData.enumerated()), id: \.element.id) { index, stackedSeries in
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(max(stackedSeries.points.count - 1, 1))
                        
                        // Start from bottom-left
                        if let firstPoint = stackedSeries.points.first {
                            path.move(to: CGPoint(x: CGFloat(firstPoint.index) * stepX, y: geometry.size.height))
                        }
                        
                        // Draw top line
                        for point in stackedSeries.points {
                            let x = CGFloat(point.index) * stepX
                            let y = geometry.size.height - (CGFloat(point.cumulativeValue / maxTotalValue) * geometry.size.height)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        // Close path to bottom
                        if let lastPoint = stackedSeries.points.last {
                            let x = CGFloat(lastPoint.index) * stepX
                            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                            path.closeSubpath()
                        }
                    }
                    .fill(stackedSeries.color.opacity(0.6))
                    .overlay(
                        Path { path in
                            let stepX = geometry.size.width / CGFloat(max(stackedSeries.points.count - 1, 1))
                            if let firstPoint = stackedSeries.points.first {
                                path.move(to: CGPoint(x: CGFloat(firstPoint.index) * stepX, y: geometry.size.height - (CGFloat(firstPoint.cumulativeValue / maxTotalValue) * geometry.size.height)))
                            }
                            for point in stackedSeries.points {
                                let x = CGFloat(point.index) * stepX
                                let y = geometry.size.height - (CGFloat(point.cumulativeValue / maxTotalValue) * geometry.size.height)
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(stackedSeries.color, lineWidth: 1)
                    )
                }
                
                // Legend
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(series.prefix(5)) { s in
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(s.color)
                                .frame(width: 12, height: 12)
                            Text(s.category)
                                .font(.system(size: 10))
                                .foregroundColor(Color.brutalistTextSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(8)
                .background(Color.brutalistBgSecondary.opacity(0.9))
                .cornerRadius(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                
                // X-axis labels
                if !series.isEmpty && !series[0].dataPoints.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(series[0].dataPoints.enumerated()), id: \.offset) { index, point in
                            if index % 4 == 0 || index == series[0].dataPoints.count - 1 {
                                Text(formatHour(point.time))
                                    .font(.system(size: 9))
                                    .foregroundColor(Color.brutalistTextMuted)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 16)
                    .offset(y: geometry.size.height + 4)
                }
            }
        }
        .frame(height: height)
    }
    
    private var maxTotalValue: Double {
        guard !series.isEmpty, !series[0].dataPoints.isEmpty else { return 1 }
        
        var max = 0.0
        let timePoints = series[0].dataPoints.map { $0.time }
        
        for timePoint in timePoints {
            var sum = 0.0
            for series in series {
                if let point = series.dataPoints.first(where: { $0.time == timePoint }) {
                    sum += point.value
                }
            }
            max = Swift.max(max, sum)
        }
        
        return max > 0 ? max : 1
    }
    
    private struct StackedPoint {
        let index: Int
        let value: Double
        let cumulativeValue: Double
    }
    
    private struct StackedSeriesData {
        let id: String
        let category: String
        let color: Color
        let points: [StackedPoint]
    }
    
    private func calculateStackedData() -> [StackedSeriesData] {
        guard !series.isEmpty, !series[0].dataPoints.isEmpty else { return [] }
        
        let timePoints = series[0].dataPoints.map { $0.time }
        var stackedData: [StackedSeriesData] = []
        
        for (seriesIndex, s) in series.enumerated() {
            var points: [StackedPoint] = []
            
            for (index, timePoint) in timePoints.enumerated() {
                let value = s.dataPoints.first(where: { $0.time == timePoint })?.value ?? 0
                
                // Calculate cumulative value (sum of all previous series + this one)
                var cumulative = 0.0
                for prevIndex in 0...seriesIndex {
                    if prevIndex < series.count {
                        let prevValue = series[prevIndex].dataPoints.first(where: { $0.time == timePoint })?.value ?? 0
                        cumulative += prevValue
                    }
                }
                
                points.append(StackedPoint(index: index, value: value, cumulativeValue: cumulative))
            }
            
            stackedData.append(StackedSeriesData(
                id: s.id,
                category: s.category,
                color: s.color,
                points: points
            ))
        }
        
        return stackedData
    }
    
    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }
}


