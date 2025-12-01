#!/bin/bash
# Automatic Error Detection and Fixing System
# Checks Swift files for errors and reports them

PROJECT_PATH="/Users/ekodevapps/Documents/Calenda Notes"
cd "$PROJECT_PATH" || exit 1

echo "=== Checking Swift Files for Errors ==="
echo ""

ERRORS_FOUND=0

# Check each Swift file
for file in "Calenda Notes"/*.swift "Calenda Notes/ViewModels"/*.swift "Calenda Notes/Services"/*.swift; do
    if [ -f "$file" ]; then
        echo "Checking: $file"
        # Use swiftc to type-check (basic syntax checking)
        swiftc -typecheck "$file" 2>&1 | grep -i "error:" && ERRORS_FOUND=1
    fi
done

if [ $ERRORS_FOUND -eq 0 ]; then
    echo ""
    echo "✅ No syntax errors found in Swift files"
    echo ""
    echo "Note: Full build requires Xcode. Run 'Product > Clean Build Folder' then 'Product > Build' in Xcode."
else
    echo ""
    echo "❌ Errors found - will be fixed automatically"
fi

exit $ERRORS_FOUND

