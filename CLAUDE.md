# Sol Unified v2.0

**"The Prosthetic for Executive Function"**

A native macOS orchestration layer that bridges the gap between human intent and AI execution. Sol v2 solves the "Context Leaking" problem by automating state management and gently correcting focus drift.

## Core Features

### 1. The HUD (Opt + P)
A minimalist, dark-mode input bar for setting your current **Objective**.
- Type your intent (e.g., "Fix the Auth Bug")
- Sets the global "Current Objective" that guides all other features
- Shows current objective and session duration

### 2. The Context Engine (Opt + C)
One-button context capture for AI injection.
- Aggregates: Active window, selected text, OCR'd screenshots, clipboard history, current objective
- Outputs: Formatted Markdown optimized for LLM context windows
- Copies directly to clipboard for pasting into Claude/GPT

### 3. The Drift Monitor
Passive monitor that gently nudges you back on task.
- Detects when you switch to distraction apps (Twitter, Reddit, etc.)
- After 30 seconds: Screen dims with glowing text: *"We were working on [Objective]. Resume?"*
- Press **Enter** to return to work, **Esc** to take a break

### 4. Infinite Memory (Background)
Silent recording for the Context Engine:
- Clipboard history with source app tracking
- Screenshot monitoring with provenance
- Activity/app usage logging

## HTTP API (Port 7654)

When Sol is running, query context programmatically:

```bash
curl http://localhost:7654/context      # Current context + objective
curl http://localhost:7654/clipboard    # Recent clipboard
curl http://localhost:7654/activity     # App usage
curl http://localhost:7654/objective    # Current objective
curl http://localhost:7654/stats        # Today's stats
```

## Project Structure

```
SolUnified/
├── App/
│   ├── AppDelegate.swift          # Lifecycle, hotkeys, menu bar
│   └── SolUnifiedApp.swift        # SwiftUI entry
├── Core/
│   ├── Database.swift             # SQLite
│   ├── HotkeyManager.swift        # Global hotkeys (Opt+P, Opt+C)
│   └── WindowManager.swift        # Settings panel
├── Features/
│   ├── Focus/
│   │   ├── ObjectiveStore.swift   # Current objective state
│   │   ├── HUDView.swift          # Opt+P input bar
│   │   ├── ContextEngine.swift    # Opt+C aggregation
│   │   └── DriftMonitor.swift     # Distraction detection + overlay
│   ├── Activity/                  # App monitoring, context graph
│   ├── AgentContext/              # API server, context export
│   ├── Clipboard/                 # Clipboard monitoring
│   └── Screenshots/               # Screenshot capture
└── Shared/
    ├── BrutalistStyles.swift      # UI theming
    ├── Models.swift               # Data models
    ├── Settings.swift             # Preferences
    └── TabNavigator.swift         # Settings panel UI
```

## Build & Run

```bash
./build.sh        # Build .app bundle
./run.sh          # Build and run
./package.sh      # Create DMG
```

## Database

Location: `~/Library/Application Support/SolUnified/sol.db`

Key tables:
- `objectives` - Work session objectives
- `clipboard_history` - Clipboard with source metadata
- `screenshots` - Screenshot metadata
- `activity_log` - App/window events
- `context_nodes` - Work context sessions

## What Was Cut in v2

Removed to focus on core value:
- Terminal emulator (use iTerm/Ghostty)
- Notes/Vault (use Obsidian/Notion)
- People CRM
- Analytics dashboard
- Agent chat UI

The app is now invisible until summoned. Background services feed the Context Engine.

## Philosophy

- **Subtraction > Addition**: Integrate, don't duplicate
- **Invisible UI**: Only visible when summoned or correcting
- **Context is King**: Value is in continuity of data passed to AI
