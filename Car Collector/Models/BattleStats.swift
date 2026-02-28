//
//  BattleStats.swift
//  CarCardCollector
//
//  Battle stat engine — converts raw CarSpecs into 5 strategic battle categories.
//  Each category has a 0-99 rating. Different car types dominate different categories,
//  so every card has a niche. A Miata beats a Bugatti in Handling; a Tesla beats
//  a Lamborghini in Efficiency; a lifted F-150 beats everything in Power.
//
//  Rarity multipliers make upgrading cards strategically important without making
//  commons useless (a Common Porsche 911 still beats a Legendary Honda Civic in Speed).
//

import Foundation

// MARK: - Battle Stat Categories

/// The five strategic stat categories for card battles.
/// Each category is derived from real CarSpecs data so battles feel grounded
/// in actual vehicle performance rather than arbitrary numbers.
enum BattleCategory: String, Codable, CaseIterable, Identifiable {
    case speed      = "Speed"
    case power      = "Power"
    case handling   = "Handling"
    case efficiency = "Efficiency"
    case rarity     = "Rarity"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .speed:      return "bolt.fill"
        case .power:      return "flame.fill"
        case .handling:   return "steeringwheel"
        case .efficiency: return "leaf.fill"
        case .rarity:     return "sparkles"
        }
    }
    
    var description: String {
        switch self {
        case .speed:      return "0-60 time + top speed"
        case .power:      return "Horsepower + torque"
        case .handling:   return "Agility + drivetrain balance"
        case .efficiency: return "Power-to-displacement ratio"
        case .rarity:     return "How rare this card is globally"
        }
    }
    
    var shortLabel: String {
        switch self {
        case .speed:      return "SPD"
        case .power:      return "PWR"
        case .handling:   return "HND"
        case .efficiency: return "EFF"
        case .rarity:     return "RAR"
        }
    }
}

// MARK: - Battle Stats (computed per card)

/// Computed battle stats for a single card. These are derived from CarSpecs
/// and adjusted by rarity multiplier. All values are 0-99.
struct BattleStats: Codable, Equatable {
    let speed: Int          // 0-99
    let power: Int          // 0-99
    let handling: Int       // 0-99
    let efficiency: Int     // 0-99
    let rarityScore: Int    // 0-99
    let overall: Int        // Weighted average
    
    /// Get stat value for a specific category
    func value(for category: BattleCategory) -> Int {
        switch category {
        case .speed:      return speed
        case .power:      return power
        case .handling:   return handling
        case .efficiency: return efficiency
        case .rarity:     return rarityScore
        }
    }
    
    /// The category where this card is strongest
    var bestCategory: BattleCategory {
        let cats: [(BattleCategory, Int)] = [
            (.speed, speed),
            (.power, power),
            (.handling, handling),
            (.efficiency, efficiency),
            (.rarity, rarityScore)
        ]
        return cats.max(by: { $0.1 < $1.1 })?.0 ?? .power
    }
    
    /// The category where this card is weakest
    var worstCategory: BattleCategory {
        let cats: [(BattleCategory, Int)] = [
            (.speed, speed),
            (.power, power),
            (.handling, handling),
            (.efficiency, efficiency),
            (.rarity, rarityScore)
        ]
        return cats.min(by: { $0.1 < $1.1 })?.0 ?? .efficiency
    }
    
    /// Empty / fallback stats for cards with no specs
    static var empty: BattleStats {
        BattleStats(speed: 25, power: 25, handling: 25, efficiency: 25, rarityScore: 10, overall: 22)
    }
}

// MARK: - Battle Stats Engine

/// The core engine that converts raw CarSpecs + CardRarity into battle-ready stats.
/// All formulas are tuned so that different car types excel in different categories:
///
/// - Supercars/Hypercars → Speed kings
/// - Muscle cars/Trucks  → Power kings
/// - Sports cars/Hatches → Handling kings
/// - EVs/Hybrids         → Efficiency kings
/// - Rare cards          → Rarity score boost
///
struct BattleStatsEngine {
    
    // MARK: - Rarity Multipliers
    
