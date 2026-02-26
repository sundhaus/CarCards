# HeatCheck — Gamification & UX Audit

**Date:** February 26, 2026  
**Scope:** Full codebase review of Car Collector / HeatCheck iOS app  
**Perspective:** AAA mobile game design, user retention, and monetization

---

## Executive Summary

HeatCheck has a solid technical foundation — Firebase sync works, the camera pipeline is functional, card flattening solves real problems, and the H2H voting system is genuinely interesting. But the app currently feels like an **engineering prototype wearing a game's clothes**, not a polished collectible experience. The core loop (capture → collect → trade → battle) exists structurally but lacks the emotional payoff, visual spectacle, and compulsive micro-loops that drive retention in successful card games.

The biggest risks to retention are:

1. **The capture-to-reward moment is invisible** — no pack-opening ceremony, no rarity reveal animation, no "holy shit" moment
2. **The Home screen is a menu, not a destination** — there's nothing to DO there, nothing dynamic, nothing that pulls you back
3. **Currencies exist but have no emotional weight** — coins and gems are numbers going up with no satisfying spend loops
4. **The collection has no shape** — there's no completion drive, no sets, no "just one more" mechanic
5. **Visual consistency is fragile** — each page feels like a different app, with background treatments, header styles, and card presentations varying widely

Below is a full breakdown organized by system, with specific diagnosis and recommended fixes.

---

## 1. THE CORE LOOP: Capture → Card → Collect → Compete

### What works
- AI vehicle identification is genuinely magical — this is the app's superpower
- LiDAR anti-cheat is clever and defensible
- Three card types (vehicle, driver, location) add variety
- The card-flip mechanic on detail view is satisfying

### What's broken

**1.1 — No "Pack Opening" Moment**

This is the single biggest missed opportunity in the entire app. In every successful card game (Pokémon TCG, FIFA Ultimate Team, Marvel Snap), the moment of reveal is the ENTIRE game. It's what gets shared on TikTok, what creates FOMO, what makes people come back.

Currently: You take a photo → AI identifies the car → card silently appears in your garage. The `handleCardSaved()` function in `ContentView.swift` just appends to an array and navigates to the Garage tab. There is no ceremony.

**What should happen:** After capture + AI identification, a full-screen "card reveal" sequence:
- Card slides in face-down with glow matching its rarity color
- User taps/swipes to flip
- Rarity tier explodes with particles (Common = subtle shimmer, Legendary = screen-shaking golden burst)
- Stats cascade in one by one (HP, 0-60, etc.) like FIFA card reveals
- XP and coin awards animate in with satisfying counters
- "NEW" badge if it's a make/model they haven't captured before
- Share button appears immediately while excitement is highest

**1.2 — No First-Capture Guidance**

`OnboardingView.swift` only collects a username. There's no tutorial capture, no "here's what a great card looks like" moment, no guided first experience. A new user lands on the Home screen with zero cards and no idea what they should be excited about.

**Recommendation:** After username creation, walk the user through a single guided capture (even against a demo image if no car is nearby). Show them the full reveal sequence. Give them a guaranteed Rare starter card. THEN drop them on Home.

**1.3 — Capture Landing Page is a Dead-End Menu**

`CaptureLandingView.swift` shows three buttons (Vehicle, Driver, Location) against a blurred background. It's functional but generates zero excitement. There's no:
- Daily capture challenge ("Capture a red car today for 2x XP")
- Streak counter for consecutive-day captures
- "Hot" cars nearby or trending makes
- Progress toward any goal

---

## 2. HOME SCREEN — The Hub Problem

### Current state
`HomeView.swift` renders 5 glass containers (Leaderboard, Friends, Featured Collections, Head to Head, Transfer List) as equal-weight tiles with system icons. It looks like a settings page, not the landing screen of a game.

### Problems

**2.1 — No Dynamic Content**

The Home screen is 100% static navigation. Nothing on it changes between sessions. Compare to:
- Clash Royale: chest timers, donation requests, clan activity, season pass progress
- Marvel Snap: daily/weekly missions, season progress, new card spotlight
- FIFA Ultimate Team: squad rating, match rewards, market alerts

**2.2 — No "What Should I Do Next?" Signal**

There's no prioritized call-to-action. A returning user sees 5 equal buttons and has to decide what to care about. The app should answer the question "What's the most exciting thing I could do right now?"

**2.3 — HomeContainer Visual Design**

`HomeContainer.swift` uses a gradient circle with a system icon + label. This is visually generic. Every tile looks the same weight and importance. The `FeaturedCollectionsContainer` is slightly different but still just a glass card with text.

