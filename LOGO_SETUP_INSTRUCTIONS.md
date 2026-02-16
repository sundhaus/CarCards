# Logo Setup Instructions - Complete Guide

## Overview
This guide will help you set up:
1. **App Icon** - The icon that appears on the iPhone home screen
2. **Launch Screen Logo** - The logo that appears when the app boots up

The blue background color has been matched exactly to your logo: **#1F5AB5** (RGB: 31, 90, 181)

---

## Part 1: Setting Up the App Icon (Home Screen Icon)

### Step 1: Open AppIcon in Assets
1. Open your Xcode project
2. In the left sidebar (Project Navigator), find and click on **Assets.xcassets**
3. In the asset list, click on **AppIcon**

### Step 2: Add Your Logo
1. You should see a grid with different icon sizes (iPhone, iPad, etc.)
2. Find the **1024x1024** slot (usually labeled "App Store iOS")
3. Drag and drop `car_collector_logo.jpg` into this 1024x1024 slot
4. Xcode should automatically generate the other sizes
   - If it doesn't, you can drag the same image into each iPhone slot

### Step 3: Verify
- You should now see your logo in multiple size slots
- The icon will appear on your iPhone home screen when you build the app

---

## Part 2: Setting Up the Launch Screen Logo

### Step 1: Create AppLogo Image Set
1. Still in **Assets.xcassets**, right-click in the asset list (left panel)
2. Select **"New Image Set"**
3. Rename it to exactly **"AppLogo"** (case-sensitive, no spaces)
   - Click on the image set name and press Enter to rename

### Step 2: Add Logo to AppLogo
1. Click on the **AppLogo** image set you just created
2. Drag and drop `car_collector_logo.jpg` into the **"Universal"** slot (or "Any Width" / "1x" slot)
3. The image should now appear in the asset

### Step 3: Verify the Code is Updated
The following files reference "AppLogo" and use the exact blue color:
- ✅ **Car_CollectorApp.swift** - Launch screen color: `Color(red: 0.122, green: 0.353, blue: 0.710)`
- ✅ **LaunchScreenView.swift** - Same blue color

---

## Testing

### Test the App Icon
1. Build and run on your device or simulator (⌘R)
2. Go to the home screen
3. Look for the Car Collector icon - it should show your wheel/camera logo

### Test the Launch Screen
1. Close the app completely (swipe up from bottom)
2. Tap the app icon to launch
3. You should see:
   - Seamless blue background (#1F5AB5)
   - Your wheel/camera logo centered
   - White loading spinner below

---

## Troubleshooting

### "AppLogo" image not found
**Problem:** Launch screen shows nothing or error
**Solution:** 
- Make sure the image set is named exactly **"AppLogo"** (capital A, capital L)
- Verify the image is in the Universal slot
- Clean build folder: **Product** → **Clean Build Folder** (⇧⌘K)
- Rebuild

### App icon not showing
**Problem:** Default icon still appears
**Solution:**
- Make sure `car_collector_logo.jpg` is in the **1024x1024** slot in **AppIcon**
- Delete the app from your device/simulator
- Rebuild and reinstall

### Blue color doesn't match
**Problem:** Background blue looks different from logo
**Solution:**
- The exact color is: `Color(red: 0.122, green: 0.353, blue: 0.710)` or Hex: `#1F5AB5`
- This was extracted directly from your logo file
- Make sure you're using the updated Car_CollectorApp.swift file

### Icon looks blurry
**Problem:** App icon appears pixelated
**Solution:**
- Make sure you're using the original 1024x1024 JPG file
- The image should be sharp and high-resolution

---

## Quick Reference

**Asset Names:**
- App Icon Asset: **AppIcon** (already exists in Xcode)
- Launch Screen Asset: **AppLogo** (you need to create this)

**Image File:**
- File: `car_collector_logo.jpg`
- Size: 1024x1024 pixels
- Use for both AppIcon and AppLogo

**Blue Color:**
- RGB: (31, 90, 181)
- Hex: #1F5AB5
- SwiftUI: `Color(red: 0.122, green: 0.353, blue: 0.710)`

---

## Success Checklist

- [ ] `car_collector_logo.jpg` added to **AppIcon** in Assets.xcassets (1024x1024 slot)
- [ ] Created **AppLogo** image set in Assets.xcassets
- [ ] `car_collector_logo.jpg` added to **AppLogo** (Universal slot)
- [ ] Updated **Car_CollectorApp.swift** in Xcode
- [ ] Clean build (⇧⌘K) and rebuild
- [ ] App icon shows on home screen
- [ ] Launch screen shows logo with seamless blue background
