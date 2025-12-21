# Distribution Guide for Sol Unified

This guide explains how to build and distribute Sol Unified as a macOS app.

## Quick Start

To build and create a distributable DMG in one step:

```bash
./package.sh
```

This will:
1. Build the app in release mode
2. Create a proper .app bundle
3. Package it into a DMG

The final DMG will be at: `.build/SolUnified-1.0.dmg`

## Step-by-Step Process

### 1. Build the App

```bash
./build.sh
```

This creates a proper macOS .app bundle at `.build/Sol Unified.app` by:
- Building the Swift executable in release mode
- Creating the .app bundle structure
- Copying the executable
- Creating Info.plist with proper metadata
- Setting up permissions

### 2. Create the DMG

```bash
./create-dmg.sh
```

This packages the app into a distributable DMG by:
- Creating a DMG directory with the app
- Adding an Applications symlink for easy installation
- Setting DMG window properties (icon size, position, etc.)
- Compressing to a read-only DMG

## Distribution

Once you have the DMG:

1. **Test it**: Open the DMG and drag the app to Applications
2. **Share it**: Upload the DMG to your distribution platform
3. **Install instructions**: Users simply:
   - Open the DMG
   - Drag Sol Unified to Applications
   - Launch from Applications folder
   - Grant Accessibility permission when prompted

## Code Signing (Optional)

For distribution outside the Mac App Store, you should sign your app with a Developer ID certificate.

### Prerequisites
- Apple Developer account ($99/year)
- Developer ID Application certificate

### Steps

1. Install your certificate in Keychain Access
2. Uncomment the signing section in `build.sh`:

```bash
codesign --force --deep --sign "Developer ID Application: YOUR NAME" "$APP_BUNDLE"
```

3. Replace "YOUR NAME" with your actual certificate name
4. Run `./package.sh` again

### Notarization (Recommended)

For macOS 10.15+, Apple requires notarization:

```bash
# After building and signing
xcrun notarytool submit .build/SolUnified-1.0.dmg \
    --apple-id "your-email@example.com" \
    --team-id "TEAM_ID" \
    --password "app-specific-password"

# Wait for approval, then staple
xcrun stapler staple .build/SolUnified-1.0.dmg
```

## Customization

### Change Version

Edit version numbers in `build.sh` and `create-dmg.sh`:

```bash
VERSION="1.0"
```

### Customize DMG Appearance

Edit `create-dmg.sh` to:
- Change icon positions
- Add a custom background image
- Adjust window size and layout
- Modify icon size

### Bundle Identifier

Edit `build.sh` to change the bundle identifier:

```bash
BUNDLE_ID="com.yourcompany.solunified"
```

## File Structure

After building, you'll have:

```
.build/
├── Sol Unified.app/          # The macOS app bundle
│   └── Contents/
│       ├── Info.plist        # App metadata
│       ├── MacOS/
│       │   └── Sol Unified   # Executable
│       ├── PkgInfo
│       └── Resources/        # App resources (if any)
└── SolUnified-1.0.dmg        # Distributable DMG
```

## Troubleshooting

### "App is damaged" error
- Sign your app with a Developer ID certificate
- Or, users can bypass Gatekeeper: Right-click app → Open

### "Cannot be opened because the developer cannot be verified"
- Sign and notarize your app
- Or, users can go to System Settings → Privacy & Security → Allow

### DMG creation fails
- Ensure you have disk space (needs ~50MB extra)
- Check that `build.sh` completed successfully
- Verify Xcode Command Line Tools are installed:
  ```bash
  xcode-select --install
  ```

### Icon doesn't show correctly
- Add an .icns file to Resources/
- Reference it in Info.plist:
  ```xml
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  ```

## Build Scripts

- **`build.sh`**: Builds the .app bundle
- **`create-dmg.sh`**: Creates the DMG
- **`package.sh`**: Runs both in sequence (recommended)
- **`run.sh`**: Quick development run (no packaging)

## Release Checklist

- [ ] Update version number in scripts
- [ ] Update CHANGELOG.md or release notes
- [ ] Test the app thoroughly
- [ ] Build with `./package.sh`
- [ ] Test the DMG on a clean Mac
- [ ] Sign and notarize (if distributing publicly)
- [ ] Create GitHub release with DMG attached
- [ ] Update download links in README

## Support

For issues with building or distribution, check:
- macOS version compatibility (requires 13.0+)
- Swift version (`swift --version` should be 5.9+)
- Xcode Command Line Tools installed
- Disk space available

