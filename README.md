# Sol Unified

A native macOS app combining notes, clipboard manager, and screenshot organizer with global hotkey access.

## Features

### 📝 Notes
- **Scratchpad**: Quick global note, auto-saves as you type
- Persistent notes with markdown support

### 📋 Clipboard Manager
- Automatically captures clipboard history (last 100 items)
- Supports text, images, and files
- Search through history
- Click to copy back to clipboard
- Deduplication using content hashing

### 📸 Screenshot Organizer
- Native file scanning directly from your folder
- Beautiful grid view with thumbnails
- Search by filename
- Statistics dashboard
- Optional AI-powered analysis (requires OpenAI API key)

**Note**: Screenshots work without an API key - you just won't get AI-generated descriptions and tags.

## Quick Start

### Prerequisites
- macOS 13.0 or later
- Swift 5.9+ (comes with Xcode)

### Installation

1. **Clone the repository:**
```bash
git clone <repository-url>
cd sol-unified
```

2. **Set OpenAI API Key (Optional):**
```bash
export OPENAI_API_KEY='your-api-key-here'
```

Or add to your shell profile:
```bash
echo 'export OPENAI_API_KEY="your-api-key-here"' >> ~/.zshrc
source ~/.zshrc
```

3. **Run the app:**
```bash
./run.sh
```

Or:
```bash
swift run
```

4. **Grant Accessibility permission** when prompted (required for global hotkey)

5. **Press Option + `** (backtick) to show/hide the window

## Usage

### Global Hotkey
- **Option + ` (backtick)**: Show/hide the app window

### Keyboard Shortcuts
- **Cmd + 1**: Switch to Notes tab
- **Cmd + 2**: Switch to Clipboard tab
- **Cmd + 3**: Switch to Screenshots tab
- **Cmd + ,**: Open Settings
- **Tab**: Cycle through tabs
- **Esc**: Close modals/sheets

### Notes
1. Open app with hotkey (Option + `)
2. Default view is Scratchpad - just start typing
3. Auto-saves 1 second after you stop typing
4. Supports markdown formatting (toggle Edit/Preview)

### Clipboard
1. Clipboard monitoring starts automatically
2. Copy anything (text, image, file)
3. Open Clipboard tab to see history
4. Click any item to copy it back to clipboard
5. Search through history

### Screenshots
1. Open Settings (Cmd + ,)
2. Click "Select..." next to Screenshot Folder
3. Choose your screenshots directory
4. Go to Screenshots tab (Cmd + 3)
5. Click "Scan" to index screenshots from your folder
6. Screenshots will appear in a grid
7. Click any screenshot to view details
8. Click "Stats" to see collection statistics

## Architecture

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Database**: SQLite3
- **Hotkey System**: Carbon API (reliable global hotkeys)
- **Design**: Brutalist aesthetic - minimal, functional, high-contrast

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
│   │   └── HotkeyManager.swift          # Carbon hotkey registration
│   ├── Features/
│   │   ├── Notes/                       # Notes feature
│   │   ├── Clipboard/                   # Clipboard manager
│   │   └── Screenshots/                 # Screenshot organizer
│   └── Shared/
│       ├── TabNavigator.swift           # Main tab switcher
│       ├── BrutalistStyles.swift        # Design system
│       └── Models.swift                 # Data models
├── Package.swift                        # Swift Package Manager config
├── run.sh                              # Quick run script
└── README.md
```

## Configuration

### Screenshot Folder
- Open Settings (Cmd + ,)
- Click "Select..." next to Screenshot Folder
- Choose your directory

### OpenAI API Key (Optional)
- Set `OPENAI_API_KEY` environment variable
- Required for AI-powered screenshot analysis
- Without it, screenshots will still work but won't have AI descriptions/tags

## Database

SQLite database stored at:
```
~/Library/Application Support/SolUnified/sol.db
```

### Tables
- `notes`: Notes and scratchpad content
- `clipboard_history`: Clipboard items
- `screenshots`: Screenshot metadata

## Troubleshooting

### Hotkey not working
- Check Accessibility permissions: System Settings → Privacy & Security → Accessibility
- Add Sol Unified to allowed apps
- Restart the app

### Screenshots not showing
- Check the folder path in Settings
- Make sure the folder contains image files (.png, .jpg, .jpeg, .gif, .webp, .bmp)
- Click "Scan" button and check console output for errors
- Verify folder permissions

### Clipboard not monitoring
- Check permissions in System Settings
- Restart the app
- Check Console.app for errors

### Build errors
```bash
cd sol-unified
swift build
```

If you see errors, make sure you're using Swift 5.9+:
```bash
swift --version
```

## Development

### Building
```bash
cd sol-unified
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

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Built with inspiration from:
- Raycast (command palette UX)
- Alfred (global hotkey reliability)
- Apple Notes (notes list UI)
