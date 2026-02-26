# Car Collector (HeatCheck) — Gamification & UX Audit

**Auditor perspective:** AAA mobile game design (F2P card collectors: FIFA Ultimate Team, Marvel Snap, Pokémon TCG Live)  
**Codebase reviewed:** 34,308 lines across 65 Swift files  
**Date:** February 2026

---

## Executive Summary

The app has **strong bones** — a real camera-to-card pipeline, Firebase-backed social, a working marketplace, and a head-to-head voting system. What it lacks are the **emotional beats and compulsion loops** that make users open the app 6+ times a day, and the **visual polish** that makes a card feel precious enough to spend money upgrading. Below is a prioritized breakdown of every weak spot I found, organized by impact on retention and revenue.

---

## 🔴 CRITICAL: The Core Loop Has No Tension

### Problem: Capture → Collect → ???

Right now the user journey is: take photo → get card → see it in garage. That's a **content creation tool**, not a game. The missing ingredient is **stakes** — reasons to care about what you capture and what you do with it afterward.

**What AAA card games do differently:**

| Game | Tension Source |
|------|---------------|
| FIFA UT | Weekend League rewards require your best squad; losing costs entry tokens |
| Marvel Snap | Snapping doubles stakes mid-match; retreat costs cubes |
| Pokémon TCG | Tournament laddering with visible rank decay |

### What HeatCheck is missing:

1. **No cost to enter Head-to-Head.** The `entryFee` field exists on the Race model but there's no visible friction. Races should cost coins to enter, creating a risk/reward decision. Currently it feels like tapping a button and waiting.

2. **No seasonal pressure.** There's no concept of seasons, resets, or time-limited goals. The Explore "Featured" rotates every 3 hours but there's no reward for engaging with it — it's just a gallery.

3. **No deck-building or loadout strategy.** You pick one card for H2H. There's no "build a team of 5" or "enter a card from each rarity tier." Without composition strategy, collecting more cards has diminishing returns.

4. **No loss condition anywhere.** You can't lose cards, lose rank, or lose streaks through inaction. If nothing bad can happen, nothing feels urgent.

---

## 🔴 CRITICAL: The Economy Is Broken (Too Generous, No Sinks)

### Current numbers from `RewardConfig.swift`:

| Action | Coins | XP |
|--------|-------|----|
| Capture (Common) | 5 | 25 |
| Capture (Legendary) | 75 | 125 |
| Daily login | 10 | 15 |
| Quick sell (Common) | 50 | 5 |
| Quick sell (Legendary) | 1,000 | 50 |
| Level-up bonus | level × 50 | — |
| Starter grant | 500 | — |

### The problem:

- **Quick sell pays 10x more than capturing.** A user can capture a Common (earn 5 coins), immediately quick-sell it (earn 50 coins), and net +55 coins for zero effort. This means the optimal strategy is to photograph anything, sell immediately, repeat. That's the opposite of collecting.

- **Coins accumulate with nothing to spend them on.** The only coin sinks are marketplace bids (player-to-player, so coins just circulate) and H2H entry fees (barely enforced). There are no cosmetic coin sinks, no card packs, no re-roll mechanics, no repair/maintenance costs.

- **Gems have exactly one use: rarity upgrade.** The `RarityUpgradeConfig` gem costs (100/300/800/2000) are the only gem sink in the entire app. Once a user upgrades their favorite card, gems become worthless. Compare to Marvel Snap where gold buys season passes, card variants, avatars, card backs, profile titles, and emotes.

- **XP is linear and uncapped with no prestige system.** The tier system (100 XP/level for levels 1-9, 200 for 10-19, etc.) means a dedicated user will blow past level 50 in weeks. After that, leveling provides coins (which are already overflowing) and nothing else. No title unlocks, no frame unlocks, no feature gates.

### Recommended economy rebalance:

| Action | Current Coins | Suggested Coins | Reasoning |
|--------|--------------|-----------------|-----------|
| Capture (Common) | 5 | 10 | Still low, but capture should feel good |
| Quick sell (Common) | 50 | 15 | Must be LESS than capture + keep value |
| Quick sell (Legendary) | 1,000 | 200 | Selling a legendary should hurt |
| H2H entry (1v1) | 0 | 25-100 (tiered) | Creates risk, makes wins feel earned |
| Daily login | 10 | 25 | Make this feel more meaningful |

---

## 🟡 HIGH: Home Screen Feels Like a Settings Menu

