# Live Activity Setup Instructions

## Files Created

All code files have been created! Now you need to add them to the correct Xcode targets.

## Step 1: Add Shared Files to BOTH Targets

The following files need to be added to **BOTH** the main app AND the widget extension:

### Shared Models & Extensions
1. `Fuckify/Shared/LiveActivity/PartnerData.swift`
2. `Fuckify/Shared/LiveActivity/EncounterActivityAttributes.swift`
3. `Fuckify/Extensions/String+Initials.swift` (already exists, add to widget)
4. `Fuckify/Extensions/Color+Partner.swift` (already exists, add to widget)
5. `Fuckify/Extensions/PartnerColors.swift` (already exists, add to widget)
6. `Fuckify/Encounter/EncounterFormView.swift` - specifically the `FlowLayout` struct (already exists, add to widget)

### How to Add Files to Both Targets:

For each file above:
1. Right-click the file in Xcode's Project Navigator
2. Select "Show File Inspector" (or press ⌥⌘1)
3. In the "Target Membership" section, check BOTH:
   - ☑️ **Fuckify** (main app)
   - ☑️ **EncounterActivityWidget** (widget extension)

## Step 2: Add Main App-Only Files

These files should ONLY be in the **Fuckify** target:

1. `Fuckify/Shared/LiveActivity/LiveActivityManager.swift`
2. `Fuckify/Encounter/LiveActivityPartnerSelector.swift`
3. `Fuckify/Encounter/ActiveEncounterView.swift`
4. `Fuckify/Partner/PartnerQuickFormView.swift`

### How to Add:
1. In Xcode, right-click on the appropriate folder
2. Select "Add Files to Fuckify..."
3. Navigate to and select the file
4. Ensure ONLY **Fuckify** target is checked

## Step 3: Add Widget Extension-Only Files

These files should ONLY be in the **EncounterActivityWidget** target:

1. `EncounterActivityWidget/Views/TimerDisplayView.swift`
2. `EncounterActivityWidget/Views/LiveActivityPartnerChipView.swift`
3. `EncounterActivityWidget/EncounterActivityWidgetLiveActivity.swift` (already exists, just verify)

### How to Add:
1. In Xcode, right-click on "EncounterActivityWidget" folder
2. Select "Add Files to Fuckify..."
3. Navigate to and select the file
4. Ensure ONLY **EncounterActivityWidget** target is checked

## Step 4: Verify Info.plist Settings

### Main App Info.plist (`Fuckify/Info.plist`)
Ensure it contains:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

### Widget Extension Info.plist (`EncounterActivityWidget/Info.plist`)
Ensure it contains:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

## Step 5: Add URL Scheme for Deep Linking

1. Select the **Fuckify** project in Project Navigator
2. Select the **Fuckify** target
3. Go to the **Info** tab
4. Expand **URL Types**
5. Click **+** to add a new URL Type
6. Configure:
   - **Identifier**: `com.fuckify.deeplink`
   - **URL Schemes**: `coitalcomrade`
   - **Role**: Editor

## Step 6: Build Order (Important!)

Build in this order to avoid errors:

1. **First**: Select **EncounterActivityWidget** scheme
   - Product → Build (⌘B)
   - Fix any build errors

2. **Second**: Select **Fuckify** scheme
   - Product → Build (⌘B)
   - Fix any build errors

## Step 7: Fix Potential Import Issues

If you see "Cannot find X in scope" errors:

### For Widget Extension:
The widget needs these extensions to work. Make sure these are added to the widget target:

- `String+Initials.swift`
- `Color+Partner.swift`
- `PartnerColors.swift`

### For FlowLayout:
You have two options:

**Option A: Share FlowLayout (Recommended)**
1. Copy the `FlowLayout` struct from `EncounterFormView.swift`
2. Create a new file: `Fuckify/Shared/UI/FlowLayout.swift`
3. Add it to BOTH targets
4. Remove duplicate from `EncounterFormView.swift`

**Option B: Duplicate in Widget**
1. Copy the `FlowLayout` struct into the widget's views file
2. Keep it in both places

## Step 8: Test Builds

### Test Widget Extension:
```bash
# From project root
xcodebuild -project Fuckify.xcodeproj -scheme EncounterActivityWidget -configuration Debug build
```

