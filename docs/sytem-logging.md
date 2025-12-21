# System Activity Logging - Feasibility & Implementation Plan

## Overview

This plan explores adding comprehensive system-wide activity logging to sol-unified, tracking app lifecycle events, app switching, and keyboard activity. This is an exploration phase to understand capabilities, limitations, and best practices.

## Feasibility Analysis

### ✅ What IS Possible on macOS

1. **App Launch/Termination Tracking**

   - Use `NSWorkspace` notifications: `didLaunchApplicationNotification`, `didTerminateApplicationNotification`
   - Get app info: bundle ID, name, PID from `NSRunningApplication`
   - No special permissions required

2. **App Switching (Active Window)**

   - Monitor `NSWorkspace.didActivateApplicationNotification`
   - Track when user switches between apps
   - Can get active app bundle ID and name

3. **Keyboard Activity Logging**

   - Use `CGEventTap` API (Core Graphics)
   - Requires **Accessibility** permission (already needed for hotkeys)
   - Can capture key presses, key releases, and modifiers
   - Can be configured to log characters vs. key codes

### ⚠️ Limitations & Considerations

1. **Keyboard Logging**

   - Requires Accessibility permission (System Settings → Privacy & Security → Accessibility)
   - Privacy-sensitive - user must explicitly grant permission
   - Cannot capture passwords in secure text fields (protected by macOS)
   - High volume: could be 100+ events per second during active typing

