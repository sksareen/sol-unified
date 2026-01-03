#!/bin/bash
# Create DMG for Sol Unified
# Brutalist-style installer with custom styling

set -e

cd "$(dirname "$0")"

echo "💿 Creating DMG for Sol Unified..."
echo ""

# Configuration
APP_NAME="Sol Unified"
VERSION="1.2"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="SolUnified-v$VERSION"
DMG_DIR="$BUILD_DIR/dmg"
TEMP_DMG="$BUILD_DIR/temp.dmg"
FINAL_DMG="$DMG_NAME.dmg"
BACKGROUND_DIR="$DMG_DIR/.background"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ Error: App bundle not found at $APP_BUNDLE"
    echo "Please run ./build.sh first"
    exit 1
fi

# Clean up previous DMG files
echo "🧹 Cleaning up previous DMG..."
rm -rf "$DMG_DIR"
rm -f "$TEMP_DMG"
rm -f "$FINAL_DMG"
rm -f "$BUILD_DIR/$DMG_NAME.dmg"

# Create DMG directory structure
echo "📁 Creating DMG directory..."
mkdir -p "$DMG_DIR"

# Copy app to DMG directory
echo "📋 Copying app bundle..."
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink
echo "🔗 Creating Applications symlink..."
ln -s /Applications "$DMG_DIR/Applications"

# Create background image for DMG
echo "🎨 Creating DMG background..."
mkdir -p "$BACKGROUND_DIR"

# Generate a brutalist background using Python
python3 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os

# DMG window will be 600x400
width, height = 600, 400
bg_color = "#0A0A0A"
accent_color = "#FF6B35"
text_color = "#333333"

img = Image.new('RGB', (width, height), bg_color)
draw = ImageDraw.Draw(img)

# Subtle grid pattern (brutalist)
grid_color = "#151515"
grid_spacing = 40
for x in range(0, width, grid_spacing):
    draw.line([(x, 0), (x, height)], fill=grid_color, width=1)
for y in range(0, height, grid_spacing):
    draw.line([(0, y), (width, y)], fill=grid_color, width=1)

# Orange accent line at bottom
draw.rectangle([0, height-4, width, height], fill=accent_color)

# Arrow from app to Applications (subtle guide)
draw.line([(200, 200), (400, 200)], fill="#2A2A2A", width=3)
# Arrow head
draw.polygon([(390, 190), (410, 200), (390, 210)], fill="#2A2A2A")

os.makedirs('.build/dmg/.background', exist_ok=True)
img.save('.build/dmg/.background/background.png')
print("  Background created")
PYEOF

# Calculate the size needed for the DMG
echo "📏 Calculating DMG size..."
SIZE=$(du -sm "$DMG_DIR" | awk '{print $1}')
SIZE=$((SIZE + 50)) # Add 50MB buffer

# Create temporary DMG
echo "🔧 Creating temporary DMG..."
hdiutil create -srcfolder "$DMG_DIR" \
    -volname "$APP_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${SIZE}m \
    "$TEMP_DMG"

# Mount the temporary DMG
echo "📦 Mounting temporary DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | egrep '^/dev/' | sed 1q | awk '{print $1}')
VOLUME_PATH="/Volumes/$APP_NAME"

# Wait for mount
sleep 2

# Set the DMG window properties using AppleScript
echo "🎨 Setting DMG window properties..."
osascript <<EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        
        -- Set background image
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Position icons (centered with space for arrow)
        set position of item "$APP_NAME.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Ensure everything is written
sync

# Unmount the temporary DMG
echo "⏏️  Unmounting temporary DMG..."
hdiutil detach "$DEVICE"

# Convert to compressed, read-only DMG
echo "🗜️  Compressing final DMG..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$BUILD_DIR/$DMG_NAME"

# Clean up
echo "🧹 Cleaning up..."
rm -rf "$DMG_DIR"
rm -f "$TEMP_DMG"

# Copy to project root for easy access
cp "$BUILD_DIR/$DMG_NAME.dmg" "$FINAL_DMG"

echo ""
echo "✅ DMG created successfully!"
echo "📦 Location: $FINAL_DMG"
echo ""
echo "File size:"
ls -lh "$FINAL_DMG" | awk '{print $5}'
echo ""
echo "To test the DMG:"
echo "  open \"$FINAL_DMG\""

