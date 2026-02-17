# Explore Feature Implementation Guide

## ⚠️ IMPORTANT - Existing Cards

**Question:** Will category labeling only work with newly added cards?

**Answer:** Yes, by default only new cards will get categories. BUT we've included a **Category Migration Tool** that can backfill categories for all existing cards using AI.

**See "Backward Compatibility - Existing Cards" section below for the migration solution.**

---

## Overview
This feature adds an "Explore" page that shows cards grouped by vehicle category (Hypercar, SUV, Track, etc.). Cards are shown randomly and refresh every 3 hours at 12am, 3am, 6am, 9am, 12pm, 3pm, 6pm, and 9pm EST. Only cards with complete specs appear in Explore.

---

## Files Created

### 1. VehicleCategory.swift (New Model)
Location: `Car Collector/Models/VehicleCategory.swift`

**20 vehicle categories:**
- Performance: Hypercar, Supercar, Sports Car, Muscle, Track
- Off-Road: Off-Road, Rally, SUV, Truck, Van
- Luxury: Luxury, Sedan, Coupe, Convertible, Wagon
- Specialty: Electric, Hybrid, Classic, Concept, Hatchback

Each category has:
- `emoji`: Visual icon (🏎️, 🚙, etc.)
- `description`: Short description

### 2. CarSpecs.swift (Updated Model)
Location: `Car Collector/Models/CarSpecs.swift`

**NEW FIELD ADDED:**
```swift
let category: VehicleCategory?  // Vehicle category for Explore page
```

**Updated `isComplete` property:**
```swift
var isComplete: Bool {
    category != nil && horsepower != nil && torque != nil
}
```

Cards must have category + basic specs to appear in Explore.

### 3. ExploreService.swift (New Service)
Location: `Car Collector/Services/ExploreService.swift`

**Features:**
- Refreshes every 3 hours at: 12am, 3am, 6am, 9am, 12pm, 3pm, 6pm, 9pm EST
- Countdown timer showing time until next refresh
- Fetches 20 random cards per category
- Only shows cards with complete specs (category + HP + torque)
- Real-time updates with Firestore listeners

**Key Methods:**
- `fetchCardsIfNeeded()`: Checks schedule and fetches if needed
- `forceRefresh()`: Immediate refresh
- `nextRefreshTime()`: Calculates next refresh time
- `formatCountdown()`: Formats countdown timer

### 4. ExploreView.swift (New View)
Location: `Car Collector/Views/ExploreView.swift`

**UI Structure:**
```
┌─────────────────────────────────────┐
│ ← Explore    Next refresh: 2h 15m  │
├─────────────────────────────────────┤
│ 🏎️ Hypercar                        │
│ Ultimate performance machines   12  │
│ ┌──┐ ┌──┐ ┌──┐ ┌──┐ → →         │
│ └──┘ └──┘ └──┘ └──┘              │
├─────────────────────────────────────┤
│ 🚙 SUV                             │
│ Sport utility vehicles          8   │
│ ┌──┐ ┌──┐ ┌──┐ → → →            │
│ └──┘ └──┘ └──┘                   │
└─────────────────────────────────────┘
```

**Features:**
- Vertical scroll of category rows
- Horizontal scroll within each row
- Tap card to view owner's profile
- Shows heat count (🔥) on cards
- Empty state if no cards with specs
- Loading state during fetch

### 5. HomeView.swift (Updated)
Location: `Car Collector/Views/HomeView.swift`

**Changes:**
- Added `@State private var showExplore = false`
- Wrapped HotCardsCarousel in Button to open Explore
- Added `.navigationDestination(isPresented: $showExplore)`
- Updated navigation reset logic to include `showExplore`

**User Flow:**
Home → Tap "Featured Collections" → Opens Explore page

---

## Additional Changes Needed

### A. Update VehicleIdentificationService.swift

**1. Update VehicleSpecs struct:**
```swift
struct VehicleSpecs: Codable {
    let engine: String
    let horsepower: String
    let torque: String
    let zeroToSixty: String
    let topSpeed: String
    let transmission: String
    let drivetrain: String
    let description: String
    let category: String  // NEW: Vehicle category
    
    // Metadata
    let fetchedAt: Date
    let fetchedBy: String?
}
```

**2. Update AI prompt in `fetchSpecs()` method:**

