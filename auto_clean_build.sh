#!/bin/bash
# Automatic Clean and Build System
# Runs clean, then build, and monitors for errors

PROJECT_PATH="/Users/ekodevapps/Documents/Calenda Notes"
PROJECT_NAME="Calenda Notes.xcodeproj"
SCHEME="Calenda Notes"
BUILD_LOG="/tmp/xcode_build_$(date +%s).log"

cd "$PROJECT_PATH" || exit 1

# Try to find Xcode
XCODE_PATHS=(
    "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
    "$(mdfind 'kMDItemKind == "Application" && kMDItemDisplayName == "Xcode"' 2>/dev/null | head -1)/Contents/Developer/usr/bin/xcodebuild"
    "/usr/bin/xcodebuild"
)

XCODEBUILD=""
for path in "${XCODE_PATHS[@]}"; do
    if [ -f "$path" ] && "$path" -version >/dev/null 2>&1; then
        XCODEBUILD="$path"
        break
    fi
done

if [ -z "$XCODEBUILD" ]; then
    echo "❌ ERROR: xcodebuild not found. Full Xcode installation required."
    echo "   Please install Xcode from the App Store, then run:"
    echo "   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

echo "=== AUTOMATED BUILD SYSTEM ==="
echo "Using: $XCODEBUILD"
echo ""

# Step 1: Clean
echo "🧹 STEP 1: Cleaning build folder..."
"$XCODEBUILD" -project "$PROJECT_NAME" -scheme "$SCHEME" -destination "generic/platform=iOS" clean > "$BUILD_LOG.clean" 2>&1
CLEAN_STATUS=$?

if [ $CLEAN_STATUS -eq 0 ]; then
    echo "✅ Clean successful"
else
    echo "⚠️  Clean had warnings (continuing anyway)"
fi

echo ""

# Step 2: Build
echo "🔨 STEP 2: Building project..."
"$XCODEBUILD" -project "$PROJECT_NAME" -scheme "$SCHEME" -destination "generic/platform=iOS" build > "$BUILD_LOG" 2>&1
BUILD_STATUS=$?

echo ""
echo "=== BUILD RESULTS ==="

if [ $BUILD_STATUS -eq 0 ]; then
    echo "✅ BUILD SUCCEEDED"
    echo ""
    echo "Summary:"
    grep -E "BUILD SUCCEEDED|warning:" "$BUILD_LOG" | tail -5
    exit 0
else
    echo "❌ BUILD FAILED"
    echo ""
    echo "=== ERRORS FOUND ==="
    grep -i "error:" "$BUILD_LOG" | head -30
    echo ""
    echo "Full log saved to: $BUILD_LOG"
    exit 1
fi

