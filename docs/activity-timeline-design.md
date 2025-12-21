# Activity Timeline UI Design & Implementation

## Overview
Add a visual timeline at the top of the Activity tab showing hourly activity patterns, allowing users to quickly navigate and filter events by time period.

## Visual Design (Brutalist Style)

```
┌─────────────────────────────────────────────────────────────┐
│ ACTIVITY LOG                                    [STATUS DOT] │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│ Timeline: Today ▼                                            │
│ ┌───────────────────────────────────────────────────────┐   │
│ │ 8am  9am 10am 11am 12pm  1pm  2pm  3pm  4pm  5pm  6pm │   │
│ │ ███   ██  ████  ████  ██   ██  ███   █   ███  ████   │   │
│ │      ↑ Selected: 9:00-9:59                            │   │
│ └───────────────────────────────────────────────────────┘   │
│                                                               │
│ Stats: 4.2h active • 42 events • 8 apps                      │
│                                                               │
│ Events from 9:00-9:59 AM (12 events)                         │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [App Icon] Switched to Chrome                    9:23 AM│ │
│ │ [App Icon] Switched to Terminal                  9:18 AM│ │
│ │ [App Icon] Switched to Cursor                    9:12 AM│ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Data Structure

### Timeline Bucket
```swift
struct TimelineBucket: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let eventCount: Int
    let activeMinutes: Int  // Minutes with activity
    let topApp: String?     // Most used app in this period
    let intensity: Double   // 0.0-1.0 for visual weight
}
```

### Timeline State
```swift
struct TimelineState {
    var buckets: [TimelineBucket]
    var selectedBucket: TimelineBucket?
    var timeRange: TimeRange  // today, week, month
    var granularity: Granularity  // hour, day, week
}

enum TimeRange {
    case today
    case last7Days
    case last30Days
    case custom(start: Date, end: Date)
}

enum Granularity {
    case hour      // For today view
    case day       // For week view
    case week      // For month view
}
```

## Component Architecture

### 1. TimelineView.swift (NEW)
Main timeline visualization component

```swift
struct ActivityTimelineView: View {
    @Binding var selectedTimeRange: DateInterval?
    let buckets: [TimelineBucket]
    let timeRange: TimeRange
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Time range selector
            HStack {
                Text("Timeline:")
                Picker("", selection: $timeRange) {
                    Text("Today").tag(TimeRange.today)
                    Text("7 Days").tag(TimeRange.last7Days)
                    Text("30 Days").tag(TimeRange.last30Days)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
                
                Spacer()
            }
            
            // Timeline bars
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(buckets) { bucket in
                        TimelineBucketView(
                            bucket: bucket,
                            isSelected: selectedBucket?.id == bucket.id,
                            width: calculateWidth(for: bucket, in: geometry)
                        )
                        .onTapGesture {
                            handleBucketTap(bucket)
                        }
                    }
                }
            }
            .frame(height: 80)
            
            // Time labels
            HStack {
                ForEach(hourLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: Typography.smallSize))
                        .foregroundColor(Color.brutalistTextMuted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.md)
    }
}
```

### 2. TimelineBucketView.swift (NEW)
Individual bar/bucket in timeline

```swift
struct TimelineBucketView: View {
    let bucket: TimelineBucket
    let isSelected: Bool
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 2) {
            // Activity bar
            Rectangle()
                .fill(barColor)
                .frame(width: width, height: barHeight)
                .cornerRadius(BorderRadius.sm)
            
            // Event count indicator (optional)
            if bucket.eventCount > 0 {
                Text("\(bucket.eventCount)")
                    .font(.system(size: 8))
                    .foregroundColor(Color.brutalistTextMuted)
            }
        }
        .overlay(
            // Selection indicator
            isSelected ? 
                RoundedRectangle(cornerRadius: BorderRadius.sm)
                    .stroke(Color.brutalistAccent, lineWidth: 2)
                : nil
        )
    }
    
    private var barHeight: CGFloat {
        let maxHeight: CGFloat = 60
        let minHeight: CGFloat = 4
        return minHeight + (maxHeight - minHeight) * CGFloat(bucket.intensity)
    }
    
    private var barColor: Color {
        if isSelected {
            return Color.brutalistAccent
        } else if bucket.eventCount == 0 {
            return Color.brutalistBorder
        } else {
            return Color.brutalistAccent.opacity(0.3 + 0.7 * bucket.intensity)
        }
    }
}
```

### 3. ActivityStore Timeline Methods (ADD)

```swift
extension ActivityStore {
    func calculateTimelineBuckets(
        for range: TimeRange,
        granularity: Granularity
    ) -> [TimelineBucket] {
        let (startDate, endDate) = getDateRange(for: range)
        let bucketSize = getBucketSize(for: granularity)
        
        var buckets: [TimelineBucket] = []
        var currentStart = startDate
        
        while currentStart < endDate {
            let currentEnd = min(
                Calendar.current.date(byAdding: bucketSize, to: currentStart)!,
                endDate
            )
            
            let eventsInBucket = getEvents(from: currentStart, to: currentEnd)
            let intensity = calculateIntensity(events: eventsInBucket)
            
            let bucket = TimelineBucket(
                startTime: currentStart,
                endTime: currentEnd,
                eventCount: eventsInBucket.count,
                activeMinutes: calculateActiveMinutes(events: eventsInBucket),
                topApp: findTopApp(in: eventsInBucket),
                intensity: intensity
            )
            
            buckets.append(bucket)
            currentStart = currentEnd
        }
        
        return buckets
    }
    