Add to the prompt:
```swift
let prompt = """
Generate specifications AND category for \(year) \(make) \(model):

Return JSON:
{
    "engine": "...",
    "horsepower": "...",
    "torque": "...",
    "zeroToSixty": "...",
    "topSpeed": "...",
    "transmission": "...",
    "drivetrain": "...",
    "description": "...",
    "category": "..."  // NEW FIELD
}

CATEGORY must be ONE of these (exact match):
Hypercar, Supercar, Sports Car, Muscle, Track,
Off-Road, Rally, SUV, Truck, Van,
Luxury, Sedan, Coupe, Convertible, Wagon,
Electric, Hybrid, Classic, Concept, Hatchback

Choose the MOST SPECIFIC category. Examples:
- Ferrari SF90 → "Hypercar"
- Porsche 911 GT3 → "Track"
- Ford Bronco → "Off-Road"
- Toyota Camry → "Sedan"
- Tesla Model S → "Electric"
- Jeep Wrangler → "Off-Road"
- Ford F-150 Raptor → "Truck"

Use "N/A" for unknown specs.
"""
```

### B. Update FriendActivity Model

**Location:** Find where `FriendActivity` is defined (likely in `Car Collector/Models/` or `Car Collector/Firestore/`)

**Add field:**
```swift
struct FriendActivity: Identifiable, Codable {
    // ... existing fields ...
    let category: String?  // NEW: Vehicle category
    
    // Update init from Firestore document:
    init?(document: DocumentSnapshot) {
        // ... existing code ...
        self.category = data["category"] as? String
    }
}
```

### C. Update Card Saving Process

**When saving cards to Firestore** (in CardService or where friend_activities are created):

Add category to the document:
```swift
var cardData: [String: Any] = [
    // ... existing fields ...
    "category": specs.category ?? ""  // Add this
]

try await db.collection("friend_activities").document(activityId).setData(cardData)
```

### D. Update CarSpecsService.swift

**In `convertToCarSpecs()` method:**

```swift
private func convertToCarSpecs(_ vehicleSpecs: VehicleSpecs) -> CarSpecs {
    // ... existing parsing code ...
    
    // Parse category
    let category = VehicleCategory(rawValue: vehicleSpecs.category)
    
    return CarSpecs(
        horsepower: hp,
        torque: tq,
        zeroToSixty: zts,
        topSpeed: ts,
        engineType: vehicleSpecs.engine != "N/A" ? vehicleSpecs.engine : nil,
        displacement: displacement,
        transmission: vehicleSpecs.transmission != "N/A" ? vehicleSpecs.transmission : nil,
        drivetrain: vehicleSpecs.drivetrain != "N/A" ? vehicleSpecs.drivetrain : nil,
        category: category  // NEW
    )
}
```

---

## Backward Compatibility - Existing Cards

### The Problem

**Yes, category labeling will only work with newly added cards by default.** Existing cards in Firestore won't have the `category` field and won't appear in Explore.

### The Solution - Category Migration

We've created a migration system to backfill categories for all existing cards.

#### Files for Migration:

**1. CategoryMigrationService.swift (New Service)**
Location: `Car Collector/Services/CategoryMigrationService.swift`

**Features:**
- Scans all friend_activities in Firestore
- Uses AI to determine category for each card
- Updates Firestore documents with category field
- Skips cards that already have categories
- Shows progress (processed, categorized, skipped)
- Includes rate limiting to avoid API throttling

**2. CategoryMigrationView.swift (New Admin View)**
Location: `Car Collector/Views/CategoryMigrationView.swift`

**Features:**
- Clean UI to run migration
- Progress bar and statistics
- Time estimate
- Can be added to Settings or as hidden admin tool

### How to Use Migration:

**Option A: Add to Settings**
Add a button in your Settings/Profile view:

```swift
// In ProfileView or SettingsView
Button("Run Category Migration") {
    showMigration = true
}
.sheet(isPresented: $showMigration) {
    CategoryMigrationView()
}
```

**Option B: Hidden Admin Access**
Add a hidden gesture in HomeView:

```swift
// In HomeView, add to the header or logo
Text("Explore")
    .onTapGesture(count: 5) { // 5 taps
        showMigration = true
    }
```

**Option C: Run Once Programmatically**
In your App struct or root view:

```swift
.task {
    // Run migration on first launch after update
    if !UserDefaults.standard.bool(forKey: "categoryMigrationDone") {
        let service = CategoryMigrationService()
        await service.migrateMissingCategories()
        UserDefaults.standard.set(true, forKey: "categoryMigrationDone")
    }
}
```

### Migration Process:

1. **Scans all cards** in friend_activities collection
2. **For each card without a category:**
   - Gets make, model, year
   - Asks AI to categorize it
   - Updates Firestore with category
3. **Skips cards that:**
   - Already have a category
   - Missing required data (make/model/year)
