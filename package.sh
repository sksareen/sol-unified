#!/bin/bash
# One-step build and package script for Sol Unified

set -e

cd "$(dirname "$0")"

echo "🚀 Building and Packaging Sol Unified..."
echo ""
echo "════════════════════════════════════════"
echo ""

# Step 1: Build the app
./build.sh

echo ""
echo "════════════════════════════════════════"
echo ""

# Step 2: Create the DMG
./create-dmg.sh

echo ""
echo "════════════════════════════════════════"
echo ""
echo "🎉 All done!"
echo ""
echo "Your distributable DMG is ready at:"
echo "  SolUnified-v1.1.dmg"
echo ""
echo "To install:"
echo "  1. Open the DMG"
echo "  2. Drag Sol Unified to Applications"
echo "  3. Launch from Applications folder"

