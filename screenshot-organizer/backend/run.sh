#!/bin/bash

# Screenshot Organizer Backend Startup Script

echo "==================================="
echo "Screenshot Organizer Backend"
echo "==================================="

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install/update dependencies
echo "Installing dependencies..."
pip install -q -r requirements.txt

# Check for OpenRouter API key
if [ -z "$OPENROUTER_API_KEY" ]; then
    echo ""
    echo "ℹ️  Note: OPENROUTER_API_KEY environment variable not set."
    echo "   Using hardcoded key in main.py"
    echo ""
    echo "   To override, set:"
    echo "   export OPENROUTER_API_KEY='your-key-here'"
    echo ""
fi

# Start the server
echo "Starting Flask server on port 5001..."
echo "Press Ctrl+C to stop"
echo ""
python main.py