4. **Shows progress:**
   - Total cards
   - Processed count
   - Categorized count
   - Skipped count
   - Time estimate

### Performance:

- **Speed:** ~0.5 seconds per card (AI call + small delay)
- **100 cards:** ~1 minute
- **1000 cards:** ~8-10 minutes
- **Rate limiting:** Built-in 0.5s delay between calls

### Important Notes:

✅ **Safe to run multiple times** - Skips already-categorized cards
✅ **Non-destructive** - Only adds category field, doesn't change existing data
✅ **Incremental** - Can be stopped and resumed (skips already-done cards)
⚠️ **Requires AI quota** - Each uncategorized card uses one AI call
⚠️ **Takes time** - For large databases, consider running during off-peak hours

---

## Firestore Structure Changes

### friend_activities Collection

**New field to add:**
```
{
  ...existing fields...,
  "category": "Supercar"  // String matching VehicleCategory rawValue
}
```

### Firestore Index Needed

Create composite index for efficient category queries:
```
Collection: friend_activities
Fields: 
  - category (Ascending)
  - heatCount (Descending)
```

---

## Testing Checklist

**Core Features:**
- [ ] VehicleCategory enum compiles with all 20 categories
- [ ] CarSpecs includes category field
- [ ] AI prompt returns valid category in specs
- [ ] ExploreService fetches cards by category
- [ ] ExploreService countdown timer works
- [ ] ExploreService refreshes at 12am, 3am, 6am, 9am, 12pm, 3pm, 6pm, 9pm EST
- [ ] ExploreView displays category rows
- [ ] Cards without specs don't appear in Explore
- [ ] Tapping Featured Collections opens Explore
- [ ] Tapping card in Explore opens user profile
- [ ] Empty state shows when no cards have specs
- [ ] Loading state shows during fetch
- [ ] Navigation back works correctly

**Migration (for existing cards):**
- [ ] CategoryMigrationService compiles
- [ ] CategoryMigrationView displays correctly
- [ ] Can run migration from UI
- [ ] Progress updates during migration
- [ ] AI correctly categorizes sample cards
- [ ] Firestore updates with categories
- [ ] Cards already with categories are skipped
- [ ] After migration, existing cards appear in Explore

---

## User Experience Flow

1. **Home Page:**
   - See "Featured Collections" carousel at top
   - Shows top heat cards (existing)
   
2. **Tap Featured Collections:**
   - Opens Explore page
   - Shows countdown: "Next refresh: 2h 15m"
   
3. **Explore Page:**
   - Vertical scroll of categories
   - Each category: emoji + name + description + count
   - Horizontal scroll of 20 random cards per category
   - Only shows categories that have cards with specs
   
4. **Tap a Card:**
   - Opens that user's profile
   - Can view their full collection
   
5. **Refresh Schedule:**
   - 12:00 AM EST (midnight) → New random cards
   - 3:00 AM EST → New random cards
   - 6:00 AM EST → New random cards
   - 9:00 AM EST → New random cards
   - 12:00 PM EST (noon) → New random cards
   - 3:00 PM EST → New random cards
   - 6:00 PM EST → New random cards
   - 9:00 PM EST → New random cards
   - (Repeats every 3 hours, 24/7)

---

## Technical Notes

**Why every 3 hours?**
- Creates anticipation (users check back periodically)
- Reduces server load vs continuous updates
- Fixed times create predictable "drop" moments
- 8 refreshes per day (every 3 hours around the clock)
- Covers all time zones with regular updates

**Why only cards with specs?**
- Ensures quality content in Explore
- Incentivizes users to flip cards and get specs
- Creates progression: capture → flip → explore

**Category determination:**
- AI analyzes make, model, specs
- Chooses most specific category
- Examples:
  - Bugatti Chiron → Hypercar (not just Supercar)
  - Porsche 911 GT3 RS → Track (not just Sports Car)
  - Ford F-150 Raptor → Truck (not Off-Road, though capable)

**Performance:**
- Firestore queries are indexed
- Images lazy load as user scrolls
- 20 cards per category balances variety and load time
- Random selection from larger pool ensures variety

---

## Future Enhancements (Optional)

1. **Filtering:**
   - Filter by era (Classic, Modern)
   - Filter by price range
   - Filter by country of origin

2. **Search:**
   - Search within categories
   - Search across all Explore cards

3. **Favorites:**
   - Save favorite categories
   - Get notified when new cards appear

4. **Statistics:**
   - Most popular category this cycle
   - Trending cards (heat increase)

5. **Personalization:**
   - Show categories based on user's collection
   - Recommend similar cars
