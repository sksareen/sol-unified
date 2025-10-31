# Quick Start Guide - Sol Unified

## Get Running in 2 Minutes

### Step 1: Set OpenAI API Key (Optional - for AI screenshot analysis)

```bash
export OPENAI_API_KEY='your-api-key-here'
```

Or add to your shell profile (`~/.zshrc` or `~/.bash_profile`):
```bash
echo 'export OPENAI_API_KEY="your-api-key-here"' >> ~/.zshrc
source ~/.zshrc
```

**Note**: The API key is optional. Screenshots will work without it, but AI analysis features won't be available.

### Step 2: Run the App

```bash
cd /Users/savarsareen/coding/mable/sol-unified
./run.sh
```

Or directly:
```bash
cd /Users/savarsareen/coding/mable/sol-unified
swift run
```

### Step 3: First Launch

1. Grant Accessibility permission when prompted (required for global hotkey)
2. Press **Option + `** (backtick) to show/hide the window

---

## That's It!

You now have:
- ✅ Global hotkey access (Option + `)
- ✅ Notes with auto-save
- ✅ Clipboard history manager
- ✅ Screenshot organizer

---

## Quick Usage

### Keyboard Shortcuts
- **Option + `**: Show/hide window
- **Cmd + 1**: Notes tab
- **Cmd + 2**: Clipboard tab
- **Cmd + 3**: Screenshots tab
- **Cmd + ,**: Settings
- **Tab**: Cycle through tabs
- **Esc**: Close modals

### Screenshots Setup

1. Open Settings (Cmd + ,)
2. Click "Select..." next to Screenshot Folder
3. Choose your screenshots directory
4. Go to Screenshots tab
5. Click "Scan" to index your screenshots

### Notes
- Start typing in the scratchpad - it auto-saves
- All your notes are persistent

### Clipboard
- Automatically captures clipboard history
- Click any item to copy it back
- Search through history

---

## Troubleshooting

### Hotkey not working?
- Grant Accessibility: **System Settings → Privacy & Security → Accessibility**
- Add Sol Unified to allowed apps
- Restart the app

### Screenshots not showing?
- Check the folder path in Settings
- Make sure the folder contains image files (.png, .jpg, etc.)
- Click "Scan" button and check console output
- Verify folder permissions

### Build errors?
```bash
cd /Users/savarsareen/coding/mable/sol-unified
swift build
```

---

## Project Structure

```
sol-unified/
├── SolUnified/          # Swift source code
├── Package.swift        # Swift Package Manager config
├── run.sh              # Quick run script
└── README.md           # Full documentation
```

---

**You're ready to go! Press Option + ` and enjoy! 🚀**
