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
    
    // Category weights for the overall power calculation.
    // Speed and Power weigh slightly more because they "feel" more impactful
    // to car enthusiasts, but Handling and Efficiency still matter for strategy.
    private static let weights: [BattleCategory: Double] = [
        .speed:      0.25,
        .power:      0.25,
        .handling:   0.22,
        .efficiency: 0.13,
        .rarity:     0.15
    ]
    
    /// Calculate the power rating for a card.
    /// - Parameters:
    ///   - specs: The card's base vehicle specs
    ///   - rarity: Card rarity tier
    ///   - mods: Applied performance mods (can be empty)
    ///   - category: Vehicle category (optional, inferred from specs if nil)
    /// - Returns: PowerRatingResult with total, base, mod bonus, and breakdown
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
        let modBoosts = PerformanceModService.totalBoosts(from: mods)
        
        // 3. Combine base + mods per category (clamped 0–99)
        var breakdown: [BattleCategory: Int] = [:]
        for cat in BattleCategory.allCases {
            let base = baseStats.value(for: cat)
            let modBonus = modBoosts[cat] ?? 0
            breakdown[cat] = max(0, min(99, base + modBonus))
        }
        
        // 4. Weighted average for total
        var weightedSum = 0.0
        for (cat, weight) in weights {
            weightedSum += Double(breakdown[cat] ?? 0) * weight
        }
        let total = max(0, min(99, Int(weightedSum.rounded())))
        
        // 5. Calculate base (without mods) for display
        var baseWeightedSum = 0.0
        for (cat, weight) in weights {
            baseWeightedSum += Double(baseStats.value(for: cat)) * weight
        }
        let baseRating = max(0, min(99, Int(baseWeightedSum.rounded())))
        
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
        return PowerRating.quickCalc(specs: specs, rarity: rarity)
    }
}
