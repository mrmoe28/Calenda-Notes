# How to Lower iOS Deployment Target in Xcode

## Method 1: Using Xcode UI (Recommended)

1. **Open your project in Xcode**
   - Double-click `Calenda Notes.xcodeproj` to open it

2. **Select your project in the Project Navigator**
   - Click on the blue project icon at the top of the file list

3. **Select your app target**
   - In the main editor area, click on "Calenda Notes" under TARGETS (not PROJECT)

4. **Go to the "General" tab**
   - You should see "Minimum Deployments" section

5. **Change iOS version**
   - Click on the iOS version dropdown (currently shows 26.0 or 17.0)
   - Select a lower version that matches your iPhone:
     - **iOS 16.0** - Works on iPhone 8 and later
     - **iOS 15.0** - Works on iPhone 6s and later
     - **iOS 14.0** - Works on iPhone 6s and later
     - **iOS 13.0** - Works on iPhone 6s and later

6. **Check your iPhone's iOS version**
   - On your iPhone: Settings → General → About → iOS Version
   - Choose a deployment target that's **equal to or lower than** your iPhone's iOS version

## Method 2: Check Your iPhone's iOS Version

To find out what iOS version your iPhone is running:

1. Open **Settings** app on your iPhone
2. Tap **General**
3. Tap **About**
4. Look for **iOS Version** or **Software Version**

Then set the deployment target to match or be lower than that version.

## Recommended Settings

- **For iPhone 8 or newer**: iOS 16.0 or 15.0
- **For iPhone 7 or older**: iOS 14.0 or 13.0
- **For maximum compatibility**: iOS 13.0 (supports iPhone 6s and later)

## After Changing Deployment Target

1. **Clean Build Folder**: Product → Clean Build Folder (Shift + Cmd + K)
2. **Build the project**: Product → Build (Cmd + B)
3. **Connect your iPhone** via USB
4. **Select your device** from the device dropdown in Xcode's toolbar
5. **Run the app**: Product → Run (Cmd + R)

## Important Notes

- The code has been updated to support iOS 13.0+ with proper fallbacks
- Speech recognition requires iOS 10.0+
- Calendar access works on iOS 6.0+
- The app will automatically use the correct APIs based on your iOS version

## Troubleshooting

If you get errors after changing the deployment target:

1. **Clean Build Folder** (Shift + Cmd + K)
2. **Delete Derived Data**:
   - Xcode → Settings → Locations
   - Click arrow next to Derived Data path
   - Delete the folder for your project
3. **Restart Xcode**
4. **Build again**