### Current state (from `HomeView.swift`):

The home screen is a 2×2 grid of `HomeContainer` items (Leaderboard, Friends, Head to Head, Transfer List) plus a Featured carousel. Each container is a glass rectangle with a system icon circle and an ALL-CAPS label.

### Problems:

1. **No personality.** Every container looks identical — a colored circle with an SF Symbol. This is a navigation hub, not a home screen. Compare to FIFA UT's home which shows your featured player card, daily objectives progress, live event countdown timers, and seasonal narrative art.

2. **No "what should I do next?"** There's no daily objective system, no challenge prompts, no "3 more captures for a bonus" progress indicators. The user lands on Home and has to *decide* what to do. Engaged users need gentle nudges.

3. **The Featured carousel is passive.** It shows hot cards but there's no interaction — no "vote for your favorite," no "save to wishlist," no "challenge this card's owner." It's a museum, not a game element.

4. **No visible progression on the home screen.** The LevelHeader shows level/coins/gems but there's no XP bar, no "next reward at level X" teaser, no weekly progress summary.

### What should be on the home screen:

- **Your "showcase" card** (the crowned card from profile) displayed prominently
- **Daily missions** (3 rotating objectives with coin/gem/XP rewards)
- **Active race status** (live vote counts if you have an active H2H)
- **"Capture streak" tracker** (days in a row you've captured at least 1 card)
- **Seasonal event banner** (limited-time themes, challenges)

---

## 🟡 HIGH: Card Detail View Undersells the Card

### Current state (from `CardDetailsView.swift`):

The card detail shows a flattened card image and then jumps straight to transactional actions: Upgrade Rarity, List on Market, Compare Price, Quick Sell. It's a utility screen.

### What's missing:

1. **No stats page.** Car specs are fetched by AI but they're buried. There should be a FIFA-style stats radar chart (0-99 ratings for Speed, Power, Handling, Style, Rarity, Heritage) that makes the card feel like it has measurable attributes. These stats could drive H2H matchups.

2. **No card history.** The `previousOwners` field exists on `SavedCard` but there's no visual timeline showing capture date, ownership transfers, battle record (W-L), total heat received. Provenance creates emotional attachment.

3. **No 3D/interactive card view.** The `CardTiltEffect` model exists but card detail just shows a flat image. Users should be able to rotate/tilt the card, see holographic effects on rare cards, and admire the border treatments. This is the "show off" moment.

4. **No sharing.** There's no "share to Instagram Stories" or "export card image" feature. User-generated sharing is the #1 organic growth driver for collection games.

---

## 🟡 HIGH: Rarity Upgrade Path Is Too Grindy (Free) and Too Simple (Paid)

### Current from `RarityUpgradeConfig.swift`:

**Free path (Evolution Points):**
- Common → Uncommon: 100 points (~20 battles at 5 pts/win)
- Uncommon → Rare: 200 points (~40 battles)  
- Rare → Epic: 400 points (~80 battles)
- Epic → Legendary: 800 points (~160 battles)

**Paid path (Gems):**
- Common → Uncommon: 100 gems
- Epic → Legendary: 2,000 gems

### Problems:

1. **The free path is pure grind with no variety.** 160 battles for one upgrade is ~2-3 months of daily play. There's no alternative way to earn evolution points — no challenges, no milestones, no bonus events. Users will burn out long before Epic → Legendary.

2. **The paid path is a binary skip button.** "Pay gems to skip grind" is the least engaging monetization. Better games make the paid path *feel different* — special upgrade animations, exclusive visual effects, "guaranteed success" vs. a chance-based free path.

3. **No upgrade failure/gambling mechanic.** Every upgrade is guaranteed. Adding a success probability (with pity system) creates excitement: "85% chance to upgrade, on failure gain +15% next attempt." This is how gacha games create memorable moments.

4. **Unlock gates are invisible.** The level/cards/wins requirements for higher tiers (`requiredLevel`, `requiredCardsOwned`, `requiredBattleWins`) are checked in code but there's no "road map" showing the user what they need to achieve. These gates should be prominent motivators, not hidden blockers.

---

## 🟡 HIGH: Head-to-Head Is the Best Feature But Poorly Surfaced

### Current from `HeadToHeadView.swift` and `HeadToHeadService.swift`:

The drag-strip race concept is creative. Two cards face off, public users vote, cars advance on a track as votes come in. This is genuinely fun and unique.

### What's holding it back:

1. **It's buried behind Home → Head to Head button.** This should be THE core engagement loop, not a sub-feature. Consider making it a primary tab or having a persistent "live race" ticker on the home screen.

2. **No matchmaking intelligence.** Races are open challenges that anyone can accept. There's no ELO/MMR, no rarity-bracket matching, no "you'll face a similar card" promise. A Common Honda Civic vs. a Legendary Ferrari isn't interesting for voters.

3. **No spectator value.** The voting feed should be a TikTok-style swipe experience where users endlessly vote on car matchups. Currently it shows one race at a time with a loading state between. Make it infinite scroll.

4. **Duo battles are underexplored.** The `isDuo` and `pairedRaceId` fields exist but duos aren't prominently featured. Team play is THE social retention mechanic in mobile games.

5. **No voting rewards beyond XP.** Voters get 5 XP per vote and 20 XP for picking the winner. They should also get coins, streak bonuses for consecutive correct picks, and a "Judge" leaderboard.

---

## 🟡 MEDIUM: Visual Consistency Issues Across Views

### Background treatment inconsistency:

| View | Background |
|------|-----------|
| Home | `HomeBackground` image + blur + 0.45 black overlay |
| Capture | `CaptureBackground` image + blur + 0.45 black overlay |
| Marketplace | `MarketBackground` image + blur + 0.45 black overlay |
| Shop | `ShopBackground` image + blur + 0.45 black overlay |
| Garage | No hero background (just content) |
| Friends | `Color.appBackgroundSolid` (solid dark) |
| Explore | `Color.appBackgroundSolid` (solid dark) |
| Profile | Black 0.4 overlay (popup) |
| H2H | `dragStripTrack` image (custom treatment) |
| Onboarding | `AppBackground` with floating shapes |

There are **three different background philosophies** coexisting: blurred hero images, solid dark color, and the AppBackground spline/floating shapes system. The Liquid Glass (.glassEffect) design language requires colorful underlayers to refract — using `Color.appBackgroundSolid` on Friends/Explore means glass effects look flat and lifeless there.

### Font inconsistency:

The app uses a mix of `.poppins()` custom font sizing and `.pTitle`/`.pTitle2`/`.pTitle3`/`.pHeadline`/`.pSubheadline`/`.pCaption` semantic styles. Some views use raw `.font(.poppins(42))` while others use the semantic system. Header text sizes range from 16pt to 42pt with no clear hierarchy.

### Recommendations:

1. **Standardize on ONE background system** — the blurred hero image approach is most visually rich. Every primary view should have a unique hero image with the same blur(3) + black 0.45 treatment.

2. **Create a strict type scale** and enforce it:
   - Page title: 28pt Poppins Bold
   - Section title: 20pt Poppins Semibold  
   - Body: 16pt Poppins Regular
   - Caption: 13pt Poppins Regular
   - Badge: 11pt Poppins Medium

3. **Unify the header bar pattern.** Some views use custom HStack headers, some use `.glassEffect(.regular, in: .rect)`, some use NavigationStack toolbar. Pick one pattern and apply it everywhere.

---

## 🟡 MEDIUM: Onboarding Drops Users Into a Cold Start

### Current flow (from `OnboardingView.swift`):

1. See logo
2. Type username
3. Check age (under 13 toggle)
4. Create account
5. Land on empty Home screen

### What's missing:

1. **No tutorial capture.** The user has never taken a photo, doesn't know how the AI identification works, and doesn't understand what a card becomes. The first action should be a guided capture with a celebration moment.

2. **No starter pack.** The 500 starter coins arrive silently. A "Welcome Pack" opening animation (like card pack opening in any TCG) would create the first dopamine hit and teach the core collectible loop.

3. **No sample content.** The Garage, Friends feed, and Explore are all empty on first login. Seed the account with 1-2 community cards or demo cards so the app feels alive.

4. **No permission priming.** Camera and location permissions are requested in-context, but there's no value proposition screen explaining why these matter before the system dialog appears.

---

## 🟡 MEDIUM: The Marketplace Needs Better Discovery

### Current flow:

Marketplace Landing → Search (filter by make/model/year/rarity/price) → Results grid → Listing detail → Bid or Buy Now

### Problems:

1. **No curated sections.** There's no "Ending Soon," "Just Listed," "Underpriced Gems," or "Staff Picks." Users have to know what they're looking for.

2. **No price guidance.** The "Compare Price" feature searches for similar listings, but there's no average sale price, price history chart, or "this is a good deal" indicator. Without price anchoring, users don't know if they're overpaying.

3. **No notification for bid activity.** When someone bids on your listing or outbids you, there should be push notifications. Currently this seems to rely on polling.

4. **Listing durations are too long.** The options are 1, 3, 6, 12, and 24 hours. For a mobile app with thin liquidity, 1-3 hour "flash sales" with a countdown timer create more urgency than 24-hour listings that feel static.

---

## 🟢 NICE-TO-HAVE: Additional Engagement Systems to Consider

### 1. Card Packs / Loot System
Instead of (or in addition to) marketplace, sell randomized card packs:
- **Bronze Pack** (500 coins): 3 Commons, 1 chance at Uncommon
- **Silver Pack** (2,000 coins): 2 Uncommon guaranteed, 1 chance at Rare
- **Gold Pack** (100 gems): 1 Rare guaranteed, 1 chance at Epic
- **Legendary Pack** (500 gems): 1 Epic guaranteed, small chance at Legendary

These packs would contain cards from the community pool (other users' captures), creating a secondary discovery mechanism.

### 2. Collections & Set Completion
Define sets: "German Engineering" (BMW, Mercedes, Porsche, Audi, VW), "Italian Stallions" (Ferrari, Lamborghini, Maserati, Pagani), "JDM Legends" (Supra, NSX, RX-7, GT-R, STI). Completing a set awards:
- Exclusive card border
- Gem bonus
- Leaderboard points
- Profile badge

### 3. Seasonal Battle Pass
A 30-day progression track with free and premium tiers:
- **Free tier:** Coins, XP boosts, basic borders at milestones
- **Premium tier ($4.99):** Exclusive card effects, animated borders, profile frames, gem bonuses
- Progress through daily missions and captures

### 4. Achievement System
Track and reward milestones:
- "First Catch" — Capture your first card
- "Century Club" — Own 100 cards  
- "Legendary Spotter" — Capture a Legendary-rarity vehicle
- "Undefeated" — Win 10 H2H races in a row
- "Tycoon" — Earn 10,000 coins from marketplace sales

### 5. Card Abilities for H2H
Instead of pure voting, give cards passive abilities based on their specs:
- **Turbo Boost** (high horsepower): Gets 10% bonus votes in first minute
- **Endurance** (high MPG): Votes count 1.2x in final 30 minutes
- **Crowd Favorite** (high heat count): Starts with 3 bonus votes
This turns H2H from a beauty contest into a strategic game.

---

## Summary Priority Matrix

| Priority | Item | Impact on Retention | Effort |
|----------|------|-------------------|--------|
| 🔴 P0 | Rebalance economy (coin sinks, quick-sell nerf) | Very High | Low |
| 🔴 P0 | Add daily missions system to Home | Very High | Medium |
| 🔴 P0 | Add H2H entry fees + tier-based matchmaking | Very High | Medium |
| 🟡 P1 | Card stats radar + battle record on detail view | High | Medium |
| 🟡 P1 | Infinite-scroll voting feed for H2H spectators | High | Medium |
| 🟡 P1 | Guided first-capture tutorial in onboarding | High | Medium |
| 🟡 P1 | Collection sets with completion rewards | High | Medium |
| 🟡 P1 | Unify backgrounds and type scale | Medium | Low |
| 🟡 P1 | Card sharing to Instagram/social | Medium | Low |
| 🟡 P2 | Seasonal battle pass | Very High | High |
| 🟡 P2 | Card pack / loot system | High | High |
| 🟡 P2 | Achievement system | Medium | Medium |
| 🟡 P2 | Upgrade chance mechanic (gambling) | Medium | Medium |
| 🟢 P3 | Card abilities for H2H strategy | Medium | High |
| 🟢 P3 | Price history on marketplace | Low | Medium |

---

## Final Thought

The fundamental problem isn't technical — the code is well-architected and the Firebase integration is solid. The problem is that **the app treats itself like a utility (camera → card → storage) when it needs to treat itself like a game (challenge → risk → reward → show off → repeat).** Every screen should ask: "What does the user want to do next, and what are they afraid of losing?" Right now, the answer to the second question is "nothing" — and that's why the retention mechanics won't hold.

The single highest-ROI change is adding **daily missions** to the home screen (capture 2 cars, vote in 3 H2H races, earn 100 coins from sales) with escalating weekly bonuses. This alone would give every session a purpose and every login a reason.