### Test Main App:
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build
```

## Common Build Errors & Fixes

### Error: "No such module 'SQLiteData'"
**Cause**: Widget extension doesn't need SQLiteData, but some files reference it
**Fix**: Make sure database-related files (SQLPartner, SQLEncounter, etc.) are NOT in the widget target

### Error: "Cannot find 'PartnerData' in scope" (in Widget)
**Fix**: Add `PartnerData.swift` to EncounterActivityWidget target

### Error: "Cannot find 'EncounterActivityAttributes' in scope" (in Widget)
**Fix**: Add `EncounterActivityAttributes.swift` to EncounterActivityWidget target

### Error: "Cannot find 'FlowLayout' in scope" (in ActiveEncounterView)
**Fix**: Add `EncounterFormView.swift` to widget target OR extract FlowLayout to shared file

### Error: "Type 'Color' has no member 'fromPartnerColorName'"
**Fix**: Add `Color+Partner.swift` to the widget target

### Error: "Value of type 'String' has no member 'initials'"
**Fix**: Add `String+Initials.swift` to the widget target

## Step 9: Running the App

### On Simulator:
1. Select **Fuckify** scheme
2. Choose an iOS 18+ simulator (Live Activities require iOS 16.1+, Dynamic Island requires iPhone 14 Pro or newer)
3. Run (⌘R)

### Testing Live Activity:
1. Launch the app
2. Tap the **+** button in Calendar view
3. Select **"Start Live Tracking"**
4. Select partners
5. Tap **"Start Tracking"**
6. Look for:
   - Dynamic Island (on iPhone 14 Pro+)
   - Lock screen notification
   - Tap it to open the app

### Testing on Device:
Live Activities work best on physical devices. To test:
1. Connect your iPhone
2. Select your device in Xcode
3. Run the app
4. Start a Live Activity
5. Lock your phone to see the lock screen view
6. Long-press Dynamic Island (iPhone 14 Pro+) to see expanded view

## Troubleshooting

### Live Activity doesn't appear:
1. Check that notification permissions are granted
2. Verify both Info.plist files have `NSSupportsLiveActivities`
3. Check console for error messages
4. Try restarting the app

### Deep link doesn't work:
1. Verify URL scheme is added to Info.plist
2. Test with: `xcrun simctl openurl booted "coitalcomrade://active-encounter"`
3. Check `handleDeepLink` function is being called

### Widget shows "No preview available":
1. Ensure all shared files are in widget target
2. Check for build errors in widget scheme
3. Clean build folder (⇧⌘K) and rebuild

## Next Steps After Setup

Once everything builds successfully:

1. **Test the flow**:
   - Start a Live Activity
   - Pause/Resume
   - Finish and verify encounter is created
   - Check that edit form opens

2. **Test edge cases**:
   - Background the app with active Live Activity
   - Kill the app and reopen (Live Activity should persist)
   - Test with 1 partner, 3 partners, 5+ partners

3. **Polish** (optional):
   - Adjust colors/fonts
   - Test accessibility
   - Add haptic feedback
   - Improve error messages

## Files Summary

### Created Files:
- ✅ `Fuckify/Shared/LiveActivity/PartnerData.swift`
- ✅ `Fuckify/Shared/LiveActivity/EncounterActivityAttributes.swift`
- ✅ `Fuckify/Shared/LiveActivity/LiveActivityManager.swift`
- ✅ `Fuckify/Encounter/LiveActivityPartnerSelector.swift`
- ✅ `Fuckify/Encounter/ActiveEncounterView.swift`
- ✅ `Fuckify/Partner/PartnerQuickFormView.swift`
- ✅ `EncounterActivityWidget/Views/TimerDisplayView.swift`
- ✅ `EncounterActivityWidget/Views/LiveActivityPartnerChipView.swift`
- ✅ `EncounterActivityWidget/EncounterActivityWidgetLiveActivity.swift` (replaced template)

### Modified Files:
- ✅ `Fuckify/Encounter/CalendarView.swift` - Added menu and Live Activity sheet
- ✅ `Fuckify/ContentView.swift` - Added ActiveEncounterView sheet
- ✅ `Fuckify/FuckifyApp.swift` - Added deep linking and finish flow

Ready to build! 🚀
