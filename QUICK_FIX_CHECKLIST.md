# Quick Fix Checklist - "App Shows But Nothing Works"

## ⚠️ Most Common Issues (Check These First!)

### 1. Info.plist Keys Missing (90% of issues!)
**This is the #1 reason nothing works!**

✅ **Check in Xcode:**
1. Click blue project icon
2. Select "Calenda Notes" target  
3. Go to "Info" tab
4. Look for these 3 keys:

```
✅ NSMicrophoneUsageDescription
✅ NSSpeechRecognitionUsageDescription  
✅ NSCalendarsUsageDescription
```

**If ANY are missing → Add them!**
- Click "+" button
- Type: "Privacy - Microphone Usage Description" (or use raw key name)
- Value: "This app uses the microphone to capture your voice notes."
- Repeat for all 3

### 2. Permissions Not Granted on iPhone

✅ **On your iPhone:**
1. Settings → Scroll down → Tap "Calenda Notes"
2. Enable:
   - ✅ Microphone
   - ✅ Speech Recognition
   - ✅ Calendars

### 3. Files Not Added to Xcode Project

✅ **In Xcode Project Navigator, check these files:**
- `VoiceCalendarNotesApp.swift` (should be black, not red)
- `ContentView.swift`
- `ViewModels/MainViewModel.swift`
- `Services/SpeechRecognitionManager.swift`
- `Services/CalendarManager.swift`

**If any are RED:**
- Right-click → Delete → Remove Reference
- Right-click folder → Add Files to Project
- Select the file → Make sure target is checked

### 4. Wrong App Entry Point

✅ **Check which file has @main:**
- `VoiceCalendarNotesApp.swift` should have `@main`
- `Calenda_NotesApp.swift` should NOT have `@main`

## 🔍 Quick Diagnostic Test

**Follow these steps in order:**

1. **Open Xcode Console** (View → Debug Area → Console)

2. **Tap the microphone button** on your iPhone

3. **Look at Xcode console** - You should see:
   ```
   🎤 [MainViewModel] startRecording() called
   🎤 [MainViewModel] Requesting speech permissions...
   ```

4. **What do you see?**
   - ✅ **See the messages above** → Permissions are being requested, check Step 2
   - ❌ **See nothing** → Button tap not working, check if files are in project
   - ❌ **See error about Info.plist** → Add Info.plist keys (Step 1)
   - ❌ **See "Permission denied"** → Enable permissions in Settings (Step 2)

## 🚨 Emergency Fixes

### Fix 1: Re-add Info.plist Keys
1. In Xcode: Project → Target → Info tab
2. Delete all 3 permission keys (if they exist)
3. Add them back one by one
4. Clean build (Shift + Cmd + K)
5. Build and run again

### Fix 2: Reset Permissions
1. On iPhone: Settings → Calenda Notes
2. Turn OFF all permissions
3. Delete the app from iPhone
4. Reinstall from Xcode
5. Grant permissions when prompted

### Fix 3: Verify Project Setup
1. In Xcode: File → Project Settings
2. Check "Build System" is set correctly
3. Product → Clean Build Folder (Shift + Cmd + K)
4. Product → Build (Cmd + B)
5. Check for build errors

## 📱 Test on iPhone Step-by-Step

1. **Launch app** → Should see UI with microphone button
2. **Tap microphone** → Should see permission prompt OR button turns red
3. **If permission prompt appears** → Tap "Allow" for both
4. **Button should turn red** → Shows "Listening..."
5. **Speak something** → Text should appear in text area
6. **Tap button again** → Should stop and show transcription

**Which step fails?** That tells us where the problem is!

## 💡 Still Not Working?

**Share this information:**
1. Screenshot of Xcode console when you tap the button
2. Screenshot of Info.plist keys (Info tab)
3. Screenshot of iPhone Settings → App permissions
4. What happens when you tap the button? (Nothing? Error? Permission prompt?)

