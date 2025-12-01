# How to Add Info.plist Keys - Step by Step

## You're on the Info Tab - Now Add These 3 Keys

### Key 1: Microphone Permission

1. **Click the "+" button** (usually at the top-left of the keys list, or right-click and select "Add Row")

2. **In the "Key" column**, type exactly:
   ```
   Privacy - Microphone Usage Description
   ```
   OR use the raw key name:
   ```
   NSMicrophoneUsageDescription
   ```
   (Xcode will auto-complete - either one works)

3. **In the "Type" column**, make sure it says: **String**

4. **In the "Value" column**, type:
   ```
   This app uses the microphone to capture your voice notes.
   ```

### Key 2: Speech Recognition Permission

1. **Click the "+" button again** (add another row)

2. **In the "Key" column**, type:
   ```
   Privacy - Speech Recognition Usage Description
   ```
   OR:
   ```
   NSSpeechRecognitionUsageDescription
   ```

3. **Type**: **String**

4. **Value**:
   ```
   This app uses speech recognition to convert your voice notes into text.
   ```

### Key 3: Calendar Permission

1. **Click the "+" button again** (add third row)

2. **In the "Key" column**, type:
   ```
   Privacy - Calendars Usage Description
   ```
   OR:
   ```
   NSCalendarsUsageDescription
   ```

3. **Type**: **String**

4. **Value**:
   ```
   This app uses Calendar access to save your notes as events.
   ```

## Final Result

After adding all 3, you should see something like:

| Key | Type | Value |
|-----|------|-------|
| Privacy - Microphone Usage Description | String | This app uses the microphone to capture your voice notes. |
| Privacy - Speech Recognition Usage Description | String | This app uses speech recognition to convert your voice notes into text. |
| Privacy - Calendars Usage Description | String | This app uses Calendar access to save your notes as events. |

## After Adding Keys

1. **Save** (Cmd + S) - though Xcode usually auto-saves
2. **Clean Build**: Product → Clean Build Folder (Shift + Cmd + K)
3. **Run the app again**: Click Play button (▶️) or Cmd + R

## Troubleshooting

### If "+" button doesn't work:
- **Right-click** in the keys list area
- Select **"Add Row"** or **"Add Item"**

### If you see a different interface:
- Some Xcode versions show a list with checkboxes
- Look for an **"Add"** or **"+"** button
- Or try **right-clicking** in the empty space

### If keys don't save:
- Make sure you're editing the **target's Info**, not the project's Info
- Check that "Calenda Notes" is selected under TARGETS (not PROJECT)

## Next Steps

Once all 3 keys are added:
1. Build and run the app (▶️)
2. Grant permissions when prompted on iPhone
3. Test the microphone button!