### Recommendations

- **Add a "hero slot"** at the top: dynamically shows the most relevant action (unclaimed daily reward, active H2H battle, marketplace offer on your card, new follower)
- **Show your crown card** prominently — this is your identity, it should be visible
- **Add a missions/challenges panel** with progress bars (see Section 6)
- **Inject live data into tiles**: H2H should show active battle count and a preview card, Friends should show recent activity count, Market should show trending price
- **Replace system icons with custom illustrations or card art** from the user's own collection where possible

---

## 3. THE COLLECTION EXPERIENCE (Garage)

### Current state
`GarageView.swift` shows a paginated grid of card thumbnails (1x or 2x columns) with a context menu for customize/options. Functional but flat.

### Problems

**3.1 — No Collection "Shape"**

There are no sets, no completion targets, no visible gaps. The Garage is a bag of cards with no structure beyond chronological order. This means there's no "I'm 8/10 on Italian Supercars" feeling — no hunt, no near-miss excitement.

**3.2 — No Rarity Distribution Visibility**

Users can't see at a glance what their collection looks like — how many Commons vs. Legendaries. There's no "collection book" showing what % of makes/models they've found.

**3.3 — Sorting & Filtering is Limited**

The Garage has a search and a 1x/2x toggle. There's no filter by rarity, make, category, date captured, H2H record, etc.

### Recommendations

- **Implement a "Collection Book"** — a Pokédex-style grid showing all possible vehicle categories/makes with silhouettes for uncaptured cars. Completion percentages per category drive the "gotta catch 'em all" impulse.
- **Add rarity breakdown** — a simple pie chart or badge strip at the top showing distribution
- **Category tabs or filters** — at minimum: By Rarity, By Make, By Category, By Date
- **Collection milestone rewards** — "Complete 5 Italian Supercars" → exclusive border unlock. This gives PURPOSE to capturing.
- **"Crown Card" showcase** — dedicated display area, not just a context menu option

---

## 4. HEAD-TO-HEAD SYSTEM — Strongest Feature, Underserved

### Current state
`HeadToHeadView.swift` (2713 lines!) is the most complex view in the app. It implements a drag-race themed voting system where community members vote on card matchups. This includes solo 1v1, duo 2v2, race timers, and winner celebrations.

### What works
- The core "vote on which car wins" mechanic is inherently engaging
- Duo battles add a social layer
- Evolution points from battles tie into the upgrade system
- The drag strip visual theme is unique

### Problems

**4.1 — Passive Engagement Only**

Users submit a card and then... wait. There's no notification when their card is in a live race. The result appears silently in history. The emotional peak (seeing your car win/lose) happens without the user present.

**4.2 — No Matchmaking Drama**

Cards are matched somewhat randomly. There's no ELO, no skill-based matching, no "your Common Civic somehow beat a Legendary McLaren" upset narrative. The outcome is purely popular vote, which means rare/pretty cars always win and Common cards are dead weight in battle.

**4.3 — Stats Don't Matter**

Vehicle specs (HP, torque, 0-60) are displayed but don't influence voting or outcomes in any way. They're flavor text. This is a huge missed opportunity — stat-based battles would give every card meaningful differentiated value and make upgrade decisions strategic.

### Recommendations

- **Push notifications for live battles** — "Your 2024 GT3 RS is in a race right now! 47 votes so far."
- **Implement stat-influenced scoring** — add a "spec bonus" layer where a stat advantage (e.g., faster 0-60) gives a small vote multiplier. This makes upgrading feel meaningful.
- **Add weight classes** — Common vs. Common, Epic vs. Epic. Removes the "Legendary always wins" problem and makes every rarity tier competitive.
- **Battle pass/season system** — weekly H2H seasons with ranked tiers and end-of-season rewards. This alone could be the #1 retention driver.
- **Show opponents' stats before voting** — make it a decision, not just a beauty contest

---

## 5. MONETIZATION & ECONOMY

### Current state
Two currencies: Coins (earned freely) and Gems (primarily purchased via IAP). Gems are used for instant rarity upgrades. Coins are used in the marketplace. `ShopView.swift` shows gem packs with bonus percentages.

### Problems

**5.1 — Gem Spend Sinks Are Too Narrow**

Gems currently do one thing: instant rarity upgrades. That's it. If a user doesn't care about upgrading a specific card right now, gems have zero value. Compare to successful games where premium currency unlocks cosmetics, battle pass, exclusive packs, name changes, storage upgrades, etc.

**5.2 — Coins Accumulate Without Purpose**

