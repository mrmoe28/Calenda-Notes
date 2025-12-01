# Voice Calendar Notes

A production-ready iOS app that converts voice notes to text and saves them as calendar events.

## Features

- 🎤 **Voice Recording**: Tap to record voice notes using the device microphone
- 📝 **Speech-to-Text**: Real-time transcription using Apple's Speech framework
- 📅 **Calendar Integration**: Save transcribed notes as calendar events with customizable date/time
- ✨ **Clean UI**: Simple, intuitive SwiftUI interface

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Physical iOS device (required for microphone and speech recognition testing)

## Project Structure

```
Calenda Notes/
├── VoiceCalendarNotesApp.swift      # App entry point
├── ContentView.swift                 # Main UI view
├── ViewModels/
│   └── MainViewModel.swift          # State management and coordination
├── Services/
│   ├── SpeechRecognitionManager.swift  # Speech recognition service
│   └── CalendarManager.swift           # Calendar integration service
└── Assets.xcassets/                 # App icons and assets
```

## Setup Instructions

### 1. Add Files to Xcode Project

1. Open your Xcode project
2. If the files don't already exist in the project navigator:
   - Right-click on the project folder
   - Select "Add Files to [Project Name]..."
   - Navigate to and select:
     - `VoiceCalendarNotesApp.swift`
     - `ContentView.swift`
     - `ViewModels/MainViewModel.swift`
     - `Services/SpeechRecognitionManager.swift`
     - `Services/CalendarManager.swift`
   - Ensure "Copy items if needed" is checked
   - Ensure your app target is selected
   - Click "Add"

### 2. Update App Entry Point

If you have an existing `Calenda_NotesApp.swift`, you can either:
- Replace it with `VoiceCalendarNotesApp.swift`, or
- Update the existing file to match the content of `VoiceCalendarNotesApp.swift`

### 3. Add Info.plist Keys

**CRITICAL**: You must add these three permission keys to your `Info.plist` file for the app to work.

#### Option A: Using Xcode UI

1. In Xcode, select your project in the navigator
2. Select your app target
3. Go to the "Info" tab
4. Click the "+" button to add a new key
5. Add each of the following keys:

**Key 1: Microphone Usage**
- **Key**: `Privacy - Microphone Usage Description` (or `NSMicrophoneUsageDescription`)
- **Type**: String
- **Value**: `This app uses the microphone to capture your voice notes.`

**Key 2: Speech Recognition Usage**
- **Key**: `Privacy - Speech Recognition Usage Description` (or `NSSpeechRecognitionUsageDescription`)
- **Type**: String
- **Value**: `This app uses speech recognition to convert your voice notes into text.`

**Key 3: Calendar Usage**
- **Key**: `Privacy - Calendars Usage Description` (or `NSCalendarsUsageDescription`)
- **Type**: String
- **Value**: `This app uses Calendar access to save your notes as events.`

#### Option B: Editing Info.plist Directly

If you prefer to edit the `Info.plist` file directly, add these entries:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app uses the microphone to capture your voice notes.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>This app uses speech recognition to convert your voice notes into text.</string>

<key>NSCalendarsUsageDescription</key>
<string>This app uses Calendar access to save your notes as events.</string>
```

### 4. Configure Project Settings

1. **Set Minimum iOS Version**:
   - Select your project in Xcode
   - Select your app target
   - Go to "General" tab
   - Set "Minimum Deployments" to iOS 17.0 or higher

2. **Enable Required Capabilities**:
   - The app uses standard iOS frameworks (Speech, AVFoundation, EventKit)
   - No additional capabilities need to be enabled in Xcode

### 5. Build and Run

1. **Connect a Physical Device**:
   - Connect your iPhone to your Mac via USB
   - Trust the computer if prompted on your iPhone
   - In Xcode, select your device from the device dropdown (top toolbar)

2. **Build the Project**:
   - Press `Cmd + B` to build, or
   - Click the "Play" button to build and run

3. **Grant Permissions**:
   - When the app launches, it will request permissions:
     - **Microphone**: Tap "Allow" when prompted
     - **Speech Recognition**: Tap "Allow" when prompted
     - **Calendar**: Tap "Allow" when prompted
   - If you deny any permission, you can grant it later in:
     - Settings → [Your App Name] → Enable the respective permissions

## How to Use

1. **Record a Voice Note**:
   - Tap the large microphone button
   - Speak your note clearly
   - Tap the button again to stop recording
   - Your transcribed text will appear in the text area

2. **Edit Event Details**:
   - The event title is auto-populated from your transcription (first 50-80 characters)
   - You can edit the title in the text field
   - Adjust the date and time using the date picker (defaults to 5 minutes from now)

3. **Save to Calendar**:
   - Tap "Save to Calendar" button
   - The event will be saved with:
     - Title: Your edited title (or transcription preview)
     - Notes: Full transcription text
     - Start: Selected date/time
     - End: Start time + 30 minutes
   - A success message will appear, and the transcription will clear after 2 seconds

## Troubleshooting

### "Speech recognition is not available"
- Ensure you're running on a physical device (not simulator)
- Check that your device language is supported by SFSpeechRecognizer
- Try restarting the app

### "Microphone permission denied"
- Go to Settings → [Your App Name] → Enable Microphone
- Restart the app

### "Calendar access not authorized"
- Go to Settings → [Your App Name] → Enable Calendars
- Ensure you have at least one calendar set up in the Calendar app
- Restart the app

### "No default calendar available"
- Open the Calendar app on your device
- Create at least one calendar
- Restart the app

### App crashes on launch
- Check that all Info.plist keys are added correctly
- Verify all files are added to the correct target
- Check Xcode console for specific error messages

## Architecture

The app follows a clean MVVM architecture:

- **View Layer** (`ContentView.swift`): SwiftUI views that display UI and handle user interactions
- **ViewModel Layer** (`MainViewModel.swift`): Manages app state, coordinates between services, and handles business logic
- **Service Layer**:
  - `SpeechRecognitionManager`: Handles speech recognition using SFSpeechRecognizer and AVAudioEngine
  - `CalendarManager`: Manages calendar access and event creation using EventKit

## Key Implementation Details

### Speech Recognition
- Uses `SFSpeechRecognizer` for speech-to-text conversion
- Uses `AVAudioEngine` for real-time audio capture
- Implements partial result reporting for live transcription updates
- Handles audio session configuration for recording

### Calendar Integration
- Uses `EKEventStore` for calendar access
- Creates `EKEvent` objects with title, notes, and date/time
- Saves to the default calendar for new events
- Includes comprehensive error handling

### Permissions
- Requests permissions asynchronously using modern Swift concurrency
- Provides user-friendly error messages
- Includes Settings deep-link for permission management

## Testing

1. **Test on Physical Device**: Speech recognition requires a physical device
2. **Test Permissions**: Try denying permissions to ensure error handling works
3. **Test Calendar Saving**: Verify events appear in the Calendar app
4. **Test Transcription**: Speak clearly and verify accuracy

## Notes

- The app uses only Apple frameworks (no third-party dependencies)
- Speech recognition works best in quiet environments
- Calendar events are saved to your default calendar
- The app clears transcription after successful save to prevent duplicate events

## License

This project is provided as-is for educational and personal use.

