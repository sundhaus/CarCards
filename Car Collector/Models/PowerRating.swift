//
//  PowerRating.swift
//  Car Collector
//
//  Calculates a unique power level for each card, displayed on the card front.
//  Like FIFA's overall rating — one number that tells you how strong a card is,
//  but the 5 individual stats underneath still drive strategy in battles.
//
//  Power = weighted combination of all 5 battle stats + mod bonuses.
//  Range: 0–99 (displayed as a big number on card front).
//
//  The power rating is:
//    - Stored in Firestore as `powerRating` on the card document
//    - Recalculated when mods are applied or rarity changes
//    - Displayed on the card front by CardRenderer
//    - Used for quick comparison in marketplace, garage, and social
//

import Foundation

// MARK: - Power Rating Result

struct PowerRatingResult {
    let total: Int               // 0–99 — the displayed number
    let baseRating: Int          // Before mods
    let modBonus: Int            // Points added from mods
    let breakdown: [BattleCategory: Int]  // Per-category final values
    
    /// Display text like "87" for the card front
    var displayText: String {
        "\(total)"
    }
    
    /// Tier label based on power level
    var tier: PowerTier {
        PowerTier.from(rating: total)
    }
}

// MARK: - Power Tiers

/// Visual tiers for the power rating — drives color and badge on card front
enum PowerTier: String, CaseIterable {
    case bronze   = "Bronze"
    case silver   = "Silver"
    case gold     = "Gold"
    case elite    = "Elite"
    case master   = "Master"
    case icon     = "Icon"
    
    static func from(rating: Int) -> PowerTier {
        switch rating {
        case 0..<30:  return .bronze
        case 30..<45: return .silver
        case 45..<60: return .gold
        case 60..<75: return .elite
        case 75..<90: return .master
        default:      return .icon
        }
    }
    
    /// Color for the power badge on the card front (as RGB values for UIKit use)
    var rgb: (r: CGFloat, g: CGFloat, b: CGFloat) {
        switch self {
        case .bronze: return (0.70, 0.45, 0.20)
        case .silver: return (0.65, 0.67, 0.72)
        case .gold:   return (0.85, 0.68, 0.10)
        case .elite:  return (0.20, 0.65, 0.85)
        case .master: return (0.55, 0.25, 0.85)
        case .icon:   return (0.90, 0.20, 0.20)
        }
    }
    
    /// Glow color for higher tiers (nil = no glow)
    var glowRGB: (r: CGFloat, g: CGFloat, b: CGFloat)? {
        switch self {
        case .bronze, .silver: return nil
        case .gold:   return (0.85, 0.68, 0.10)
        case .elite:  return (0.20, 0.65, 0.85)
        case .master: return (0.55, 0.25, 0.85)
        case .icon:   return (0.90, 0.20, 0.20)
        }
    }
}

// MARK: - Power Rating Calculator

struct PowerRating {
    
    /// Calculate the power rating for a card.
    ///
    /// Uses a **peak-weighted** system: your best stats contribute more than your
    /// worst stats. This means a Chiron (99 Speed, 97 Power, but low Efficiency)
    /// rates higher than a P1 (high across the board but lower peaks).
    ///
    /// Formula:
    ///   1. Sort all 5 stats highest → lowest
    ///   2. Apply descending weights: best stat counts most, worst counts least
    ///   3. Rarity gets a flat bonus on top (not competing with performance stats)
    ///
    /// This ensures:
    ///   - Hypercars with extreme specs rate 90+ (Icon tier)
    ///   - Well-rounded sports cars rate 70–85 (Master/Elite)
    ///   - Average cars rate 40–60 (Gold/Silver)
    ///   - Economy cars rate 20–40 (Bronze/Silver)
    ///   - A Chiron always beats a P1 in raw power rating
    ///   - But a P1 can still win battles by picking Handling or Efficiency
    ///
    static func calculate(
        specs: CarSpecs,
        rarity: CardRarity,
        mods: [AppliedMod] = [],
        category: VehicleCategory? = nil
    ) -> PowerRatingResult {
        // 1. Get base battle stats from the engine
        let baseStats = BattleStatsEngine.calculate(
            specs: specs,
            rarity: rarity,
            category: category ?? specs.category
        )
        
        // 2. Get mod bonuses
        let modBoosts = ModStatCalculator.totalBoosts(from: mods)
        
        // 3. Combine base + mods per category (clamped 0–99)
        var breakdown: [BattleCategory: Int] = [:]
        let performanceCategories: [BattleCategory] = [.speed, .power, .handling, .efficiency]
        
        for cat in BattleCategory.allCases {
            let base = baseStats.value(for: cat)
            let modBonus = modBoosts[cat] ?? 0
            breakdown[cat] = max(0, min(99, base + modBonus))
        }
        
        // 4. Peak-weighted calculation (performance stats only — rarity handled separately)
        //    Sort performance stats highest to lowest, then apply descending weights.
        //    Best stat = 35%, 2nd = 28%, 3rd = 22%, Worst = 15%
        let perfValues = performanceCategories
            .map { breakdown[$0] ?? 0 }
            .sorted(by: >)
        
        let peakWeights: [Double] = [0.35, 0.28, 0.22, 0.15]
        
        var perfScore = 0.0
        for (i, value) in perfValues.enumerated() {
            perfScore += Double(value) * peakWeights[i]
        }
        
        // 5. Rarity bonus: flat addition scaled 0–8 points
        //    This means rarity can bump you up a tier but can't carry a bad car
        let rarityBonus: Double
        switch rarity {
        case .common:    rarityBonus = 0.0
        case .uncommon:  rarityBonus = 1.5
        case .rare:      rarityBonus = 3.0
        case .epic:      rarityBonus = 5.0
        case .legendary: rarityBonus = 8.0
        }
        
        let total = max(0, min(99, Int((perfScore + rarityBonus).rounded())))
        
        // 6. Calculate base (without mods) for display
        let basePerfValues = performanceCategories
            .map { baseStats.value(for: $0) }
            .sorted(by: >)
        
        var basePerfScore = 0.0
        for (i, value) in basePerfValues.enumerated() {
            basePerfScore += Double(value) * peakWeights[i]
        }
        let baseRating = max(0, min(99, Int((basePerfScore + rarityBonus).rounded())))
        
        return PowerRatingResult(
            total: total,
            baseRating: baseRating,
            modBonus: total - baseRating,
            breakdown: breakdown
        )
    }
    
    /// Quick calculation from just specs and rarity (no mods) — for new cards
    static func quickCalc(specs: CarSpecs, rarity: CardRarity) -> Int {
        let result = calculate(specs: specs, rarity: rarity)
        return result.total
    }
}

// MARK: - Convenience Extensions

extension CloudCard {
    /// Get the stored power rating, or 0 if not yet calculated
    var powerRating: Int {
        // Stored as a field on CloudCard — populated when specs are fetched
        // or mods are applied. Falls back to 0 for cards that haven't been rated yet.
        return storedPowerRating ?? 0
    }
    
    /// Power tier for display color
    var powerTier: PowerTier {
        PowerTier.from(rating: powerRating)
    }
}

extension SavedCard {
    /// Calculate power rating from embedded specs
    func calculatePowerRating(rarity: CardRarity = .common) -> Int {
        return PowerRating.quickCalc(specs: carSpecs, rarity: rarity)
    }
}