2. **App Tracking**

   - Cannot track app contents (what's inside windows)
   - Cannot track which documents/files are opened within apps
   - Only tracks app-level events

3. **Performance**

   - Keyboard logging is CPU-intensive
   - Need efficient batching/writing to avoid blocking UI
   - Database writes should be asynchronous

## Database Strategy for High-Volume Logging

### Current State

- Using SQLite (already in `Database.swift`)
- Stored at `~/Library/Application Support/SolUnified/sol.db`

### SQLite Optimization for High Volume

**Recommendation: Stick with SQLite but optimize**

SQLite can handle millions of rows efficiently with proper configuration:

1. **WAL Mode** (Write-Ahead Logging)

   - Better concurrent reads/writes
   - Faster writes for logging workloads
   - Enable with: `PRAGMA journal_mode=WAL;`

2. **Indexing Strategy**

   - Index on `timestamp` for time-based queries
   - Index on `event_type` for filtering
   - Index on `app_bundle_id` for app-specific queries
   - Avoid over-indexing (each index slows writes)

3. **Batch Inserts**

   - Buffer events in memory (e.g., 100-500 events)
   - Bulk insert every 5-10 seconds
   - Reduces I/O overhead

4. **Data Retention Policy**

   - Option to auto-delete old records (e.g., keep last 30 days)
   - Archive old data to separate tables or files
   - Provide user control over retention period

5. **Estimated Storage**

   - App event: ~200 bytes per record
   - Keyboard event: ~100 bytes per record
   - Assuming 1000 events/hour: ~300KB/hour = ~7MB/day = ~2.5GB/year
   - With compression/archiving: manageable

### Alternative: NoSQL (if volume exceeds SQLite comfort)

Only needed if:

- >10M events/day
- Need distributed storage
- Complex nested queries

Options:

- **SQLite with FTS5** (full-text search extension) - good middle ground
- **Realm** (local NoSQL) - Swift-native, good performance
- **Core Data** - Apple's ORM, but overkill for simple logging

**Recommendation**: Start with optimized SQLite, migrate if needed.

## Implementation Approach

### Phase 1: App Activity Tracking (Low Risk, Low Latency)

**Core Tracking (App-Level Events):**

1. **App Launch** - Track when apps are opened
2. **App Termination** - Track when apps are closed
3. **App Activation** - Track when user switches between apps
4. **Time Spent** - Calculate duration spent in each app (time between activation events)

**Additional Low-Cost Tracking (No Extra Permissions):**

5. **Active Window Title** - Track which window/document is active (using Accessibility API, already have permission)

   - Get window title from active app to see what user is working on
   - Low frequency: only changes when window focus changes
   - Example: "Untitled Document - Pages", "Inbox - Mail", "terminal.pdf"

6. **System Idle Detection** - Track when user stops interacting

   - Use `CGEventSource.secondsSinceLastEventType()` to detect idle time
   - Mark periods of inactivity (>5 min idle)
   - Helps separate active time from idle time

7. **Display Sleep/Wake** - Track when screen goes to sleep/wakes

   - Monitor `NSWorkspace.screensDidSleepNotification` and `screensDidWakeNotification`
   - Helps identify when user is actually using the system vs. away

8. **Screen Lock/Unlock** - Track when screen is locked/unlocked

   - Monitor `NSWorkspace.didWakeNotification` combined with idle detection
   - Helps identify session boundaries

**Files to Create:**

- `SolUnified/Features/Activity/ActivityStore.swift` - ObservableObject managing state and time calculations
- `SolUnified/Features/Activity/ActivityMonitor.swift` - NSWorkspace observer and window title tracking
- `SolUnified/Features/Activity/ActivityView.swift` - UI for viewing logs and statistics
- `SolUnified/Features/Activity/IdleDetector.swift` - System idle monitoring

**Files to Modify:**

- `SolUnified/Shared/Models.swift` - Add `ActivityEvent` and `AppSession` models
- `SolUnified/Core/Database.swift` - Add `activity_log` table with optimized schema
- `SolUnified/Shared/TabNavigator.swift` - Add Activity tab (optional for viewing)
- `SolUnified/Shared/Settings.swift` - Add activity logging toggle

**Key APIs:**

```swift
// Monitor app launches
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didLaunchApplicationNotification,
    object: nil,
    queue: .main
) { notification in
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
    // Log: app.bundleIdentifier, app.localizedName, timestamp
}

// Monitor app termination
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didTerminateApplicationNotification,
    // Similar extraction
)

// Monitor app activation (switching)
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification,
    // Track time spent in previous app, switch to new app
)

// Get active window title (requires Accessibility permission - already have)
func getActiveWindowTitle() -> String? {
    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedApp: AnyObject?
    guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
          let app = focusedApp as! AXUIElement? else { return nil }
    
    var focusedWindow: AnyObject?
    guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
          let window = focusedWindow as! AXUIElement? else { return nil }
    
    var title: AnyObject?
    guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title) == .success,
          let titleString = title as? String else { return nil }
    
    return titleString
}

// System idle detection
func checkIdleTime() -> TimeInterval {
    let eventSource = CGEventSource(stateID: .hidSystemState)
    return eventSource?.secondsSinceLastEventType(.keyboard) ?? 0
}

// Display sleep/wake
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.screensDidSleepNotification,
    // ...
)

NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.screensDidWakeNotification,
    // ...
)
```

**Performance Considerations:**

- **Window Title Tracking**: Poll every 2-3 seconds (not on every event) to avoid overhead
- **Idle Detection**: Check every 30-60 seconds, not continuously
- **Batch Writes**: Buffer events and write every 10-30 seconds (not on every event)
- **Indexing**: Only index timestamp and app_bundle_id for fast queries
- **Storage**: Each event ~150-250 bytes, with ~100-200 events/hour = ~20-50KB/hour = manageable

## Required Permissions

### Already Have:

- Accessibility (for hotkeys) ✅

### May Need:

- Input Monitoring (for keyboard logging) - separate permission in macOS 10.15+
- Already have Accessibility, but macOS may require explicit Input Monitoring

## Database Schema Proposal

```sql
CREATE TABLE activity_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,  -- 'app_launch', 'app_terminate', 'app_activate', 'key_press', 'key_release'
    app_bundle_id TEXT,
    app_name TEXT,
    event_data TEXT,  -- JSON for additional data (key code, modifiers, etc.)
    timestamp TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX idx_activity_timestamp ON activity_log(timestamp DESC);
CREATE INDEX idx_activity_type ON activity_log(event_type);
CREATE INDEX idx_activity_app ON activity_log(app_bundle_id);
```

## Privacy & Ethics

**Critical Considerations:**

1. **User Consent**: Explicit opt-in toggle in Settings
2. **Data Local-Only**: All data stays on device (no cloud sync)
3. **Transparency**: Clear UI showing what's being logged
4. **User Control**: Ability to pause/resume, delete history, export data
5. **Security**: Encrypt database if storing sensitive data

## Next Steps

1. **Start with App Tracking** (Phase 1) - low risk, high value
2. **Test SQLite performance** with realistic data volumes
3. **Add keyboard logging** (Phase 2) only if needed and with explicit user consent
4. **Monitor performance** and optimize database queries
5. **Add retention/archival** policies as data grows

## Questions to Answer

1. What's the primary use case? (productivity analysis, debugging, research?)
2. Do you need full keyboard logging or just activity patterns?
3. How long should data be retained?
4. Should this be opt-in or opt-out?
5. Do you need real-time analytics or just historical logging?