From `RewardConfig.swift`: daily login gives 10 coins, captures give 5-75. Quick sell gives 50-1000. But what can users spend coins on? The marketplace — but that requires OTHER users to list cards. In a low-population app, coins just pile up with nowhere to go.

**5.3 — The Shop is Just a Price List**

`ShopView.swift` is a vertical list of gem packs. There's no:
- Limited-time offers creating urgency
- Starter bundles for new players
- Daily rotating deals
- "First purchase" double gems bonus
- Subscription/battle pass option

**5.4 — Quick Sell is Too Generous**

A Common quick-sells for 50 coins, but a Common capture only earns 5 coins. This means a user can capture one card and quick-sell it for 10x the capture reward. This breaks the economy — there's no reason to hold Commons.

### Recommendations

- **Add gem-exclusive cosmetics** — special card borders, animated effects, profile frames, unique card backs. These are the #1 revenue driver in every successful card game.
- **Implement a Battle Pass / Season Pass** — free and premium tracks, XP-driven progression, exclusive rewards. $4.99-9.99/month. This is your recurring revenue foundation.
- **Create coin sinks** — card storage upgrades, re-rolls on AI identification, marketplace listing fees, custom garage sorting slots
- **Add a "Daily Deal"** — one discounted gem pack per day, rotates. Creates a habit loop.
- **Rebalance quick sell** — Common should be 10-15 coins, not 50. Or make quick-sell return a "scrap" currency that can be combined into random packs.
- **First purchase bonus** — double gems on first IAP. This is industry standard and dramatically increases conversion.

---

## 6. MISSING SYSTEMS — What Would Make This a Real Game

### 6.1 — Missions / Challenges (CRITICAL)

This is the single most impactful system the app is missing. Every retention-focused mobile game has daily, weekly, and seasonal challenges. Currently HeatCheck has daily login (which is a passive check-in, not a mission).

**Implement three tiers:**
- **Daily (3-4 missions):** "Capture any car" (+15 XP), "Vote in 3 H2H battles" (+10 coins), "Visit the Explore page" (+5 XP)
- **Weekly (2-3 missions):** "Capture 5 different makes" (+100 coins), "Win 3 H2H battles" (+50 XP + border unlock), "List a card on marketplace" (+25 gems)
- **Seasonal (multi-week):** "Complete the Italian Collection" (exclusive legendary border), "Reach Level 20" (exclusive profile frame)

This alone would transform retention because it answers "what should I do today?"

### 6.2 — Collection Sets & Achievements

Add named sets that span multiple captures:
- "JDM Legends" — capture 5 Japanese sports cars → exclusive JDM border
- "Supercar Row" — capture cars from Ferrari, Lamborghini, McLaren, and Porsche → trophy
- "Local Hero" — capture 20 cars in the same city → location badge
- "Rarity Hunter" — own one card of each rarity tier → bonus gems

### 6.3 — Notifications & Re-engagement

The app currently sends zero push notifications. This is a death sentence for retention. Minimum set:
- Daily login reminder (if streak active)
- H2H battle started/completed with your card
- Marketplace: card sold, outbid, new listing matching your watchlist
- Friend captured a new card
- Weekly collection summary ("You captured 12 cars this week!")

### 6.4 — Season/Event System

Timed events create urgency and FOMO:
- "Supercar September" — bonus XP for capturing supercars all month
- "Drag Race Weekend" — 2x evolution points from H2H
- Limited-edition borders only available during events
- Seasonal leaderboard resets with tier rewards

---

## 7. VISUAL CONSISTENCY & POLISH

### Problems

**7.1 — Every Page Has a Different Background Treatment**

- Home: `Image("HomeBackground")` + blur + black overlay
- Capture: `Image("CaptureBackground")` + blur + black overlay
- Market: `Image("MarketBackground")` + blur + black overlay
- Garage: No background image, just system default
- Shop: `Image("ShopBackground")` + blur + black overlay
- H2H: `Image("dragStripTrack")` + scaledToFill
- Explore: `Color.appBackgroundSolid`
- Friends: `Color.appBackgroundSolid`

This creates a disjointed experience. Some pages feel immersive, others feel like utility screens.

**7.2 — Inconsistent Header Patterns**

- Home: No visible header (just LevelHeader overlay)
- Garage: Custom HStack header with glass effect
- Capture/Market: Large centered title + subtitle
- Explore/Friends: Left-aligned header with back button + glass effect
- H2H: Custom top bar with challenge button
- Shop: Left-aligned title with gem pill

**7.3 — Glass Effect Usage is Inconsistent**

`.glassEffect(.regular, in:)` is used on some headers, some containers, but not consistently. The "Liquid Glass" design language is partially applied.

