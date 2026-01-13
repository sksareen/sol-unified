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

# Follow logs
echo "📋 Following logs (Ctrl+C to stop)..."
sleep 2
log stream --predicate 'subsystem == "com.solunified.app" OR process == "Sol Unified"' --level debug 2>/dev/null || echo "Log streaming not available, check Console.app for logs"