    /// Rarity gives a small stat multiplier. A Common Porsche 911 still beats
    /// a Legendary Honda Civic in Speed, but the Legendary has an edge in close matchups.
    static func rarityMultiplier(for rarity: CardRarity) -> Double {
        switch rarity {
        case .common:    return 1.0
        case .uncommon:  return 1.03
        case .rare:      return 1.06
        case .epic:      return 1.10
        case .legendary: return 1.15
        }
    }
    
    /// Rarity base score (0-99) — higher rarity = higher base score
    static func rarityBaseScore(for rarity: CardRarity) -> Int {
        switch rarity {
        case .common:    return 15
        case .uncommon:  return 35
        case .rare:      return 55
        case .epic:      return 75
        case .legendary: return 95
        }
    }
    
    // MARK: - Main Calculation
    
    /// Calculate battle stats from a card's specs and rarity.
    /// Returns a BattleStats with all 5 categories rated 0-99.
    static func calculate(specs: CarSpecs, rarity: CardRarity, category: VehicleCategory? = nil) -> BattleStats {
        let multiplier = rarityMultiplier(for: rarity)
        
        // --- SPEED (0-99) ---
        // Based on 0-60 time (lower = better) and top speed (higher = better)
        let speedFromAccel = calculateAccelScore(zeroToSixty: specs.zeroToSixty)
        let speedFromTop = calculateTopSpeedScore(topSpeed: specs.topSpeed)
        let rawSpeed = (speedFromAccel * 0.6 + speedFromTop * 0.4)
        
        // --- POWER (0-99) ---
        // Based on horsepower and torque
        let rawPower = calculatePowerScore(hp: specs.horsepower, torque: specs.torque)
        
        // --- HANDLING (0-99) ---
        // Based on drivetrain, weight class estimate, and vehicle category
        let rawHandling = calculateHandlingScore(
            drivetrain: specs.drivetrain,
            category: category ?? specs.category,
            hp: specs.horsepower,
            displacement: specs.displacement
        )
        
        // --- EFFICIENCY (0-99) ---
        // Based on power-to-displacement ratio (how much HP per liter)
        // EVs and hybrids get bonus
        let rawEfficiency = calculateEfficiencyScore(
            hp: specs.horsepower,
            displacement: specs.displacement,
            engineType: specs.engineType,
            category: category ?? specs.category
        )
        
        // --- RARITY (0-99) ---
        // Directly from CardRarity tier
        let rawRarity = Double(rarityBaseScore(for: rarity))
        
        // Apply rarity multiplier to performance stats (not to rarity itself)
        let speed = clampStat(Int(rawSpeed * multiplier))
        let power = clampStat(Int(rawPower * multiplier))
        let handling = clampStat(Int(rawHandling * multiplier))
        let efficiency = clampStat(Int(rawEfficiency * multiplier))
        let rarityScore = clampStat(Int(rawRarity))
        
        // Overall = weighted average (rarity weighs less)
        let overall = (speed * 25 + power * 25 + handling * 25 + efficiency * 15 + rarityScore * 10) / 100
        
        return BattleStats(
            speed: speed,
            power: power,
            handling: handling,
            efficiency: efficiency,
            rarityScore: rarityScore,
            overall: clampStat(overall)
        )
    }
    
    // MARK: - Individual Stat Calculators
    
    /// Acceleration score: 0-60 in seconds → 0-99 rating
    /// Sub-2.0s = 99, 3.0s = ~85, 5.0s = ~65, 8.0s = ~40, 12s+ = ~15
    private static func calculateAccelScore(zeroToSixty: Double?) -> Double {
        guard let zts = zeroToSixty, zts > 0 else { return 30.0 }
        
        // Inverse relationship: faster 0-60 = higher score
        // Formula: score = 110 - (zts * 10), clamped
        let score = 110.0 - (zts * 10.0)
        return max(5.0, min(99.0, score))
    }
    