**7.4 — Card Presentation Varies by Context**

Cards appear as:
- Thumbnail grids (Garage)
- FIFA-style landscape cards (Explore)
- Full-screen with tilt effect (Detail)
- Small previews in H2H
- List items in Marketplace

While some variation is expected, the card itself should have a single "canonical" appearance that scales, not different visual treatments per context.

### Recommendations

- **Unify background system** — create a single `AppSceneBackground` component that accepts a theme parameter and handles all background rendering. Every screen should use it.
- **Standardize header patterns** — create a reusable `ScreenHeader` component with variants (large title, compact, with/without back button) and use it everywhere.
- **Complete the Liquid Glass language** — if glass effects are the design direction, apply them consistently to all interactive surfaces, or don't use them at all.
- **Define a card "identity"** — the card should look the same (proportions, border treatment, info overlay) whether it's 50px or fullscreen. Scale, don't redesign.

---

## 8. SPECIFIC UX ISSUES

**8.1 — LevelHeader `levelGradient` is duplicated 3 times**

The identical gradient function appears in `LevelHeader.swift`, `ProfileView.swift`, and `FriendsView.swift`. This should be a shared utility.

**8.2 — Tab bar icons don't match the app's identity**

The five tabs use generic SF Symbols: bag, house, camera.fill, chart.line, wrench.and.screwdriver. For a car/card game, these feel generic. Custom tab icons matching the automotive theme would reinforce brand identity.

**8.3 — Empty states are afterthoughts**

When the Garage is empty, you see a system car icon and "Your collection will appear here." This is the MOST important moment to sell the experience — show them what a full garage COULD look like, or prompt them to capture their first card.

**8.4 — The Explore page is just a card browser**

`ExploreView.swift` shows categorized cards from the community. It's fine as a feed, but there's no interaction beyond viewing. Users should be able to: challenge a card they see, offer a trade, add to wishlist, send heat directly from the feed.

**8.5 — Profile is a popup, not a destination**

`ProfileView.swift` presents as an overlay. For a game where your identity (level, crown card, collection stats) matters, the profile should be a full screen with shareable elements — a "gamer card" that users want to screenshot and share.

---

## 9. PRIORITY ROADMAP

### Phase 1 — Emotional Core (Weeks 1-3)
_Make capturing feel incredible_
1. **Card reveal animation** after capture (pack-opening moment)
2. **Guided first capture** in onboarding
3. **Push notifications** (daily login reminder, H2H results)
4. **Daily/weekly missions system** (3 daily + 2 weekly)

### Phase 2 — Collection Depth (Weeks 4-6)
_Give the collection purpose_
5. **Collection Book** (Pokédex-style tracker with completion %)
6. **Named sets with rewards** (5-6 starter sets)
7. **Garage filters** (rarity, make, category, date)
8. **Collection milestone achievements**

### Phase 3 — Competitive Edge (Weeks 7-9)
_Make battles meaningful_
9. **H2H weight classes** (rarity-matched battles)
10. **Stat-influenced scoring** in H2H
11. **Season system** with ranked tiers and rewards
12. **Battle notifications** (live race alerts)

### Phase 4 — Monetization Polish (Weeks 10-12)
_Give players reasons to spend_
13. **Gem-exclusive cosmetics** (animated borders, effects, profile frames)
14. **Battle Pass** (free + premium track)
15. **Daily rotating deals** in shop
16. **First-purchase double gems**
17. **Economy rebalance** (quick-sell nerf, new coin sinks)

### Phase 5 — Visual Unity (Ongoing)
18. **Unified background system**
19. **Standardized headers**
20. **Custom tab bar icons**
21. **Consistent card presentation**
22. **Polished empty states**

---

## 10. CLOSING ASSESSMENT

HeatCheck's **concept is strong** — the idea of photographing real cars and turning them into trading cards with social competition is genuinely novel. The technical execution (AI identification, LiDAR anti-cheat, Firebase real-time sync) is impressive and well beyond prototype stage.

What's missing is the **game design layer**. Right now the app has features but not *feelings*. The capture is functional but not thrilling. The collection is stored but not showcased. The battles exist but don't create stories. The shop sells but doesn't tempt.

The good news: none of the recommended changes require architectural rewrites. The data models, services, and sync infrastructure are already in place. What's needed is **spectacle on top of structure** — animations, missions, sets, notifications, and visual consistency that transform a collection tool into a collectible game.

The single highest-ROI change is the **card reveal animation**. If a user captures a car and the app makes them feel like they just pulled a rare Pokémon card, everything else flows from that moment. That's the moment they screenshot, share, and come back to chase again.
