#!/bin/bash
# Start Screenshot Organizer Backend

BACKEND_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$BACKEND_DIR"

echo "🔍 Checking if backend is already running..."
if curl -s http://localhost:5001/api/stats > /dev/null 2>&1; then
    echo "✅ Backend is already running on http://localhost:5001"
    exit 0
fi

echo "🚀 Starting Screenshot Organizer Backend..."
echo "📁 Directory: $BACKEND_DIR"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3."
    exit 1
fi

# Check if requirements are installed
if [ ! -d "venv" ]; then
    echo "⚙️  Setting up virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
else
    source venv/bin/activate
fi

# Check for OPENAI_API_KEY
if [ -z "$OPENAI_API_KEY" ]; then
    echo "⚠️  Warning: OPENAI_API_KEY not set in environment"
    echo "   AI analysis will not work without it."
    echo "   Set it with: export OPENAI_API_KEY='your-key-here'"
    echo ""
fi

echo "🌐 Starting Flask server on http://localhost:5001..."
python3 main.py

# If we get here, the server stopped
echo "🛑 Backend stopped"