    /// Top speed score: mph → 0-99 rating
    /// 260+ mph = 99, 200 mph = ~85, 155 mph = ~70, 120 mph = ~50, 90 mph = ~30
    private static func calculateTopSpeedScore(topSpeed: Int?) -> Double {
        guard let ts = topSpeed, ts > 0 else { return 30.0 }
        
        // Linear-ish mapping with diminishing returns above 200
        if ts >= 260 { return 99.0 }
        if ts >= 200 {
            return 85.0 + Double(ts - 200) * (14.0 / 60.0)
        }
        // 60 mph → ~15, 200 mph → 85
        let score = 15.0 + Double(ts - 60) * (70.0 / 140.0)
        return max(5.0, min(99.0, score))
    }
    
    /// Power score from HP + torque → 0-99
    /// 1000+ HP = 99, 500 HP = ~75, 300 HP = ~55, 150 HP = ~35
    private static func calculatePowerScore(hp: Int?, torque: Int?) -> Double {
        let hpScore: Double
        if let hp = hp, hp > 0 {
            if hp >= 1000 { hpScore = 99.0 }
            else if hp >= 500 { hpScore = 75.0 + Double(hp - 500) * (24.0 / 500.0) }
            else if hp >= 200 { hpScore = 35.0 + Double(hp - 200) * (40.0 / 300.0) }
            else { hpScore = max(10.0, Double(hp) / 200.0 * 35.0) }
        } else {
            hpScore = 25.0
        }
        
        let tqScore: Double
        if let tq = torque, tq > 0 {
            if tq >= 800 { tqScore = 99.0 }
            else if tq >= 400 { tqScore = 70.0 + Double(tq - 400) * (29.0 / 400.0) }
            else if tq >= 200 { tqScore = 35.0 + Double(tq - 200) * (35.0 / 200.0) }
            else { tqScore = max(10.0, Double(tq) / 200.0 * 35.0) }
        } else {
            tqScore = 25.0
        }
        
        // Weight HP slightly more than torque
        return hpScore * 0.6 + tqScore * 0.4
    }
    
    /// Handling score based on drivetrain, category, weight estimate → 0-99
    /// Lightweight sports cars + AWD/RWD = high handling
    /// Heavy trucks/SUVs = lower handling
    private static func calculateHandlingScore(
        drivetrain: String?,
        category: VehicleCategory?,
        hp: Int?,
        displacement: Double?
    ) -> Double {
        var score = 50.0  // Start neutral
        
        // Drivetrain bonus
        switch drivetrain?.uppercased() {
        case "AWD", "4WD":
            score += 10.0   // AWD = good handling
        case "RWD":
            score += 5.0    // RWD = balanced
        case "FWD":
            score -= 3.0    // FWD = slight penalty
        default:
            break
        }
        
        // Category adjustment — the big differentiator
        switch category {
        case .hypercar:      score += 25.0   // Active aero, carbon brakes
        case .supercar:      score += 22.0
        case .sportsCar:     score += 20.0   // Purpose-built for corners
        case .track:         score += 28.0   // Track-focused = best handling
        case .rally:         score += 18.0   // Great at sliding
        case .coupe:         score += 12.0
        case .hatchback:     score += 10.0   // Hot hatches are nimble
        case .convertible:   score += 8.0
        case .sedan:         score += 3.0
        case .electric:      score += 8.0    // Low center of gravity
        case .hybrid:        score += 3.0
        case .wagon:         score -= 2.0
        case .luxury:        score -= 5.0    // Heavy, comfort-tuned
        case .muscle:        score -= 5.0    // Straight line, not corners
        case .suv:           score -= 12.0   // Top-heavy
        case .truck:         score -= 18.0   // Long wheelbase, heavy
        case .van:           score -= 20.0
        case .offRoad:       score -= 8.0    // Good on dirt, not pavement
        case .classic:       score += 0.0    // Varies wildly
        case .concept:       score += 15.0   // Usually cutting-edge
        case .none:          break
        }
        
        // Lightweight estimate: lower displacement + decent HP = likely lighter
        if let disp = displacement, let hp = hp {
            let powerToWeight = Double(hp) / max(disp, 0.5)
            if powerToWeight > 200 { score += 8.0 }      // Very light relative to power
            else if powerToWeight > 120 { score += 4.0 }
            else if powerToWeight < 60 { score -= 5.0 }   // Heavy/underpowered
        }
        
        return max(5.0, min(99.0, score))
    }
    
