# Sol Unified

A native macOS app for unified personal context—clipboard, screenshots, activity tracking, notes, and terminal in one place. Built for vibe coders who want their AI agents to actually know what they're working on.

![Demo](demo.gif)

## Why Sol Unified?

The fundamental bottleneck in personal productivity isn't computation—it's **context**. 

Every time you switch apps, your brain has to reconstruct what you were doing. Every time you paste something into ChatGPT, you lose the surrounding context. Every time you search for "that screenshot from yesterday," you're paying a tax on your attention.

Sol Unified solves this by creating a **persistent, local context layer** that captures your work automatically:
- What you copied → Clipboard history
- What you saw → Screenshot archive with AI tagging
- What you did → Activity log of apps and windows
- What you wrote → Markdown vault
- What you ran → Embedded terminal

Press `Option + \`` and everything is right there. No more app switching. No more copy-paste archaeology.

---

## Features

### 📋 Clipboard History
- Automatic capture of text and images
- Searchable history
- Never lose what you copied

### 📸 Screenshots
- Organized screenshot archive
- Local AI tagging (coming soon)
- Quick search and retrieval

### ⏱️ Activity Tracking
- Log of app usage and window titles
- Know where your time went
- Data stays local—your privacy, your data

### 📚 Vault
- Browse and edit markdown files
- Folder-based organization
- WYSIWYG markdown editor
- Search across all files
- Collapsible sidebar (Cmd+B)

### 💻 Terminal
- Embedded terminal emulator (SwiftTerm)
- Full shell access (zsh/bash)
- Right alongside your context

### 📝 Tasks
- Simple task management
- Syncs with `agent_state.json` for AI agent integration
- Filter by status and priority

### 🎨 Design
- Brutalist, information-dense UI
- Light and dark mode
- Global hotkey access (`Option + \``)
- Customizable window size

---

## Quick Start

### Prerequisites
- macOS 13.0 or later
- Swift 5.9+ (comes with Xcode)

### Installation

```bash
git clone https://github.com/yourusername/sol-unified.git
cd sol-unified
./run.sh
```

1. **Grant Accessibility permission** when prompted (required for global hotkey and activity tracking)
2. **Press `Option + \``** to show/hide the window

That's it.

### Build a DMG

```bash
./package.sh
```

Creates `SolUnified-1.0.dmg` for distribution.

---

## Usage

### Global Hotkey
- **Option + \` (backtick)**: Show/hide the app window

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `Cmd + 1-5` | Switch tabs |
| `Cmd + P` | Focus vault search |
| `Cmd + B` | Toggle vault sidebar |
| `Cmd + ,` | Open Settings |
| `Cmd + =/-` | Resize window |
| `Esc` | Close modals |

---

## How It Works

Sol Unified creates a **shared state** architecture. Instead of every app being an island, it maintains a persistent context layer that any tool—including AI agents—can read.

### Data Storage

```
~/Library/Application Support/SolUnified/sol.db
```

Tables:
- `clipboard_history` — Text and images you've copied
- `screenshots` — Screenshot metadata and paths
- `activity_logs` — App usage and window tracking
- `notes` — Scratchpad and vault content

### Agent Integration (Optional)

If you're building AI agents, Sol Unified can sync with `agent_state.json`:

```json
{
  "tasks": {
    "task_001": {
      "title": "Example task",
      "status": "pending",
      "priority": "high"
    }
  }
}
```

Place this at `~/Documents/agent_state.json` and Sol Unified will read/write to it.

---

## Roadmap

### ✅ Phase 1: Core Context (Current)
- [x] Clipboard history
- [x] Screenshot organization
- [x] Activity tracking
- [x] Markdown vault
- [x] Embedded terminal
- [x] Global hotkey access
- [x] Task management

### 🔄 Phase 2: Enhanced Context
- [ ] **Email capture** — Ingest and search email context
- [ ] **Context graph** — Visualize relationships between your data
- [ ] **Smart search** — AI-powered search across all context types
- [ ] **Browser integration** — Capture tabs and reading history

### 🚀 Phase 3: Intelligence Layer
- [ ] **Agent interface** — Built-in chat with context-aware AI
- [ ] **Social network tracking** — Track relationships and interactions
- [ ] **Automated tagging** — AI classification of all captured data
- [ ] **Workflow triggers** — Actions based on context patterns

---

## Architecture

```
sol-unified/
├── SolUnified/
│   ├── App/                    # Entry point, window management
│   ├── Core/                   # Database, hotkeys, window manager
│   ├── Features/
│   │   ├── Clipboard/          # Clipboard monitoring
│   │   ├── Screenshots/        # Screenshot organization
│   │   ├── Activity/           # App/window tracking
│   │   ├── Notes/              # Vault and markdown editor
│   │   ├── Terminal/           # SwiftTerm integration
│   │   ├── Tasks/              # Task management
│   │   └── Context/            # Context viewer
│   └── Shared/                 # Design system, models, settings
├── Package.swift
└── run.sh
```

**Tech Stack:**
- Swift 5.9+ / SwiftUI
- SQLite3 for local storage
- SwiftTerm for terminal
- Carbon API for global hotkeys

---

## Troubleshooting

### Hotkey not working?
- System Settings → Privacy & Security → Accessibility → Add Sol Unified

### Activity log empty?
- System Settings → Privacy & Security → Input Monitoring → Add Sol Unified

### Build errors?
```bash
swift --version  # Need 5.9+
swift build
```

---

## Contributing

Contributions welcome! This is a personal project, but if you find it useful:

1. Fork the repo
2. Create a feature branch
3. Submit a PR

---

## License

MIT License - see [LICENSE](LICENSE)

---

## Credits

Built with inspiration from:
- [Raycast](https://raycast.com) — Command palette UX
- [Warp](https://warp.dev) — Terminal design
- [Obsidian](https://obsidian.md) — Vault concept

---

*This is a personal hobby project. Not affiliated with an employer.*
