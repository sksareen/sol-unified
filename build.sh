#!/bin/bash
# Build script for Sol Unified macOS app

set -e

cd "$(dirname "$0")"

echo "🔨 Building Sol Unified..."
echo ""

# Configuration
APP_NAME="Sol Unified"
BUNDLE_ID="com.solunified.app"
VERSION="1.0"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "$APP_BUNDLE"

# Build the Swift executable in release mode
echo "⚙️  Building Swift executable..."
swift build -c release

# Create .app bundle structure
echo "📦 Creating .app bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy the executable
echo "📋 Copying executable..."
cp ".build/release/SolUnified" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2024-2025. All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Sol Unified needs access to your Photos library to display your photos without duplicating them.</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>Sol Unified needs Apple Events permission for clipboard monitoring.</string>
	<key>NSAccessibilityUsageDescription</key>
	<string>Sol Unified needs Accessibility permission for global hotkey support.</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy resources (if any)
if [ -d "SolUnified/Resources" ]; then
    echo "📁 Copying resources..."
    cp -R SolUnified/Resources/* "$RESOURCES_DIR/" 2>/dev/null || true
fi

# Optional: Code signing (uncomment if you have a developer certificate)
# echo "✍️  Signing app..."
# codesign --force --deep --sign "Developer ID Application: YOUR NAME" "$APP_BUNDLE"

echo ""
echo "✅ Build complete!"
echo "📦 App bundle created at: $APP_BUNDLE"
echo ""
echo "To test the app, run:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "To create a DMG, run:"
echo "  ./create-dmg.sh"

