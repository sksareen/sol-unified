# Sol Unified

A native macOS app for unified personal context—clipboard, screenshots, activity tracking, notes, and terminal in one place.

## 🤖 AI Agent Context Access

### Quick Start (For Any Claude Code Instance)

Run this command to understand what I'm currently working on:

```bash
sol-context
```

This gives you my current work session, recent clipboard, and activity summary.

### Available Commands

| Command | Description |
|---------|-------------|
| `sol-context` | Quick summary of current context |
| `sol-context full` | Full JSON context (all data) |
| `sol-context clipboard 10` | Last 10 clipboard items |
| `sol-context clipboard 5 Cursor` | Last 5 clips from Cursor |
| `sol-context activity 4` | Activity from last 4 hours |
| `sol-context contexts 24` | Work sessions from last 24h |
| `sol-context search "README"` | Search across all context |
| `sol-context stats` | Today's productivity stats |

### HTTP API (Real-Time Access)

When Sol Unified is running, you can also query the API:

```bash
curl -s http://localhost:7654/context        # Current context
curl -s http://localhost:7654/clipboard      # Recent clipboard
curl -s http://localhost:7654/activity       # Recent activity
curl -s http://localhost:7654/search?q=TERM  # Search
curl -s http://localhost:7654/stats          # Today's stats
```

### What You Get

- **Active Context**: Current work session type (deep work, creative, communication, etc.)
- **Focus Score**: How focused I am (fewer app switches = higher focus)
- **Recent Clipboard**: What I've copied, with source app and window title
- **Activity Timeline**: App usage patterns
- **Context Transitions**: How I've moved between work modes

### When to Check Context

- Before answering coding questions (understand what I'm working on)
- When I reference "that thing" or assume you know context
- When helping with debugging (see what I've copied recently)
- When planning tasks (understand my work patterns)

---

## File Export (Alternative)

If the CLI isn't available, read these files directly:
- **Full context**: `~/Documents/sol-context/context.json`
- **Quick summary**: `~/Documents/sol-context/context-compact.md`

Updated every 30 seconds while Sol Unified is running.

## Project Structure

```
SolUnified/
├── App/                    # Entry point, AppDelegate
├── Core/                   # Database, hotkeys, window management
├── Features/
│   ├── Activity/           # App tracking, context graph, focus detection
│   ├── AgentContext/       # Context export for AI agents
│   ├── Clipboard/          # Clipboard monitoring with source tracking
│   ├── Screenshots/        # Screenshot capture with metadata
│   ├── Notes/              # Vault and markdown editor
│   ├── Terminal/           # Embedded SwiftTerm
│   └── Tasks/              # Task management
└── Shared/                 # Design system, models, settings
```

## Key Files

- `SolUnified/Features/Activity/ContextGraph.swift` - Context detection and tracking
- `SolUnified/Features/AgentContext/ContextExporter.swift` - AI context export
- `SolUnified/Core/Database.swift` - SQLite database wrapper

## Build & Run

```bash
./run.sh          # Build and run
./package.sh      # Create DMG for distribution
swift build       # Build only
```

## Database Location

`~/Library/Application Support/SolUnified/sol.db`

Key tables: `context_nodes`, `context_edges`, `clipboard_history`, `screenshots`, `activity_log`
