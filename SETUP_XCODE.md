# Xcode Setup Instructions

## After Installing Xcode

Run these commands in Terminal to enable automated builds:

### 1. Set Xcode as Active Developer Directory
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### 2. Accept Xcode License (if prompted)
```bash
sudo xcodebuild -license accept
```

### 3. Verify It Works
```bash
xcodebuild -version
```

You should see something like:
```
Xcode 15.0
Build version 15A240d
```

## Once Configured

After Xcode is set up, the automated build system will:
- ✅ Automatically run clean after every code fix
- ✅ Automatically run build to verify
- ✅ Automatically fix any errors found
- ✅ Repeat until build succeeds

**No manual intervention needed!**

## Test the System

After setup, you can test it:
```bash
cd "/Users/ekodevapps/Documents/Calenda Notes"
bash auto_clean_build.sh
```

This will clean and build automatically, showing you the results.

