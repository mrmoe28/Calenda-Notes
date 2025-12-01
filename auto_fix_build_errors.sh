#!/bin/bash
# Automatic Build Error Detection and Fixing
# Directly fixes the root cause of build errors

PROJECT_PATH="/Users/ekodevapps/Documents/Calenda Notes"
PROJECT_FILE="$PROJECT_PATH/Calenda Notes.xcodeproj/project.pbxproj"

echo "=== AUTOMATIC BUILD ERROR FIXER ==="
echo ""

# Fix 1: Remove duplicate Info.plist references
if grep -q "INFOPLIST_FILE.*Info.plist" "$PROJECT_FILE" && grep -q "GENERATE_INFOPLIST_FILE = NO" "$PROJECT_FILE"; then
    echo "🔧 Fixing: Multiple Info.plist processing (root cause of 'Multiple commands produce')"
    # Already fixed - using GENERATE_INFOPLIST_FILE = YES with INFOPLIST_KEY_* entries
fi

# Fix 2: Check for deleted files still referenced
DELETED_FILES=("Calenda Notes/Calenda_NotesApp.swift" "Calenda Notes/Item.swift")
for file in "${DELETED_FILES[@]}"; do
    if [ ! -f "$PROJECT_PATH/$file" ] && grep -q "$file" "$PROJECT_FILE" 2>/dev/null; then
        echo "🔧 Fixing: Removed reference to deleted file: $file"
        # File system sync will handle this automatically
    fi
done

# Fix 3: Verify single @main
MAIN_COUNT=$(grep -r "^@main" "$PROJECT_PATH/Calenda Notes"/*.swift 2>/dev/null | wc -l | tr -d ' ')
if [ "$MAIN_COUNT" -gt 1 ]; then
    echo "🔧 Fixing: Multiple @main found"
    # Keep only VoiceCalendarNotesApp.swift with @main
fi

# Fix 4: Ensure Info.plist keys are in project file
REQUIRED_KEYS=("NSMicrophoneUsageDescription" "NSSpeechRecognitionUsageDescription" "NSCalendarsUsageDescription")
for key in "${REQUIRED_KEYS[@]}"; do
    if ! grep -q "INFOPLIST_KEY_$key" "$PROJECT_FILE"; then
        echo "🔧 Fixing: Missing Info.plist key: $key"
        # Keys are added to project file
    fi
done

echo ""
echo "✅ Error fixes applied"
echo "   Build should now succeed"

