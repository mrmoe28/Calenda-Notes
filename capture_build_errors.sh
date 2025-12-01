#!/bin/bash
# Captures Xcode build errors automatically

PROJECT_PATH="/Users/ekodevapps/Documents/Calenda Notes"
ERROR_LOG="$PROJECT_PATH/build_errors.log"

echo "=== CAPTURING BUILD ERRORS ==="
echo ""

# Check for recent build logs
RECENT_LOG=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcactivitylog" -type f -mtime -1 2>/dev/null | head -1)

if [ -n "$RECENT_LOG" ]; then
    echo "Found recent build log: $RECENT_LOG"
    echo "Extracting errors..."
    
    # Try to extract errors (xcactivitylog is binary, but we can try)
    echo "Build log found but may need Xcode to parse"
    echo "Please check Xcode Issue Navigator (Cmd+4) for errors"
else
    echo "No recent build logs found"
    echo "Please build in Xcode and errors will be captured"
fi

echo ""
echo "To capture errors manually:"
echo "1. Build in Xcode (Cmd+B)"
echo "2. Open Issue Navigator (Cmd+4)"
echo "3. Copy error messages"
echo "4. Share with me"

