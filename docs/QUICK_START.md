# Quick Start Guide - Sol Unified

## Get Running in 10 Minutes

### Step 1: Open Xcode (2 min)

```bash
cd /Users/savarsareen/coding/hanu/components/hanuPARTS/sol-unified
open -a Xcode .
```

### Step 2: Create Project (3 min)

1. **File → New → Project**
2. Choose: **macOS** → **App**
3. Settings:
   - Product Name: `SolUnified`
   - Interface: `SwiftUI`
   - Language: `Swift`
4. **IMPORTANT**: Save to **this directory** (the one with all the files)
rsareen/coding/hanu/components/hanuPARTS/sol-unified`
   - Click "Save" (Xcode will merge with existing files)

### Step 3: Add Source Files (2 min)

1. In Project Navigator, right-click "SolUnified" folder
2. **Add Files to "SolUnified"...**
3. Select the `SolUnified/` folder (with App, Core, Features, Shared)
4. Options:
   - **UNCHECK** "Copy items if needed"
   - Create groups: ✓
   - Add to targets: SolUnified ✓
5. Click "Add"

### Step 4: Link Frameworks (1 min)

1. Select project (blue icon at top)
2. Select "SolUnified" target
3. **Build Phases** tab
4. **Link Binary With Libraries** → Click "+"
5. Add: `libsqlite3.tbd`
6. **Build Settings** tab
7. Search: "Other Linker Flags"
8. Add: `-framework Carbon`

### Step 5: Configure (1 min)

1. **General** tab:
   - Deployment Target: `macOS 13.0`

2. **Signing & Capabilities** tab:
   - Remove "App Sandbox" (or configure entitlements)

3. **Info** tab:
   - Add: `LSUIElement` = `YES` (Boolean)

### Step 6: Build & Run (1 min)

1. Select target: **My Mac**
2. Press **Cmd + R** (or Product → Run)
3. Wait for build...
4. Grant Accessibility permission when prompted
5. Press **Option + `** (backtick)
6. Window should slide in! 🎉

---

## That's It!

You now have:
- ✅ Global hotkey access (Option + `)
- ✅ Notes with auto-save
- ✅ Clipboard history manager
- ✅ Screenshot organizer (needs OPENAI_API_KEY for AI)

---

## Quick Tips

### Set OpenAI Key (for screenshots)
```bash
echo 'export OPENAI_API_KEY="sk-..."' >> ~/.zshrc
source ~/.zshrc
```

### Keyboard Shortcuts
- **Option + `**: Show/hide window
- **Cmd + 1**: Notes tab
- **Cmd + 2**: Clipboard tab
- **Cmd + 3**: Screenshots tab
- **Cmd + N**: New note
- **Esc**: Close modals

### Test Clipboard
1. Open app (Option + `)
2. Click "CLIPBOARD" tab
3. Copy some text
4. See it appear in history
5. Click to re-copy

### Test Notes
1. Open app (Option + `)
2. "NOTES" tab (default)
3. Start typing in scratchpad
4. Click "LIST" to see all notes
5. Click "NEW NOTE" to create one

---

## Troubleshooting

### Hotkey not working?
- Grant Accessibility: **System Settings → Privacy → Accessibility**
- Add SolUnified to allowed apps

### Build errors?
- Make sure all Swift files have target membership checked
- Verify SQLite and Carbon are linked
- Clean build folder: **Product → Clean Build Folder**

### Window not appearing?
- Check Console.app for errors
- Press hotkey twice
- Restart app

---

## Full Docs

- **README.md** - Complete documentation
- **BUILD_INSTRUCTIONS.md** - Detailed step-by-step
- **IMPLEMENTATION_SUMMARY.md** - What was built
- **sol-unified-spec.json** - Complete specification

---

## Verification

Run this to check everything is in place:
```bash
./verify_structure.sh
```

Should show: ✅ ALL CHECKS PASSED!

---

**You're ready to go! Press Option + ` and enjoy! 🚀**

