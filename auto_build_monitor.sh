#!/bin/bash
# Automatic Build Monitor and Error Fixer
# This script cleans, builds, and monitors for errors

PROJECT_PATH="/Users/ekodevapps/Documents/Calenda Notes"
PROJECT_NAME="Calenda Notes.xcodeproj"
SCHEME="Calenda Notes"

cd "$PROJECT_PATH" || exit 1

# Find Xcode
XCODE_PATH=$(mdfind "kMDItemKind == 'Application' && kMDItemDisplayName == 'Xcode'" 2>/dev/null | head -1)
if [ -z "$XCODE_PATH" ]; then
    XCODE_PATH="/Applications/Xcode.app"
fi

XCODEBUILD="$XCODE_PATH/Contents/Developer/usr/bin/xcodebuild"

if [ ! -f "$XCODEBUILD" ]; then
    echo "Error: xcodebuild not found at $XCODEBUILD"
    echo "Trying system xcodebuild..."
    XCODEBUILD="xcodebuild"
fi

echo "=== Cleaning Build ==="
$XCODEBUILD -project "$PROJECT_NAME" -scheme "$SCHEME" -destination "generic/platform=iOS" clean 2>&1

echo ""
echo "=== Building Project ==="
BUILD_OUTPUT=$($XCODEBUILD -project "$PROJECT_NAME" -scheme "$SCHEME" -destination "generic/platform=iOS" build 2>&1)
BUILD_STATUS=$?

echo "$BUILD_OUTPUT"

if [ $BUILD_STATUS -eq 0 ]; then
    echo ""
    echo "✅ BUILD SUCCEEDED"
    exit 0
else
    echo ""
    echo "❌ BUILD FAILED"
    echo ""
    echo "=== Errors Found ==="
    echo "$BUILD_OUTPUT" | grep -i "error:" | head -20
    exit 1
fi

