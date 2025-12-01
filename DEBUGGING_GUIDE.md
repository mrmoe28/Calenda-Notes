# Debugging Guide: App Shows But Nothing Works

## Step 1: Check Xcode Console for Errors

1. **Open Xcode**
2. **Connect your iPhone** via USB
3. **Run the app** (Cmd + R)
4. **Open the Console**:
   - View → Debug Area → Activate Console (Shift + Cmd + Y)
   - Or click the bottom panel in Xcode
5. **Look for error messages** - Common errors:
   - "Info.plist key missing" → See Step 2
   - "Permission denied" → See Step 3
   - "File not found" → See Step 4

## Step 2: Verify Info.plist Keys Are Added

**CRITICAL**: The app won't work without these keys!

1. In Xcode, select your project (blue icon)
2. Select "Calenda Notes" target
3. Go to **"Info"** tab
4. Check for these three keys (they should be listed):

   ✅ **NSMicrophoneUsageDescription**
   - Value: "This app uses the microphone to capture your voice notes."
   
   ✅ **NSSpeechRecognitionUsageDescription**
   - Value: "This app uses speech recognition to convert your voice notes into text."
   
   ✅ **NSCalendarsUsageDescription**
   - Value: "This app uses Calendar access to save your notes as events."

5. **If any are missing**, add them:
   - Click the "+" button
   - Type the key name (e.g., "Privacy - Microphone Usage Description")
   - Set Type to "String"
   - Enter the value

## Step 3: Check App Permissions on iPhone

1. **On your iPhone**, open **Settings**
2. Scroll down and tap **"Calenda Notes"** (or your app name)
3. **Check these permissions**:
   - ✅ **Microphone** - Should be enabled
   - ✅ **Speech Recognition** - Should be enabled  
   - ✅ **Calendars** - Should be enabled

4. **If any are OFF**, toggle them ON
5. **Restart the app** on your iPhone

## Step 4: Verify All Files Are in Xcode Project

1. In Xcode Project Navigator, check these files exist:
   - ✅ `VoiceCalendarNotesApp.swift`
   - ✅ `ContentView.swift`
   - ✅ `ViewModels/MainViewModel.swift`
   - ✅ `Services/SpeechRecognitionManager.swift`
   - ✅ `Services/CalendarManager.swift`

2. **If any file is RED** (missing):
   - Right-click the file
   - Select "Delete" → "Remove Reference"
   - Then right-click the folder
   - Select "Add Files to [Project]..."
   - Navigate to the file and add it back
   - Make sure your app target is checked

## Step 5: Test Each Feature Individually

### Test 1: Check if UI Loads
- ✅ Does the date show at the top?
- ✅ Does the microphone button appear?
- ✅ Does the text area show "Your transcribed note will appear here..."?

### Test 2: Test Microphone Button
1. Tap the microphone button
2. **What happens?**
   - If nothing: Check console for errors
   - If you see "Requesting speech permission...": Good, wait for permission prompt
   - If you see error message: Check Info.plist keys

### Test 3: Check Console Output
When you tap the microphone button, look for these messages in Xcode console:
- "Requesting speech recognition permission..."
- "Speech recognition authorized"
- "Starting recording..."
- "Listening..."

**If you see errors instead**, note them down.

## Step 6: Common Issues and Fixes

### Issue: "Nothing happens when I tap the button"
**Possible causes:**
1. Info.plist keys missing → Add them (Step 2)
2. Permissions denied → Enable in Settings (Step 3)
3. Files not added to target → Check Step 4

### Issue: "App crashes immediately"
**Check:**
1. Xcode console for crash log
2. Info.plist keys are correct
3. All files are in the project

### Issue: "Button works but no transcription"
**Check:**
1. Are you speaking clearly?
2. Is the microphone working? (Test in other apps)
3. Check console for "Recognition error" messages
4. Is your device language supported? (English is most reliable)

### Issue: "Can't save to calendar"
**Check:**
1. Calendar permission is enabled (Step 3)
2. You have at least one calendar in the Calendar app
3. Check console for calendar errors

## Step 7: Enable Detailed Logging

Add this to see what's happening. In `MainViewModel.swift`, add print statements:

```swift
func startRecording() {
    print("🔴 startRecording() called")
    Task {
        print("🔴 Requesting permissions...")
        isProcessingPermissions = true
        let authorized = await requestSpeechPermissions()
        print("🔴 Permission result: \(authorized)")
        isProcessingPermissions = false
        
        if authorized {
            print("🔴 Starting speech manager...")
            speechManager.startRecording()
        } else {
            print("🔴 Permission denied!")
            showPermissionAlert(message: "Please enable Microphone and Speech Recognition access in Settings to record voice notes.")
        }
    }
}
```

Then check the Xcode console when you tap the button.

## Step 8: Quick Checklist

Before asking for help, verify:

- [ ] Info.plist has all 3 permission keys
- [ ] iPhone Settings → App → All permissions enabled
- [ ] All 5 Swift files are in Xcode project (not red)
- [ ] App builds without errors
- [ ] Running on physical iPhone (not simulator)
- [ ] Checked Xcode console for error messages
- [ ] Tried restarting the app

## Still Not Working?

If nothing works after checking all above:

1. **Share the Xcode console output** - Copy any error messages
2. **Check which step fails** - Does the button respond? Do you see permission prompts?
3. **Take a screenshot** of:
   - Your Info.plist keys
   - iPhone Settings → App permissions
   - Xcode console errors

## Quick Test: Minimal Functionality

To test if the basic app works:

1. **Tap microphone button** → Should show permission prompt
2. **Grant microphone permission** → Should show speech recognition prompt
3. **Grant speech permission** → Button should turn red and show "Listening..."
4. **Speak something** → Text should appear in the text area
5. **Tap button again** → Should stop recording

If any step fails, that's where the problem is!

