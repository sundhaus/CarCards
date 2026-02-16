# Logo Setup Instructions

## Adding the Car Collector Logo to Your App

Follow these steps to add the new logo to your Xcode project:

### Step 1: Add Logo to Assets Catalog

1. Open your Xcode project
2. In the Project Navigator (left sidebar), find `Assets.xcassets`
3. Click on `Assets.xcassets` to open it
4. Right-click in the assets list and select **"New Image Set"**
5. Rename the new image set to **"AppLogo"** (must match exactly)
6. Drag and drop the `car_collector_logo.jpg` file into the **"Universal"** slot (or 1x slot)
7. The image should now appear in your Assets catalog

### Step 2: Update the Files

The following files have been updated and need to be added to your Xcode project:

1. **Car_CollectorApp.swift** - Updated launch screen to use the new logo
2. **LaunchScreenView.swift** - NEW file with the logo design (optional standalone view)

### Step 3: Add Files to Xcode

1. In Xcode, right-click on the "Car Collector" folder
2. Select "Add Files to 'Car Collector'..."
3. Add the updated **Car_CollectorApp.swift** (replace existing)
4. Optionally add **LaunchScreenView.swift** for a reusable launch screen component

### Step 4: Test the Logo

1. Build and run the app (⌘R)
2. You should see the blue logo appear on launch
3. The logo will show while Firebase is loading

### Color Information

The blue background color is: `Color(red: 0.22, green: 0.47, blue: 0.76)`
This matches the blue tone in your logo design.

### Troubleshooting

**If the logo doesn't appear:**
- Make sure the image set is named exactly **"AppLogo"** in Assets.xcassets
- Verify the image was dragged into the Universal/1x slot
- Clean build folder (⌘⇧K) and rebuild

**If you see "Image not found" error:**
- Check that Assets.xcassets is included in your target's resources
- Make sure the image name in code matches the asset name exactly
