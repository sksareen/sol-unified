# Sol Unified

A native macOS app combining notes, clipboard manager, and AI-powered screenshot organizer with global hotkey access.

## Features

### 📝 Notes
- **Scratchpad**: Quick global note, auto-saves as you type
- **Notes List**: Persistent notes with titles, search, CRUD operations
- Switch between modes with one click

### 📋 Clipboard Manager
- Automatically captures clipboard history (last 100 items)
- Supports text, images, and files
- Search through history
- Click to copy back to clipboard
- Deduplication using content hashing

### 📸 Screenshot Organizer
- AI-powered analysis using OpenAI GPT-4o-mini Vision
- Automatic tagging and description generation
- Text extraction from screenshots
- Search by description, tags, or extracted text
- Beautiful grid view with thumbnails
- Statistics dashboard

## Architecture

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Database**: SQLite3
- **Hotkey System**: Carbon API (reliable global hotkeys)
- **AI Backend**: Python Flask (embedded subprocess)
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
│   ├── Shared/
│   │   ├── TabNavigator.swift           # Main tab switcher
│   │   ├── BrutalistStyles.swift        # Design system
│   │   └── Models.swift                 # Data models
│   └── Resources/
├── Info.plist
├── SolUnified.entitlements
└── README.md
```

## Setup Instructions

### Method 1: Create Xcode Project (Recommended)

1. Open Xcode
2. Create New Project → macOS → App
3. Product Name: `SolUnified`
4. Organization Identifier: `com.yourname.solunified`
5. Interface: SwiftUI
6. Language: Swift
7. Save in: `/Users/savarsareen/coding/hanu/components/hanuPARTS/sol-unified/`

8. **Add existing files**:
   - File → Add Files to "SolUnified"
   - Select the `SolUnified/` folder with all Swift files
   - Ensure "Copy items if needed" is UNCHECKED (files are already in place)
   - Create groups: ✓
   - Add to targets: SolUnified ✓

9. **Configure Project Settings**:
   - Select project in navigator
   - General tab:
     - Deployment Target: macOS 13.0+
   - Signing & Capabilities:
     - Disable App Sandbox (or configure entitlements)
     - Add capability: Network (Client/Server)
   - Info tab:
     - Set custom Info.plist location: `Info.plist`
   - Build Settings:
     - Search "Other Linker Flags"
     - Add: `-framework Carbon`
     - Search "Swift Language Version"
     - Set to: Swift 5

10. **Link SQLite**:
    - Select target → Build Phases → Link Binary With Libraries
    - Add `libsqlite3.tbd`

11. **Set Entitlements**:
    - Signing & Capabilities → Add `SolUnified.entitlements`

### Method 2: Command Line (Swift Package)

```bash
cd /Users/savarsareen/coding/hanu/components/hanuPARTS/sol-unified

# Build with swiftc (requires manual linking)
swiftc -framework Cocoa -framework Carbon -lsqlite3 \
    SolUnified/**/*.swift \
    -o SolUnified
```

## Dependencies

### Built-in Frameworks
- SwiftUI (UI framework)
- AppKit (Window management)
- Carbon (Global hotkeys)
- SQLite3 (Database)
- CryptoKit (Content hashing)

### Python Backend (for Screenshots)
The screenshot analyzer uses the existing Python backend:

**Location**: `~/Library/Mobile Documents/com~apple~CloudDocs/Obsidian Vault/brutalist-apps-ecosystem/screenshot-organizer/backend/`

**Requirements**:
```bash
cd ~/Library/Mobile\ Documents/com~apple~CloudDocs/Obsidian\ Vault/brutalist-apps-ecosystem/screenshot-organizer/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Environment**:
```bash
export OPENAI_API_KEY='your-api-key-here'
```

The app will automatically start the Python backend as a subprocess when needed.

## Usage