    private func calculateIntensity(events: [ActivityEvent]) -> Double {
        guard !events.isEmpty else { return 0.0 }
        
        // Calculate based on:
        // - Event count
        // - App switches (higher weight)
        // - Time density
        
        let switchCount = events.filter { $0.eventType == .appActivate }.count
        let totalEvents = events.count
        
        // Normalize to 0-1 range
        let maxExpected = 20.0 // Max events per hour we expect
        let intensity = min(1.0, Double(totalEvents) / maxExpected)
        
        // Boost intensity for high switch activity
        let switchBoost = min(0.3, Double(switchCount) / 10.0)
        
        return min(1.0, intensity + switchBoost)
    }
    
    private func getEvents(from: Date, to: Date) -> [ActivityEvent] {
        let startString = Database.dateToString(from)
        let endString = Database.dateToString(to)
        
        let results = db.query(
            "SELECT * FROM activity_log WHERE timestamp >= ? AND timestamp < ? ORDER BY timestamp ASC",
            parameters: [startString, endString]
        )
        
        return results.map { eventFromRow($0) }
    }
}
```

## Integration with ActivityView

### Updated ActivityView.swift

```swift
struct ActivityView: View {
    @ObservedObject var store = ActivityStore.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var selectedTimeRange: DateInterval?
    @State private var timelineRange: TimeRange = .today
    @State private var timelineBuckets: [TimelineBucket] = []
    
    var filteredEvents: [ActivityEvent] {
        guard let timeRange = selectedTimeRange else {
            return store.events
        }
        
        // Filter events to selected time range
        return store.events.filter { event in
            timeRange.contains(event.timestamp)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (existing)
            headerView()
            
            // TIMELINE (NEW)
            ActivityTimelineView(
                selectedTimeRange: $selectedTimeRange,
                buckets: timelineBuckets,
                timeRange: timelineRange
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            
            // Quick Stats (existing, now shows filtered stats)
            if let stats = calculateFilteredStats() {
                statsView(stats)
            }
            
            // Event list (existing, now filtered by timeline selection)
            eventListView()
        }
        .onAppear {
            loadTimelineBuckets()
        }
        .onChange(of: timelineRange) { _ in
            loadTimelineBuckets()
        }
    }
    
    private func loadTimelineBuckets() {
        DispatchQueue.global(qos: .userInitiated).async {
            let buckets = store.calculateTimelineBuckets(
                for: timelineRange,
                granularity: .hour
            )
            
            DispatchQueue.main.async {
                self.timelineBuckets = buckets
            }
        }
    }
}
```

## Enhanced Features

### 1. Hover Tooltips
Show detailed info on hover:
```swift
.help("9:00-10:00 AM\n12 events\n4 apps\nMost used: Chrome")
```

### 2. App-Specific Coloring
Color bars by dominant app:
```swift
private func appColor(for appBundleId: String?) -> Color {
    guard let bundleId = appBundleId else { return .brutalistAccent }
    
    switch bundleId {
    case _ where bundleId.contains("chrome"):
        return Color.blue
    case _ where bundleId.contains("cursor"):
        return Color.purple
    case _ where bundleId.contains("terminal"):
        return Color.green
    default:
        return Color.brutalistAccent
    }
}
```

### 3. Zoom Controls
```swift
HStack {
    Button(action: zoomIn) {
        Image(systemName: "plus.magnifyingglass")
    }
    
    Button(action: zoomOut) {
        Image(systemName: "minus.magnifyingglass")
    }
    
    Button(action: resetZoom) {
        Text("Reset")
    }
}
```

### 4. Export Timeline as Image
```swift
func exportTimelineAsImage() {
    let renderer = ImageRenderer(content: timelineView)
    if let image = renderer.nsImage {
        // Save to file or copy to clipboard
    }
}
```

## Implementation Priority

### Phase 1: Basic Timeline (MVP)
1. ✅ Create TimelineBucket data structure
2. ✅ Add calculateTimelineBuckets to ActivityStore
3. ✅ Create simple TimelineView with hour bars
4. ✅ Add click interaction for filtering
5. ✅ Update event list to show filtered results

### Phase 2: Enhanced Visuals
1. Add intensity-based coloring
2. Add hover tooltips
3. Add app-specific coloring
4. Add smooth animations

### Phase 3: Advanced Features
1. Add week/month views
2. Add zoom controls
3. Add export functionality
4. Add comparison mode (compare two days)

## Performance Considerations

- **Cache buckets**: Recalculate only when data changes
- **Lazy loading**: Only calculate visible time range
- **Background calculation**: Calculate buckets on background queue
- **Debouncing**: Debounce timeline updates when events arrive

## Storage Impact

- No additional database storage needed
- Timeline is calculated from existing activity_log data
- Calculations are fast (< 100ms for 24 hours of data)

## Code Structure

```
SolUnified/Features/Activity/
├── Timeline/
│   ├── TimelineView.swift           (Main timeline component)
│   ├── TimelineBucketView.swift     (Individual bar)
│   ├── TimelineModels.swift         (TimelineBucket, TimeRange, etc.)
│   └── TimelineCalculator.swift     (Bucket calculation logic)
├── ActivityView.swift               (Updated with timeline)
├── ActivityStore.swift              (Add timeline methods)
└── ...existing files
```

## Alternative Designs

### Design A: Minimalist Bars (Recommended)
- Simple vertical bars
- Height = activity intensity
- Width = time bucket
- Brutalist, clean

### Design B: Heatmap Grid
- Calendar-style grid
- Color intensity = activity level
- Good for month view
- More complex to implement

### Design C: Continuous Line Graph
- Smooth line connecting activity points
- Shows trends clearly
- Less brutalist aesthetic
- Good for detailed analysis

## Next Steps

1. Create Timeline subdirectory
2. Implement basic TimelineView
3. Add calculateTimelineBuckets to ActivityStore
4. Integrate into ActivityView
5. Test with real data
6. Iterate on visual design

