# Sol Unified

A native macOS app combining notes, clipboard manager, and screenshot organizer with global hotkey access.

![Demo](demo.gif)

## Features

### 📝 Notes
- **Scratchpad**: Quick global note, auto-saves as you type
- Markdown support with edit/preview toggle
- Monospaced font for editing, rendered view for preview
- Supports headings, bold, italic, code, links, lists, quotes, strikethrough

### 📋 Clipboard Manager
- Automatically captures clipboard history (last 100 items)
- Supports text, images, and files
- Image thumbnails in history for visual identification
- Search through history
- Click to copy back to clipboard
- Deduplication using content hashing

### 📸 Screenshot Organizer
- Full-featured web app embedded via WebView
- Table and grid view options
- Favorites system and advanced search
- AI-powered analysis (requires OpenAI API key)
- Batch operations and tag filtering
- Statistics dashboard with detailed metrics

### 🎨 Appearance
- Light and dark mode toggle in Settings
- Brutalist design aesthetic - minimal, functional, high-contrast
- Customizable window size

**Note**: Screenshots work without an API key - you just won't get AI-generated descriptions and tags.

---

## New Features

### October 2025

**Oct 31 - Markdown Support**: Scratchpad now includes markdown formatting with edit/preview mode toggle. Write in markdown syntax and preview rendered output with proper headings, bold, italic, code blocks, links, and more.

**Oct 31 - Image Thumbnails in Clipboard**: Clipboard history now displays actual 60x60px thumbnails of copied images instead of just icons, making it easier to visually identify and find specific images.

**Oct 31 - Dark Mode**: Added system-wide dark mode toggle in Settings (Cmd+,) with instant UI updates. Choose between light and dark themes with carefully designed color palettes for both modes.

**Oct 31 - Screenshot Web App Integration**: Screenshots tab now embeds the full-featured web app via WebView, providing instant access to table view, favorites, advanced search, batch operations, and all web app features without rebuilding native UI.

**Oct 31 - Tab Cycling**: Added Tab key support to cycle through tabs (Notes → Clipboard → Screenshots → Notes) for faster keyboard-only navigation.

**Oct 31 - Customizable Window Size**: Settings now include width and height sliders (600-1400px width, 400-1000px height) to customize the app window to your preferred dimensions.

---

## Quick Start

### Prerequisites
- macOS 13.0 or later
- Swift 5.9+ (comes with Xcode)

### Installation

#### Option 1: Download DMG (Recommended for End Users)

1. **Download** the latest DMG from releases
2. **Open** the DMG file
3. **Drag** Sol Unified to Applications
4. **Launch** from Applications folder
5. **Grant Accessibility permission** when prompted
6. **Press Option + `** (backtick) to show/hide the window

#### Option 2: Build from Source

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

#### Option 3: Build Distributable DMG

To create a distributable DMG:

```bash
./package.sh
```

The DMG will be created at `.build/SolUnified-1.0.dmg`

For detailed distribution instructions, see [DISTRIBUTION.md](DISTRIBUTION.md)

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

## Roadmap

### ✅ Phase 1: Core Content Capture (Current)
- **Mac app** consolidating clipboard, screenshots, and quick notes
- Global hotkey access for instant capture
- Native file scanning and organization
- Basic search and filtering

### 🔄 Phase 2: Intelligent Analysis & Tagging
- Enhanced screenshot analysis with AI-powered descriptions
- Automatic tagging and categorization
- Content extraction from images (OCR)
- Search across all captured content (text, images, notes)

### 🚀 Phase 3: Universal Content Capture
- Expand beyond screenshots and clipboard to capture:
  - Web content (articles, code snippets)
  - Documents and PDFs
  - Audio/video transcripts
  - Browser history and bookmarks
- Unified search across all content types
- Smart content relationships and linking

### 🎯 Phase 4: Personal AI Training
- Aggregate all captured content into a knowledge base
- Provide context-aware suggestions and insights
- Enable users to train custom models on their own data
- Private, local-first AI training capabilities
- Export structured data for model fine-tuning

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Built with inspiration from:
- Raycast (command palette UX)
- Alfred (global hotkey reliability)
- Apple Notes (notes list UI)
