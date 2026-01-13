#!/bin/bash
# Quick run script for Sol Unified

cd "$(dirname "$0")"

echo "🚀 Building and running Sol Unified..."
echo ""

# Build the app bundle (required for proper macOS permissions)
./build.sh

# Run the app bundle
echo ""
echo "🚀 Launching Sol Unified..."
open ".build/Sol Unified.app"

echo ""
echo "✅ App launched. Check Console.app for detailed logs if needed."