    /// Efficiency score: HP-per-liter + category bonuses → 0-99
    /// EVs dominate, hybrids are strong, big displacement V8s are low
    private static func calculateEfficiencyScore(
        hp: Int?,
        displacement: Double?,
        engineType: String?,
        category: VehicleCategory?
    ) -> Double {
        var score = 40.0  // Start at middle
        
        // EVs and hybrids get a massive category bonus
        switch category {
        case .electric:  score += 40.0
        case .hybrid:    score += 25.0
        default: break
        }
        
        // Engine type keywords
        if let engine = engineType?.lowercased() {
            if engine.contains("electric") || engine.contains("ev") {
                score += 35.0
            } else if engine.contains("hybrid") {
                score += 20.0
            } else if engine.contains("turbo") {
                score += 8.0  // Forced induction = more efficient per liter
            } else if engine.contains("supercharged") || engine.contains("supercharger") {
                score += 5.0
            }
        }
        
        // HP per liter (higher = more efficient use of displacement)
        if let hp = hp, let disp = displacement, disp > 0 {
            let hpPerLiter = Double(hp) / disp
            if hpPerLiter > 200 { score += 15.0 }      // Turbocharged monsters
            else if hpPerLiter > 130 { score += 10.0 }  // Good modern engines
            else if hpPerLiter > 80 { score += 3.0 }    // Average
            else { score -= 8.0 }                        // Low output per liter
        }
        
        // Penalize massive displacement (8.0L V10 = not efficient)
        if let disp = displacement {
            if disp > 6.0 { score -= 15.0 }
            else if disp > 4.0 { score -= 5.0 }
            else if disp < 2.0 { score += 8.0 }
        }
        
        return max(5.0, min(99.0, score))
    }
    
    // MARK: - Helpers
    
    private static func clampStat(_ value: Int) -> Int {
        max(0, min(99, value))
    }
}

// MARK: - Convenience Extensions

extension CloudCard {
    /// Compute battle stats from this card's specs.
    /// Requires specs to be loaded separately (from CarSpecsService).
    func battleStats(specs: CarSpecs) -> BattleStats {
        let rarity = CardRarity(rawValue: self.rarity ?? "Common") ?? .common
        let category = specs.category ?? VehicleCategory(rawValue: self.color) // fallback
        return BattleStatsEngine.calculate(specs: specs, rarity: rarity, category: category)
    }
}

extension SavedCard {
    /// Compute battle stats from this card's embedded specs.
    func battleStats(rarity: CardRarity = .common) -> BattleStats {
        return BattleStatsEngine.calculate(specs: carSpecs, rarity: rarity, category: carSpecs.category)
    }
}

// MARK: - Synergy System

/// Card synergies give bonus stats when multiple cards in a battle hand share traits.
/// This creates a "deck-building metagame" where players think about which cards pair together.
enum SynergyType: String, Codable, CaseIterable {
    case brandBonus     = "Brand Bonus"        // 3+ same manufacturer
    case eraBonus       = "Era Bonus"          // All cards same decade
    case drivetrainSync = "Drivetrain Sync"    // All same drivetrain
    case engineFamily   = "Engine Family"      // All same engine type
    case categoryMatch  = "Category Match"     // All same vehicle category
    
    var icon: String {
        switch self {
        case .brandBonus:     return "building.2.fill"
        case .eraBonus:       return "clock.fill"
        case .drivetrainSync: return "gearshape.2.fill"
        case .engineFamily:   return "engine.combustion.fill"
        case .categoryMatch:  return "car.2.fill"
        }
    }
    
    var description: String {
        switch self {
        case .brandBonus:     return "+5% all stats with 3+ same brand"
        case .eraBonus:       return "+3% handling from same decade"
        case .drivetrainSync: return "+5% to best stat with matching drivetrain"
        case .engineFamily:   return "+4% power with same engine type"
        case .categoryMatch:  return "+3% overall with same category"
        }
    }
}

