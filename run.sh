#!/bin/bash
# Quick run script for Sol Unified

cd "$(dirname "$0")"

echo "🚀 Building and running Sol Unified..."
echo ""

swift run

# If you want to run in release mode for better performance:
# swift run -c release

