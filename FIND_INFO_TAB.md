# How to Find the Info Tab in Xcode

## Step-by-Step Instructions

### You're Currently On:
- You're looking at the **"General"** tab (I can see it in your screenshot)
- The Info tab is right next to it!

### Steps to Find Info Tab:

1. **Look at the top of the right pane** (where you see "General" tab)
2. **You'll see several tabs in a row**, like:
   - General | **Info** | Build Settings | Build Phases | Build Rules | Signing & Capabilities
3. **Click on "Info"** (it's the second tab, right after "General")

### Visual Guide:

```
┌─────────────────────────────────────────┐
│ General | Info | Build Settings | ...  │ ← Click "Info" here!
├─────────────────────────────────────────┤
│                                         │
│  (Your Info.plist keys will be here)   │
│                                         │
└─────────────────────────────────────────┘
```

## Alternative: If You Don't See Info Tab

Some Xcode versions use a different layout. Try this:

### Method 1: Check if Info.plist File Exists

1. In the **left sidebar** (Project Navigator), look for a file called:
   - `Info.plist`
   - OR `Calenda Notes-Info.plist`
   - OR it might be inside a folder

2. **If you find it:**
   - Click on the `Info.plist` file
   - It will open in the editor
   - You can add keys directly there

3. **If you DON'T find it:**
   - Your project might be using "Generate Info.plist File" (modern Xcode)
   - In that case, use Method 2 below

### Method 2: Add Keys via Build Settings

1. **Stay on the "General" tab** (where you are now)
2. Scroll down to find **"Info"** section
3. OR click the **"Info" tab** at the top (next to General)

### Method 3: Use the Info Tab (Recommended)

1. At the **top of the editor area** (right pane), you'll see tabs
2. Click **"Info"** (it's right next to "General")
3. You should see a list of keys with "+" and "-" buttons
4. Click the **"+"** button to add new keys

## What You Should See in Info Tab

Once you click "Info", you should see:

- A list of keys (like a table/spreadsheet)
- Columns for: Key | Type | Value
- A **"+"** button (usually top-left of the keys list)
- Existing keys might include things like:
  - Bundle name
  - Bundle identifier
  - etc.

## If Info Tab is Missing Completely

This might mean your project uses a different Info.plist setup:

1. **Check Build Settings:**
   - Click **"Build Settings"** tab
   - Search for "Info.plist" in the search box
   - Look for "INFOPLIST_FILE" setting

2. **Or create Info.plist manually:**
   - Right-click on "Calenda Notes" folder in Project Navigator
   - New File → Property List
   - Name it "Info.plist"
   - Add it to your target

## Quick Visual Check

Look at the **very top of the right pane** where you see:
- "Calenda Notes" (title)
- Then tabs: **General** | **Info** | Build Settings | ...

The **Info** tab should be visible there. If it's not, your Xcode version might be different.

## Still Can't Find It?

Try this:
1. **Click "Build Settings"** tab
2. In the search box, type: `Info.plist`
3. Look for settings related to Info.plist
4. OR tell me what tabs you DO see, and I'll guide you from there

The Info tab should be right there next to General - it's a standard Xcode tab!