### Global Hotkey
- **Option + ` (backtick)**: Show/hide the app window

### Keyboard Shortcuts
- **Cmd + 1**: Switch to Notes tab
- **Cmd + 2**: Switch to Clipboard tab
- **Cmd + 3**: Switch to Screenshots tab
- **Cmd + N**: New note (in Notes List view)
- **Esc**: Close modals/sheets

### Notes
1. Open app with hotkey
2. Default view is Scratchpad - just start typing
3. Auto-saves 1 second after you stop typing
4. Click "LIST" to see all your notes
5. Click "NEW NOTE" to create a persistent note

### Clipboard
1. Clipboard monitoring starts automatically
2. Copy anything (text, image, file)
3. Open Clipboard tab to see history
4. Click any item to copy it back to clipboard
5. Search through history
6. Click "CLEAR ALL" to reset

### Screenshots
1. First launch: Backend starts automatically (may take a few seconds)
2. Click "SCAN FOLDER" to analyze screenshots
3. AI will generate descriptions, tags, and extract text
4. Search by any metadata
5. Click screenshot for detail view
6. Click "STATS" to see collection statistics

## Configuration

### Change Screenshots Directory
Edit `ScreenshotAnalyzer.swift`:
```swift
backendPath = "/path/to/your/screenshots"
```

Or modify the Python backend's `main.py`:
```python
SCREENSHOTS_DIR = os.path.expanduser("~/Pictures/Pics/Screenshots")
```

### Change Hotkey
Edit `AppDelegate.swift`:
```swift
// Change from Option+Backtick to another key
let keyCode = UInt32(kVK_ANSI_Grave) // Change this
let modifiers = UInt32(optionKey)     // Or this
```

### Clipboard History Limit
Edit `ClipboardStore.swift`:
```swift
private let maxItems = 100  // Change to your preference
```

## Database

SQLite database stored at:
```
~/Library/Application Support/SolUnified/sol.db
```

### Tables
- `notes`: Notes and scratchpad content
- `clipboard_history`: Clipboard items
- `screenshots`: Screenshot metadata and AI analysis

To inspect database:
```bash
sqlite3 ~/Library/Application\ Support/SolUnified/sol.db
.tables
.schema notes
```

## Performance

### Target Metrics
- Launch time: <0.2s from hotkey to visible ✓
- Memory usage: <50MB idle
- App size: <10MB compiled
- Animation smoothness: 60fps

### Optimizations
- Lazy loading for screenshots grid
- Debounced autosave (1s delay)
- Clipboard polling at 0.5s intervals
- SQLite indexes on frequently queried columns

## Troubleshooting

### Hotkey not working
- Check Accessibility permissions: System Settings → Privacy & Security → Accessibility
- Add SolUnified to allowed apps
- Try a different hotkey combination

### Clipboard not monitoring
- Check permissions in System Settings
- Restart the app
- Check Console.app for errors

### Screenshots not analyzing
- Ensure OPENAI_API_KEY is set in environment
- Check Python backend is running: `curl http://localhost:5001/api/stats`
- Verify screenshots directory path is correct
- Check backend logs in terminal

### Database errors
- Check file permissions: `ls -la ~/Library/Application\ Support/SolUnified/`
- Delete database to reset: `rm ~/Library/Application\ Support/SolUnified/sol.db`
- Restart app (will recreate database)

### Window not appearing
- Press hotkey twice
- Check Console.app for errors
- Verify window frame is within screen bounds

## Development

### Building
1. Open `SolUnified.xcodeproj` in Xcode
2. Select "My Mac" as target
3. Product → Build (Cmd+B)
4. Product → Run (Cmd+R)

### Debugging
- Use Xcode debugger
- Check Console.app for NSLog output
- Enable debug logging in Database.swift and other components

### Testing
- All features should work without crashes
- Test hotkey repeatedly
- Test clipboard with various content types
- Test screenshot scanning with real data
- Check animations for smoothness

## Architecture Details

### Window Management
- Uses custom `BorderlessWindow` class (NSWindow subclass)
- Overrides `canBecomeKey` and `canBecomeMain` for keyboard input
- Slide animations: 210ms in (easeOut), 150ms out (easeIn)
- Window floats above all other windows

### Hotkey System
- Carbon API `RegisterEventHotKey` (20+ years old but most reliable)
- Event handler registered to application event target
- Callback triggers window toggle
- Automatically unregisters on app termination

### Data Flow
```
User Input → View → ObservableObject Store → Database → SQLite
                                ↓
                          Published Properties
                                ↓
                         View Updates (SwiftUI)
```

## Future Enhancements

- [ ] Preferences window (hotkey customization, paths, limits)
- [ ] Menu bar icon with quick access
- [ ] Export data (JSON, CSV)
- [ ] iCloud sync for notes
- [ ] Note templates
- [ ] Rich text editing
- [ ] Note linking/backlinks
- [ ] Screenshot annotations
- [ ] Custom AI prompts for analysis
- [ ] Duplicate screenshot detection
- [ ] File system watcher for auto-scan
- [ ] Multiple screenshot folders
- [ ] Tag management UI
- [ ] Keyboard-only navigation

## License

MIT

## Credits

Built with inspiration from:
- Raycast (command palette UX)
- Alfred (global hotkey reliability)
- Apple Notes (notes list UI)
- brutalist-apps-ecosystem (design aesthetic)

## Technical References

- Carbon Framework: [Apple Documentation](https://developer.apple.com/documentation/carbon)
- SwiftUI: [Apple Documentation](https://developer.apple.com/documentation/swiftui)
- SQLite: [SQLite Documentation](https://www.sqlite.org/docs.html)
- OpenAI Vision API: [OpenAI Documentation](https://platform.openai.com/docs/guides/vision)