/// Result of synergy detection on a hand of cards
struct SynergyResult {
    let activeSynergies: [(SynergyType, String)]  // (type, detail like "BMW × 3")
    let statMultiplier: [BattleCategory: Double]   // Per-category multiplier from synergies
    
    static var none: SynergyResult {
        SynergyResult(activeSynergies: [], statMultiplier: [:])
    }
}

/// Detects active synergies in a hand of cards
struct SynergyDetector {
    
    /// Analyze a hand of cards + specs for active synergies.
    /// - Parameters:
    ///   - cards: The cards in the player's hand
    ///   - specsMap: Dictionary of card ID → CarSpecs
    /// - Returns: SynergyResult with active bonuses
    static func detect(cards: [CloudCard], specsMap: [String: CarSpecs]) -> SynergyResult {
        guard cards.count >= 2 else { return .none }
        
        var synergies: [(SynergyType, String)] = []
        var multipliers: [BattleCategory: Double] = [:]
        
        // --- BRAND BONUS: 3+ cards from same manufacturer ---
        let makes = cards.filter { $0.cardType == "vehicle" }.map { $0.make.lowercased() }
        let makeCounts = Dictionary(grouping: makes, by: { $0 }).mapValues { $0.count }
        if let topMake = makeCounts.max(by: { $0.value < $1.value }), topMake.value >= 3 {
            synergies.append((.brandBonus, "\(topMake.key.capitalized) × \(topMake.value)"))
            for cat in BattleCategory.allCases {
                multipliers[cat, default: 1.0] += 0.05
            }
        }
        
        // --- ERA BONUS: All vehicle cards from same decade ---
        let years = cards.compactMap { Int($0.year) }
        if years.count >= 2 {
            let decades = Set(years.map { ($0 / 10) * 10 })
            if decades.count == 1, let decade = decades.first {
                synergies.append((.eraBonus, "\(decade)s cars"))
                multipliers[.handling, default: 1.0] += 0.03
            }
        }
        
        // --- DRIVETRAIN SYNC: All same drivetrain ---
        let drivetrains = cards.compactMap { specsMap[$0.id]?.drivetrain?.uppercased() }
        if drivetrains.count >= 2, Set(drivetrains).count == 1 {
            synergies.append((.drivetrainSync, "\(drivetrains.first ?? "?") lineup"))
            // +5% to the best stat of each card (applied at battle time)
            // For simplicity, boost speed + handling
            multipliers[.speed, default: 1.0] += 0.03
            multipliers[.handling, default: 1.0] += 0.02
        }
        
        // --- ENGINE FAMILY: All same engine type (V8, I4, etc) ---
        let engines = cards.compactMap { specsMap[$0.id]?.engineType }
        let engineFamilies = engines.map { extractEngineFamily($0) }
        if engineFamilies.count >= 2, Set(engineFamilies).count == 1, let family = engineFamilies.first {
            synergies.append((.engineFamily, "\(family) crew"))
            multipliers[.power, default: 1.0] += 0.04
        }
        
        // --- CATEGORY MATCH: All same vehicle category ---
        let categories = cards.compactMap { specsMap[$0.id]?.category?.rawValue }
        if categories.count >= 2, Set(categories).count == 1, let cat = categories.first {
            synergies.append((.categoryMatch, "\(cat) squad"))
            // Flat +3% overall (approximated as small boost to all)
            for bc in BattleCategory.allCases {
                multipliers[bc, default: 1.0] += 0.03
            }
        }
        
        return SynergyResult(activeSynergies: synergies, statMultiplier: multipliers)
    }
    
    /// Extract engine family from engine type string (e.g. "3.0L V6 Twin-Turbo" → "V6")
    private static func extractEngineFamily(_ engine: String) -> String {
        let upper = engine.uppercased()
        let families = ["V12", "V10", "V8", "V6", "V4", "I6", "I4", "I3", "H6", "H4", "W12", "W16",
                        "ELECTRIC", "ROTARY", "FLAT-4", "FLAT-6", "BOXER"]
        return families.first(where: { upper.contains($0) }) ?? "OTHER"
    }
}
