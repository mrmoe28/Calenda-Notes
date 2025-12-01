# Getting Started Guide - For Xcode Beginners

## Step 1: Build and Run the App

### First Time Setup:

1. **Make sure your iPhone is selected:**
   - Look at the top of Xcode (toolbar area)
   - Click the device dropdown (it might say "Any iOS Device" or show your Mac name)
   - Select your iPhone from the list
   - It should show: "Your iPhone Name (iOS X.X)"

2. **Build and Run:**
   - Click the **Play button** (▶️) in the top-left corner of Xcode
   - OR press **Cmd + R** on your keyboard
   - Xcode will build the app (this takes 30-60 seconds the first time)
   - The app will install on your iPhone and launch automatically

3. **What to expect:**
   - You'll see build progress in Xcode (bottom panel)
   - Your iPhone screen will show the app launching
   - The app should open automatically

## Step 2: Add Required Permissions (CRITICAL!)

**This is the #1 reason buttons don't work!**

### In Xcode:

1. **Click the blue project icon** at the top of the left sidebar (Project Navigator)

2. **Select "Calenda Notes"** under TARGETS (not PROJECT)
   - You'll see it in the main editor area
   - Make sure you click on TARGETS, not PROJECT

3. **Click the "Info" tab** at the top of the editor

4. **Add the three permission keys:**

   **Key 1: Microphone**
   - Click the **"+"** button (top-left of the keys list)
   - In the dropdown, type: `Privacy - Microphone Usage Description`
   - OR type the raw key: `NSMicrophoneUsageDescription`
   - Set Type to: **String**
   - Set Value to: `This app uses the microphone to capture your voice notes.`

   **Key 2: Speech Recognition**
   - Click **"+"** again
   - Type: `Privacy - Speech Recognition Usage Description`
   - OR: `NSSpeechRecognitionUsageDescription`
   - Type: **String**
   - Value: `This app uses speech recognition to convert your voice notes into text.`

   **Key 3: Calendar**
   - Click **"+"** again
   - Type: `Privacy - Calendars Usage Description`
   - OR: `NSCalendarsUsageDescription`
   - Type: **String**
   - Value: `This app uses Calendar access to save your notes as events.`

5. **Save:** The changes save automatically

6. **Rebuild the app:**
   - Product → Clean Build Folder (Shift + Cmd + K)
   - Click Play button again (▶️) or press Cmd + R

## Step 3: Grant Permissions on iPhone

When you run the app, you'll see permission prompts:

1. **First Launch:**
   - App opens on your iPhone
   - You'll see a popup: "Calenda Notes Would Like to Access the Microphone"
   - Tap **"Allow"**
   - Another popup: "Calenda Notes Would Like to Access Speech Recognition"
   - Tap **"Allow"**
   - Another popup: "Calenda Notes Would Like to Access Your Calendars"
   - Tap **"Allow"**

2. **If you accidentally denied:**
   - On iPhone: Settings → Scroll down → Tap "Calenda Notes"
   - Enable:
     - ✅ Microphone
     - ✅ Speech Recognition
     - ✅ Calendars
   - Go back to the app

## Step 4: Test the Features

### Test 1: Microphone Button

1. **Tap the big blue microphone button** in the app
2. **What should happen:**
   - Button turns **red**
   - Shows "Listening..." text
   - Button pulses/animates
3. **Speak clearly** into your iPhone
4. **Watch the text area** - your words should appear as you speak!
5. **Tap the button again** to stop recording

### Test 2: Save to Calendar

1. **After recording**, you should see:
   - Transcribed text in the text area
   - Event title field (auto-filled)
   - Date picker (shows date/time)
   - "Save to Calendar" button

2. **Edit if needed:**
   - Change the event title
   - Adjust the date/time using the date picker

3. **Tap "Save to Calendar"**
4. **You should see:** "Event saved to calendar!" message
5. **Check your Calendar app** - the event should be there!

## Step 5: Understanding Xcode Basics

### Important Xcode Areas:

1. **Project Navigator** (left sidebar):
   - Shows all your files
   - Click files to open them

2. **Editor Area** (center):
   - Shows code when you click a file
   - Shows project settings when you click the blue project icon

3. **Toolbar** (top):
   - **Play button (▶️)**: Build and run app
   - **Stop button (⏹)**: Stop running app
   - **Device selector**: Choose iPhone or Simulator

4. **Debug Area** (bottom):
   - **Console**: Shows messages and errors
   - Open it: View → Debug Area → Activate Console
   - Or press: Shift + Cmd + Y

### Common Xcode Actions:

- **Build**: Cmd + B (checks for errors, doesn't run)
- **Run**: Cmd + R (builds and runs on device)
- **Clean**: Shift + Cmd + K (clears build cache)
- **Stop**: Cmd + . (stops running app)

## Troubleshooting: Buttons Still Don't Work

### Check 1: Info.plist Keys
- Go back to Step 2
- Make sure all 3 keys are added
- Check spelling is correct

### Check 2: Permissions
- On iPhone: Settings → Calenda Notes
- All 3 permissions should be ON

### Check 3: Console Messages
1. In Xcode, open Console (Shift + Cmd + Y)
2. Tap the microphone button on iPhone
3. Look for messages starting with 🎤
4. If you see errors, note them down

### Check 4: Files Are in Project
In Project Navigator (left sidebar), check these files exist:
- ✅ VoiceCalendarNotesApp.swift
- ✅ ContentView.swift
- ✅ ViewModels/MainViewModel.swift
- ✅ Services/SpeechRecognitionManager.swift
- ✅ Services/CalendarManager.swift

If any are **red** (missing):
- Right-click → Delete → Remove Reference
- Right-click folder → Add Files to Project
- Select the file → Make sure target is checked

## Quick Test Checklist

After following all steps:

- [ ] App launches on iPhone
- [ ] All 3 permission prompts appeared and were allowed
- [ ] Microphone button is visible
- [ ] Tapping button turns it red
- [ ] Speaking shows text in the text area
- [ ] "Save to Calendar" button is visible
- [ ] Tapping save shows success message
- [ ] Event appears in Calendar app

## Next Steps

Once everything works:

1. **Try recording a voice note**
2. **Save it to calendar**
3. **Check your Calendar app** to see the event
4. **Experiment with different dates/times**

## Getting Help

If something doesn't work:

1. **Check the Console** (Shift + Cmd + Y) for error messages
2. **Take a screenshot** of:
   - Info.plist keys (Info tab)
   - Console errors
   - What happens when you tap buttons
3. **Note which step fails** from the checklist above

## Tips for Beginners

- **Don't worry about errors** - they're normal when learning
- **Read error messages** - they usually tell you what's wrong
- **Use Clean Build** if things get weird (Shift + Cmd + K)
- **Check Console** for clues about what's happening
- **Save often** - Xcode auto-saves, but it's good practice

Good luck! 🚀

