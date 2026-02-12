# Card Flip Specs Update

## Changes Made

### Problem
- Card backs in the garage were showing basic info (make/model/year/color) instead of vehicle specifications
- Specs needed to be fetched lazily when cards are flipped for the first time
- Specs should only be fetched once per unique make/model/year combination

### Solution

#### Updated ContentView.swift

**1. Card Back Display**
- Changed from basic DetailRow layout showing make/model/year/color
- Now displays FIFA-style stats matching CardDetailsView design:
  - HP (Horsepower)
  - TRQ (Torque)
  - 0-60 (0-60 mph time)
  - TOP (Top Speed)
  - ENGINE (Engine Type)
  - DRIVE (Drivetrain)

**2. Lazy Spec Fetching**
- Added `handleCardFlip()` method that checks if specs need to be fetched
- Only fetches if flipping to back AND specs are empty (horsepower/torque are nil)
- Uses CarSpecsService.shared.getSpecs() which:
  - Checks Firestore cache first (shared across all users)
  - Only calls AI if specs don't exist in Firestore
  - Saves generated specs to Firestore for future use

**3. State Management**
- Added `updatedCard` state to track card with fetched specs
- Added `isFetchingSpecs` state to show loading indicator
- Added `onSpecsUpdated` callback to propagate spec updates to parent view
- Updates saved cards array and persists to storage when specs are fetched

**4. Visual Enhancements**
- Loading indicator shows "Loading specs..." while fetching
- Stats are highlighted (white) when available, grayed out (???) when missing
- "Some specs unavailable" footer shows if incomplete
- Maintains flip animation with rotation3DEffect

## Technical Details

### Spec Caching Strategy
```
User flips card -> Check if specs exist in card.specs
                -> If missing: Fetch from CarSpecsService
                -> CarSpecsService checks Firestore first
                -> If not in Firestore: Call AI (VehicleIDService line 322)
                -> Save to Firestore for all users
                -> Update local card and save to storage
```

### Data Flow
```
CardDetailView (flip event)
    ↓
handleCardFlip()
    ↓
fetchSpecsIfNeeded()
    ↓
CarSpecsService.getSpecs()
    ↓
VehicleIDService.fetchSpecs() [line 322]
    ↓
Save to Firestore (docId: make_model_year)
    ↓
Update local SavedCard
    ↓
onSpecsUpdated callback
    ↓
Parent view updates & persists
```

### Backward Compatibility
- Cards created before this update will have empty specs
- Specs will be fetched on first flip
- No migration needed - works automatically

## Testing Checklist

- [ ] Flip existing cards - should fetch and display specs
- [ ] Flip same make/model/year multiple times - should NOT refetch (uses cache)
- [ ] Flip different cards - each unique car fetches once
- [ ] Check Firestore - specs should be saved with docId format: make_model_year
- [ ] Verify loading indicator appears during fetch
- [ ] Confirm card persists with specs after flip
- [ ] Test with cards that have missing specs (should show ???)

## Files Modified

- `Car Collector/Views/ContentView.swift` - Complete rewrite of card back display and spec fetching logic

## iOS Compatibility

- Xcode 16.0
- iOS 17.0+
- SwiftUI with async/await support
