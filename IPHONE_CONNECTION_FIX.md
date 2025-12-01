# Fix: Xcode Can't Find iPhone

## Quick Fixes (Try These First!)

### 1. Trust the Computer on iPhone
**Most common issue!**

1. **Unlock your iPhone**
2. **Connect iPhone to Mac via USB**
3. **On iPhone**, you should see a popup: "Trust This Computer?"
4. **Tap "Trust"**
5. **Enter your iPhone passcode**
6. **In Xcode**, wait 10-20 seconds for device to appear

### 2. Check USB Cable and Port
- ✅ Use the **original Apple cable** (or certified MFi cable)
- ✅ Try a **different USB port** on your Mac
- ✅ Try a **different USB cable** if available
- ✅ Make sure cable is **fully plugged in** on both ends

### 3. Restart Devices
1. **Unplug iPhone** from Mac
2. **Restart iPhone**: Hold power button + volume down until Apple logo appears
3. **Restart Mac** (or at least quit and reopen Xcode)
4. **Reconnect iPhone** after both restart
5. **Open Xcode** and wait for device to appear

### 4. Check iPhone is Unlocked
- ✅ **Unlock your iPhone** (enter passcode)
- ✅ **Keep it unlocked** while connecting
- ✅ **Don't let it lock** while Xcode is detecting it

## Step-by-Step Connection Process

### Step 1: Prepare iPhone
1. Unlock iPhone
2. Connect to Mac via USB
3. If prompted: Tap "Trust This Computer" → Enter passcode

### Step 2: Check Xcode Device List
1. Open Xcode
2. Look at the **top toolbar** - there's a device selector
3. Click the device dropdown (should show "No Devices" or your Mac name)
4. Wait 10-30 seconds - your iPhone should appear

### Step 3: Verify Device Appears
Your iPhone should show as:
- **"Your iPhone Name" (iOS X.X)** 
- Or **"iPhone" (iOS X.X)**

If it shows but is **grayed out** or has a warning icon, see troubleshooting below.

## Advanced Troubleshooting

### Issue: Device Shows But Is Grayed Out

**Cause**: Device needs to be prepared for development

**Fix:**
1. In Xcode, click on your iPhone in the device list
2. Xcode will show: "This device needs to be prepared for development"
3. Click **"Prepare for Development"** or **"Use for Development"**
4. Wait for Xcode to process (may take 1-2 minutes)
5. Device should turn from gray to normal

### Issue: "Developer Mode Disabled"

**On iPhone:**
1. Settings → Privacy & Security
2. Scroll down to **"Developer Mode"**
3. **Enable Developer Mode**
4. iPhone will restart
5. After restart, confirm you want to enable Developer Mode
6. Reconnect to Xcode

### Issue: "Untrusted Developer"

**On iPhone:**
1. Settings → General → VPN & Device Management
2. Look for your Apple ID or developer account
3. Tap it
4. Tap **"Trust [Your Name]"**
5. Confirm trust
6. Reconnect to Xcode

### Issue: Xcode Says "Device Not Connected"

**Try:**
1. **Quit Xcode completely** (Cmd + Q)
2. **Unplug iPhone**
3. **Wait 10 seconds**
4. **Plug iPhone back in**
5. **Open Xcode again**
6. Wait for device to appear

### Issue: Device Appears But Can't Build

**Check:**
1. **iOS Version Compatibility**:
   - In Xcode: Project → Target → General
   - Check "Minimum Deployments" iOS version
   - Your iPhone's iOS version must be **equal to or higher** than this

2. **Code Signing**:
   - In Xcode: Project → Target → Signing & Capabilities
   - Make sure "Automatically manage signing" is checked
   - Select your **Team** (your Apple ID)
   - If you see errors, fix them

## Check iPhone Connection Status

### On Mac:
1. Open **Finder**
2. Look in the **sidebar** - do you see your iPhone listed?
3. If yes → iPhone is connected, issue is with Xcode
4. If no → iPhone connection issue (try different cable/port)

### On iPhone:
1. When connected, you should see a **battery icon** in status bar
2. If you see "Not Charging" → Try different cable/port
3. If you see charging icon → Connection is working

## Alternative: Wireless Debugging (iOS 16+)

If USB keeps failing, try wireless:

1. **First time setup (USB required):**
   - Connect iPhone via USB
   - In Xcode: Window → Devices and Simulators
   - Select your iPhone
   - Check **"Connect via network"**
   - Wait for it to connect

2. **After setup:**
   - iPhone and Mac must be on **same Wi-Fi network**
   - Unplug USB cable
   - In Xcode device list, your iPhone should appear with a **network icon**
   - Select it and run your app

## Still Not Working?

### Check These:
- [ ] iPhone is unlocked
- [ ] "Trust This Computer" was tapped
- [ ] Using original Apple USB cable
- [ ] Tried different USB port
- [ ] Restarted both iPhone and Mac
- [ ] Developer Mode enabled on iPhone (iOS 16+)
- [ ] Xcode is fully updated
- [ ] iPhone iOS version is compatible with deployment target

### Get More Info:
1. In Xcode: **Window → Devices and Simulators**
2. Select your iPhone
3. Look for **error messages** or **status information**
4. Share what you see there

## Quick Test: Is iPhone Detected by Mac?

1. Open **Finder** on Mac
2. Look in sidebar for your iPhone
3. If iPhone appears in Finder → Connection works, issue is Xcode
4. If iPhone doesn't appear in Finder → Connection issue (cable/port/driver)

## Common Error Messages

### "Could not find Developer Disk Image"
- Your Xcode version doesn't support your iPhone's iOS version
- **Fix**: Update Xcode to latest version

### "Device is locked"
- Unlock your iPhone and keep it unlocked

### "Device is busy"
- Another app (iTunes, Photos) is using the iPhone
- **Fix**: Quit other apps, disconnect/reconnect

### "This device is not registered"
- You need to register the device with your Apple Developer account
- **Fix**: In Xcode, select device → "Use for Development" → Sign in with Apple ID

