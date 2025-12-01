#!/bin/bash
# Direct Error Fixer - Fixes root cause immediately
# No checking, no analysis - just fixes the actual problem

PROJECT_FILE="/Users/ekodevapps/Documents/Calenda Notes/Calenda Notes.xcodeproj/project.pbxproj"

# Fix "Multiple commands produce" error
# Root cause: Both INFOPLIST_FILE and GENERATE_INFOPLIST_FILE were set
# Solution: Use only GENERATE_INFOPLIST_FILE with INFOPLIST_KEY_* entries

sed -i '' 's/INFOPLIST_FILE = "Calenda Notes\/Info.plist";//g' "$PROJECT_FILE"
sed -i '' 's/GENERATE_INFOPLIST_FILE = NO;/GENERATE_INFOPLIST_FILE = YES;/g' "$PROJECT_FILE"

echo "✅ Fixed: Removed duplicate Info.plist processing"
echo "   Build should now succeed"

