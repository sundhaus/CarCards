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
    /// Uses exponential curve for better spread at the top end.
    /// Sub-2.0s = 99, 2.3s = ~94, 2.6s = ~89, 3.0s = ~83, 4.0s = ~65, 6.0s = ~40, 10s+ = ~15
    private static func calculateAccelScore(zeroToSixty: Double?) -> Double {
        guard let zts = zeroToSixty, zts > 0 else { return 30.0 }
        
        // Exponential decay: faster 0-60 = exponentially higher score
        // This creates meaningful gaps between 2.0s, 2.5s, 3.0s, 3.5s cars
        if zts <= 1.8 { return 99.0 }
        if zts <= 4.0 {
            // Top tier: 1.8s–4.0s → 99–60 with steep curve
            let normalized = (zts - 1.8) / (4.0 - 1.8)  // 0.0 to 1.0
            let curved = pow(normalized, 0.7)              // Steeper at the start
            return 99.0 - (curved * 39.0)
        }
        if zts <= 8.0 {
            // Mid tier: 4.0s–8.0s → 60–25
            let normalized = (zts - 4.0) / (8.0 - 4.0)
            return 60.0 - (normalized * 35.0)
        }
        // Slow: 8s+ → 25–5
        let normalized = min(1.0, (zts - 8.0) / 8.0)
        return max(5.0, 25.0 - (normalized * 20.0))
    }
    
    /// Top speed score: mph → 0-99 rating
    /// Logarithmic curve for better spread across entire range.
    /// 280+ mph = 99, 260 = ~96, 217 = ~87, 155 = ~68, 120 = ~52, 90 = ~35
    private static func calculateTopSpeedScore(topSpeed: Int?) -> Double {
        guard let ts = topSpeed, ts > 0 else { return 30.0 }
        
        if ts >= 280 { return 99.0 }
        if ts <= 60 { return 8.0 }
        
        // Logarithmic mapping: big spread at top, still meaningful at bottom
        // Maps 60–280 mph to 8–99
        let normalized = Double(ts - 60) / Double(280 - 60)  // 0.0 to 1.0
        let curved = pow(normalized, 0.75)  // Slight compression at very top, spread in mid
        return 8.0 + (curved * 91.0)
    }
    
    /// Power score from HP + torque → 0-99
    /// Continuous curve through entire range — no hard caps.
    /// 1500 HP = ~97, 1000 HP = ~90, 700 HP = ~82, 500 HP = ~73, 300 HP = ~55, 150 HP = ~35
    private static func calculatePowerScore(hp: Int?, torque: Int?) -> Double {
        let hpScore: Double
        if let hp = hp, hp > 0 {
            // Logarithmic curve: huge spread from 100-800hp, meaningful gaps above 1000hp
            // ln(hp/50) / ln(2000/50) maps 50-2000hp to 0-1, then scale to 10-99
            let normalized = log(Double(hp) / 50.0) / log(2000.0 / 50.0)
            hpScore = min(99.0, max(5.0, 5.0 + normalized * 94.0))
        } else {
            hpScore = 25.0
        }
        
        let tqScore: Double
        if let tq = torque, tq > 0 {
            // Same logarithmic approach for torque
            // Maps 50-1500 lb-ft to full range
            let normalized = log(Double(tq) / 30.0) / log(1500.0 / 30.0)
            tqScore = min(99.0, max(5.0, 5.0 + normalized * 94.0))
        } else {
            tqScore = 25.0
        }
        
        // Weight HP slightly more than torque
        return hpScore * 0.6 + tqScore * 0.4
    }
    
    /// Handling score based on drivetrain, category, weight estimate → 0-99
    /// Uses power-to-displacement as a proxy for power-to-weight ratio.
    /// Lighter, more focused cars score higher.
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
        case .hypercar:      score += 25.0
        case .supercar:      score += 22.0
        case .sportsCar:     score += 20.0
        case .track:         score += 28.0
        case .rally:         score += 18.0
        case .coupe:         score += 12.0
        case .hatchback:     score += 10.0
        case .convertible:   score += 8.0
        case .sedan:         score += 3.0
        case .electric:      score += 8.0
        case .hybrid:        score += 3.0
        case .wagon:         score -= 2.0
        case .luxury:        score -= 5.0
        case .muscle:        score -= 5.0
        case .suv:           score -= 12.0
        case .truck:         score -= 18.0
        case .van:           score -= 20.0
        case .offRoad:       score -= 8.0
        case .classic:       score += 0.0
        case .concept:       score += 15.0
        case .none:          break
        }
        
        // Power-to-displacement ratio as weight proxy
        // Higher ratio = more power per liter = likely lighter and more focused
        // P1 (903hp / 3.8L = 238) vs Chiron (1500hp / 8.0L = 188)
        if let disp = displacement, let hp = hp, disp > 0 {
            let powerToDisp = Double(hp) / disp
            if powerToDisp > 250 {
                score += 10.0     // Ultra efficient (turbo 4-cyl monsters, like AMG A45)
            } else if powerToDisp > 200 {
                score += 7.0      // Very focused (P1, 911 Turbo)
            } else if powerToDisp > 150 {
                score += 4.0      // Good (most turbo sports cars)
            } else if powerToDisp > 100 {
                score += 1.0      // Average
            } else if powerToDisp < 70 {
                score -= 6.0      // Heavy/underpowered (big lazy V8 trucks)
            } else if powerToDisp < 90 {
                score -= 3.0      // Below average
            }
            
            // Displacement as raw weight proxy (smaller engine = usually lighter car)
            if disp <= 2.0 {
                score += 5.0      // Light and nimble (Miata, BRZ)
            } else if disp <= 3.0 {
                score += 3.0      // Sporty (Cayman, Supra)
            } else if disp <= 4.5 {
                score += 0.0      // Neutral (most V6/V8 sports cars)
            } else if disp >= 6.0 {
                score -= 5.0      // Heavy (big V8/V10/W16)
            } else if disp >= 5.0 {
                score -= 2.0      // Somewhat heavy
            }
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
