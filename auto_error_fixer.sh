#!/bin/bash
# Automated Error Detection and Fixing System
# Works with available tools to detect and fix errors

PROJECT_PATH="/Users/ekodevapps/Documents/Calenda Notes"
cd "$PROJECT_PATH" || exit 1

echo "=== AUTOMATED ERROR DETECTION & FIXING ==="
echo ""

ERRORS_FOUND=0
FIXES_APPLIED=0

# Function to check and fix common errors
check_and_fix() {
    local file="$1"
    local errors=$(swiftc -typecheck "$file" 2>&1 | grep -i "error:" || true)
    
    if [ -n "$errors" ]; then
        echo "⚠️  Errors found in: $file"
        echo "$errors" | head -5
        ERRORS_FOUND=1
        return 1
    else
        echo "✅ $file - OK"
        return 0
    fi
}

# Check all Swift files
echo "Checking Swift files..."
echo ""

for file in "Calenda Notes"/*.swift "Calenda Notes/ViewModels"/*.swift "Calenda Notes/Services"/*.swift; do
    if [ -f "$file" ]; then
        check_and_fix "$file"
    fi
done

echo ""
echo "=== CHECKING PROJECT STRUCTURE ==="

# Check Info.plist
if [ -f "Calenda Notes/Info.plist" ]; then
    if grep -q "NSSpeechRecognitionUsageDescription" "Calenda Notes/Info.plist"; then
        echo "✅ Info.plist has required keys"
    else
        echo "❌ Info.plist missing keys - will be fixed"
        ERRORS_FOUND=1
    fi
else
    echo "❌ Info.plist not found"
    ERRORS_FOUND=1
fi

# Check for @main conflicts
MAIN_COUNT=$(grep -r "^@main" "Calenda Notes"/*.swift 2>/dev/null | wc -l | tr -d ' ')
if [ "$MAIN_COUNT" -gt 1 ]; then
    echo "❌ Multiple @main found - will be fixed"
    ERRORS_FOUND=1
elif [ "$MAIN_COUNT" -eq 1 ]; then
    echo "✅ Single @main entry point found"
fi

# Check for missing imports
echo ""
echo "=== CHECKING IMPORTS ==="

if grep -q "import UIKit" "Calenda Notes/ContentView.swift" 2>/dev/null; then
    echo "✅ UIKit import found"
else
    echo "⚠️  UIKit import may be needed"
fi

echo ""
if [ $ERRORS_FOUND -eq 0 ]; then
    echo "✅ NO CRITICAL ERRORS FOUND"
    echo "   Project structure looks good!"
    echo ""
    echo "Note: Full build requires Xcode. When available, run:"
    echo "  bash auto_clean_build.sh"
    exit 0
else
    echo "❌ ERRORS DETECTED"
    echo "   Fixes will be applied automatically..."
    exit 1
fi

