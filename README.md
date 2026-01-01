# Sol Unified

A native macOS productivity app with AI agent integration, terminal emulation, and personal knowledge management.

![Demo](demo.gif)

## Features

### 📋 Tasks
- Unified task management synced with agent_state.json
- Assign tasks to different agents (Mable, Devon, Josh, Gunter, Kevin)
- Filter by status (pending, in_progress, completed, archived)
- Priority levels and project tagging
- Live updates from agent system

### 🤖 Agents
- View status of all active agents (Mable, Devon, Josh, Gunter, Kevin)
- Real-time agent focus and activity tracking
- Message log between agents
- Manual sync and memory refresh controls

### 📚 Vault
- Browse and edit markdown files from ~/Documents
- Folder-based organization with expand/collapse
- Search across all files
- WYSIWYG markdown editor
- Collapsible sidebar (Cmd+B)

### 🧠 Context
- View AI context state
- Recent changes and priorities
- Architecture notes
- Memory tracking of clipboard, screenshots, notes, activity

### 💻 Terminal
- Embedded terminal emulator using SwiftTerm
- Full shell access (zsh/bash)
- Clear and new terminal session controls

### 🎨 Appearance
- Nordic minimalist tab design
- Light and dark mode toggle
- Clean, functional UI
- Customizable window size

---

## Quick Start

### Prerequisites
- macOS 13.0 or later
- Swift 5.9+ (comes with Xcode)

### Installation

#### Option 1: Build from Source

1. **Clone the repository:**
```bash
git clone https://github.com/yourusername/sol-unified.git
cd sol-unified
```

2. **Run the app:**
```bash
./run.sh
```

Or:
```bash
swift run
```

3. **Grant Accessibility permission** when prompted (required for global hotkey)

4. **Press Option + `** (backtick) to show/hide the window

#### Option 2: Build Distributable DMG

To create a distributable DMG:

```bash
./package.sh
```

The DMG will be created at `.build/SolUnified-1.0.dmg`

For detailed distribution instructions, see [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)

## Usage

### Global Hotkey
- **Option + ` (backtick)**: Show/hide the app window

### Keyboard Shortcuts
- **Cmd + 1**: Switch to Tasks tab
- **Cmd + 2**: Switch to Agents tab
- **Cmd + 3**: Switch to Vault tab
- **Cmd + 4**: Switch to Context tab
- **Cmd + 5**: Switch to Terminal tab
- **Cmd + P**: Focus vault search
- **Cmd + B**: Toggle vault sidebar
- **Cmd + ,**: Open Settings
- **Cmd + =**: Increase window size
- **Cmd + -**: Decrease window size
- **Esc**: Close modals/sheets

## Architecture

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI with AppKit bridge
- **Terminal**: SwiftTerm library
- **Database**: SQLite3
- **Hotkey System**: Carbon API
- **Design**: Nordic minimalist aesthetic

## Project Structure

```
sol-unified/
├── SolUnified/
│   ├── App/
│   │   ├── SolUnifiedApp.swift          # Main entry point
│   │   └── AppDelegate.swift            # Window/hotkey management
│   ├── Core/
│   │   ├── WindowManager.swift          # Borderless window + animations
│   │   ├── Database.swift               # SQLite wrapper
│   │   └── HotkeyManager.swift          # Global hotkey registration
│   ├── Features/
│   │   ├── Tasks/                       # Task management
│   │   ├── AgentContext/                # Agent system integration
│   │   ├── Notes/                       # Vault & notes
│   │   ├── Context/                     # AI context viewer
│   │   ├── Terminal/                    # Terminal emulator
│   │   ├── Clipboard/                   # Clipboard manager
│   │   ├── Screenshots/                 # Screenshot organizer
│   │   └── Activity/                    # Activity tracking
│   └── Shared/
│       ├── TabNavigator.swift           # Main tab switcher
│       ├── BrutalistStyles.swift        # Design system
│       ├── Settings.swift               # App settings
│       └── Models.swift                 # Data models
├── Package.swift                        # Swift Package Manager config
├── run.sh                              # Quick run script
└── README.md
```

## Configuration

### Agent System Integration

Sol Unified reads from `~/Documents/agent_state.json` for task and agent synchronization. Example structure:

```json
{
  "active_agents": {
    "mable": {
      "status": "active",
      "current_focus": "Orchestrating agent system",
      "last_active": "2025-12-20T17:00:00-08:00"
    }
  },
  "tasks": {
    "task_001": {
      "id": "task_001",
      "title": "Example task",
      "description": "Task description",
      "assigned_to": "mable",
      "status": "pending",
      "priority": "high",
      "project": "general"
    }
  }
}
```

### Vault Path

By default, the vault browses `~/` (Home). You can modify this in **Settings** (Cmd + ,) under the **Vault** tab.

## Database

SQLite database stored at:
```
~/Library/Application Support/SolUnified/sol.db
```

### Tables
- `notes`: Notes and scratchpad content
- `clipboard_history`: Clipboard items
- `screenshots`: Screenshot metadata
- `activity_logs`: Activity tracking data

## Troubleshooting

### Hotkey not working or Activity Log empty
- Check **Accessibility** permissions: System Settings → Privacy & Security → Accessibility
- Check **Input Monitoring** permissions: System Settings → Privacy & Security → Input Monitoring (Required for Activity Log)
- Add Sol Unified to allowed apps
- Restart the app

### Agent files not found
- Ensure `~/Documents/agent_state.json` exists
- Check file permissions
- View logs in Terminal tab

### Build errors
```bash
swift build
```

If you see errors, make sure you're using Swift 5.9+:
```bash
swift --version
```

## Development

### Building
```bash
swift build
```

### Running
```bash
./run.sh
```

Or:
```bash
swift run
```

### Dependencies
- SwiftTerm (terminal emulation)
- Swift Argument Parser

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Roadmap

### ✅ Phase 1: Core Productivity (Current)
- Task management with agent integration
- Terminal emulator
- Vault for markdown notes
- Context viewer

### 🔄 Phase 2: Enhanced Intelligence
- AI-powered task suggestions
- Context-aware agent routing
- Smart note linking
- Advanced search

### 🚀 Phase 3: Collaboration
- Multi-user agent coordination
- Shared knowledge bases
- Team task management

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Built with inspiration from:
- Raycast (command palette UX)
- Warp (terminal design)
- Obsidian (vault concept)
