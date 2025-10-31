#!/bin/bash
# Verification script for Sol Unified project structure

echo "🔍 Verifying Sol Unified Project Structure..."
echo ""

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

ERRORS=0
WARNINGS=0

# Check directories
echo "📁 Checking directories..."
REQUIRED_DIRS=(
    "SolUnified/App"
    "SolUnified/Core"
    "SolUnified/Features/Notes"
    "SolUnified/Features/Clipboard"
    "SolUnified/Features/Screenshots"
    "SolUnified/Shared"
    "SolUnified/Resources"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir"
    else
        echo "  ✗ $dir (MISSING)"
        ((ERRORS++))
    fi
done

echo ""

# Check source files
echo "📄 Checking source files..."
REQUIRED_FILES=(
    "SolUnified/App/SolUnifiedApp.swift"
    "SolUnified/App/AppDelegate.swift"
    "SolUnified/Core/WindowManager.swift"
    "SolUnified/Core/HotkeyManager.swift"
    "SolUnified/Core/Database.swift"
    "SolUnified/Shared/Models.swift"
    "SolUnified/Shared/BrutalistStyles.swift"
    "SolUnified/Shared/TabNavigator.swift"
    "SolUnified/Features/Notes/NotesView.swift"
    "SolUnified/Features/Notes/NotesStore.swift"
    "SolUnified/Features/Notes/ScratchpadView.swift"
    "SolUnified/Features/Notes/NotesListView.swift"
    "SolUnified/Features/Clipboard/ClipboardView.swift"
    "SolUnified/Features/Clipboard/ClipboardStore.swift"
    "SolUnified/Features/Clipboard/ClipboardMonitor.swift"
    "SolUnified/Features/Screenshots/ScreenshotsView.swift"
    "SolUnified/Features/Screenshots/ScreenshotsStore.swift"
    "SolUnified/Features/Screenshots/ScreenshotAnalyzer.swift"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
        ((ERRORS++))
    fi
done

echo ""

# Check config files
echo "⚙️  Checking configuration files..."
CONFIG_FILES=(
    "Info.plist"
    "SolUnified.entitlements"
    "Package.swift"
    "README.md"
    "run.sh"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
        ((ERRORS++))
    fi
done

echo ""

# Check ScreenshotScanner (new native implementation)
echo "📸 Checking screenshot scanner..."
if [ -f "SolUnified/Features/Screenshots/ScreenshotScanner.swift" ]; then
    echo "  ✓ ScreenshotScanner.swift (native implementation)"
else
    echo "  ✗ ScreenshotScanner.swift (MISSING)"
    ((ERRORS++))
fi

echo ""

# Check environment
echo "🔑 Checking environment..."
if [ -z "$OPENAI_API_KEY" ]; then
    echo "  ⚠ OPENAI_API_KEY not set (AI screenshot analysis won't work)"
    echo "     Screenshots will still work without AI analysis"
    ((WARNINGS++))
else
    echo "  ✓ OPENAI_API_KEY is set"
fi

echo ""

# Count Swift files
echo "📊 Statistics..."
SWIFT_COUNT=$(find SolUnified -name "*.swift" | wc -l | tr -d ' ')
echo "  Total Swift files: $SWIFT_COUNT"

SWIFT_LINES=$(find SolUnified -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print $1}')
echo "  Total lines of Swift code: $SWIFT_LINES"

echo ""

# Summary
echo "═══════════════════════════════════════"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ ALL CHECKS PASSED!"
    echo "Your project structure is complete."
    echo ""
    echo "Next steps:"
    echo "1. Run: ./run.sh"
    echo "2. Grant Accessibility permission when prompted"
    echo "3. Press Option + ` to show/hide the window"
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  CHECKS PASSED WITH WARNINGS"
    echo "Warnings: $WARNINGS"
    echo "Project will work but some features may be limited."
else
    echo "❌ CHECKS FAILED"
    echo "Errors: $ERRORS, Warnings: $WARNINGS"
    echo "Please fix errors before building."
fi
echo "═══════════════════════════════════════"

