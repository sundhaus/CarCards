//
//  PerformanceModService.swift
//  Car Collector
//
//  Realistic car modification system — boost stats through mods that match
//  real-world tuning. A modded WRX starts with base specs but players can
//  install intake, exhaust, turbo, suspension, etc. to bring the card
//  closer to their actual build.
//
//  Each mod:
//    - Has a realistic name and description
//    - Only boosts stats that would actually change from that mod
//    - Costs coins (scales with mod tier and card rarity)
//    - Is permanent and tracked per-card in Firestore
//    - Stacks with other mods (diminishing returns at high levels)
//
//  Mod tiers: Stage 1 (bolt-on) → Stage 2 (serious) → Stage 3 (built)
//

import Foundation
import FirebaseFirestore

// MARK: - Mod Categories

/// Real-world modification categories. Each affects specific stats.
enum ModCategory: String, Codable, CaseIterable, Identifiable {
    // Power mods
    case intake       = "Cold Air Intake"
    case exhaust      = "Performance Exhaust"
    case tune         = "ECU Tune"
    case turbo        = "Turbo / Supercharger"
    case intercooler  = "Intercooler Upgrade"
    case fuelSystem   = "Fuel System"
    case headers      = "Headers"
    
    // Handling mods
    case suspension   = "Coilover Suspension"
    case sway         = "Sway Bars"
    case brakes       = "Big Brake Kit"
    case tires        = "Performance Tires"
    case alignment    = "Track Alignment"
    
    // Speed mods
    case weight       = "Weight Reduction"
    case aero         = "Aero Kit"
    case gearing      = "Short Throw / Final Drive"
    
    // Efficiency mods
    case hybrid       = "Hybrid Conversion"
    case ecoTune      = "Eco Tune"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .intake:      return "wind"
        case .exhaust:     return "smoke.fill"
        case .tune:        return "cpu"
        case .turbo:       return "tornado"
        case .intercooler: return "snowflake"
        case .fuelSystem:  return "fuelpump.fill"
        case .headers:     return "arrow.up.forward"
        case .suspension:  return "arrow.up.and.down"
        case .sway:        return "arrow.left.arrow.right"
        case .brakes:      return "circle.circle"
        case .tires:       return "circle.dashed"
        case .alignment:   return "ruler"
        case .weight:      return "scalemass"
        case .aero:        return "wind.snow"
        case .gearing:     return "gearshape"
        case .hybrid:      return "bolt.batteryblock"
        case .ecoTune:     return "leaf.fill"
        }
    }
    
    var description: String {
        switch self {
        case .intake:      return "Better airflow for more power"
        case .exhaust:     return "Free-flowing exhaust adds HP and sound"
        case .tune:        return "Optimized fuel maps and timing"
        case .turbo:       return "Forced induction — big power gains"
        case .intercooler: return "Cooler intake temps for turbo setups"
        case .fuelSystem:  return "Injectors and pump to support more power"
        case .headers:     return "Equal-length headers improve exhaust flow"
        case .suspension:  return "Adjustable height and damping"
        case .sway:        return "Reduce body roll in corners"
        case .brakes:      return "Better stopping power and fade resistance"
        case .tires:       return "Stickier rubber for more grip"
        case .alignment:   return "Optimized camber and toe for cornering"
        case .weight:      return "Strip interior, lighter wheels, carbon panels"
        case .aero:        return "Splitter, wing, diffuser — downforce"
        case .gearing:     return "Shorter gears for quicker acceleration"
        case .hybrid:      return "Electric motor assist"
        case .ecoTune:     return "Efficiency-focused calibration"
        }
    }
    
    /// Which battle stats this mod category actually affects, and by how much.
    /// Values are base boosts for Stage 1 — multiplied by stage level.
    var statBoosts: [StatBoost] {
        switch self {
        // Power mods → mainly HP and torque
        case .intake:
            return [.init(.power, 2), .init(.efficiency, 1)]
        case .exhaust:
            return [.init(.power, 3), .init(.speed, 1)]
        case .tune:
            return [.init(.power, 4), .init(.speed, 2), .init(.efficiency, 1)]
        case .turbo:
            return [.init(.power, 7), .init(.speed, 5), .init(.efficiency, -2)]
        case .intercooler:
            return [.init(.power, 2), .init(.efficiency, 1)]
        case .fuelSystem:
            return [.init(.power, 3)]
        case .headers:
            return [.init(.power, 3), .init(.speed, 1)]
            
        // Handling mods → mainly handling
        case .suspension:
            return [.init(.handling, 5), .init(.speed, 1)]
        case .sway:
            return [.init(.handling, 3)]
        case .brakes:
            return [.init(.handling, 3), .init(.speed, 1)]
        case .tires:
            return [.init(.handling, 5), .init(.speed, 2)]
        case .alignment:
            return [.init(.handling, 3)]
            
        // Speed mods → mainly acceleration and top speed
        case .weight:
            return [.init(.speed, 4), .init(.handling, 3), .init(.efficiency, 2)]
        case .aero:
            return [.init(.speed, 3), .init(.handling, 2)]
        case .gearing:
            return [.init(.speed, 5), .init(.efficiency, -1)]
            
        // Efficiency mods
        case .hybrid:
            return [.init(.efficiency, 8), .init(.power, 2)]
        case .ecoTune:
            return [.init(.efficiency, 5), .init(.power, -1)]
        }
    }
    
    /// Which stage tiers are available for this mod
    var maxStage: Int {
        switch self {
        case .turbo, .tune, .suspension, .tires:
            return 3  // These have Stage 1–3
        case .intake, .exhaust, .brakes, .weight, .aero, .gearing, .headers:
            return 2  // Stage 1–2
        default:
            return 1  // Single stage only
        }
    }
}

// MARK: - Stat Boost

struct StatBoost: Codable {
    let category: String  // BattleCategory rawValue
    let amount: Int       // Base points added (can be negative)
    
    init(_ cat: BattleCategory, _ amount: Int) {
        self.category = cat.rawValue
        self.amount = amount
    }
    
    var battleCategory: BattleCategory? {
        BattleCategory(rawValue: category)
    }
}

// MARK: - Applied Mod (stored per-card)

struct AppliedMod: Codable, Identifiable {
    let id: String           // UUID
    let modCategory: String  // ModCategory rawValue
    let stage: Int           // 1, 2, or 3
    let appliedAt: Date
    let coinCost: Int        // What the player paid
    
    var category: ModCategory? {
        ModCategory(rawValue: modCategory)
    }
    
    var toDictionary: [String: Any] {
        [
            "id": id,
            "modCategory": modCategory,
            "stage": stage,
            "appliedAt": Timestamp(date: appliedAt),
            "coinCost": coinCost
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> AppliedMod? {
        guard let id = dict["id"] as? String,
              let modCategory = dict["modCategory"] as? String,
              let stage = dict["stage"] as? Int else { return nil }
        
        return AppliedMod(
            id: id,
            modCategory: modCategory,
            stage: stage,
            appliedAt: (dict["appliedAt"] as? Timestamp)?.dateValue() ?? Date(),
            coinCost: dict["coinCost"] as? Int ?? 0
        )
    }
}

// MARK: - Mod Pricing

struct ModPricing {
    
    /// Coin cost for a mod, based on mod category + stage + card rarity.
    /// Higher rarity cards cost more to mod (the base vehicle is worth more).
    static func coinCost(mod: ModCategory, stage: Int, cardRarity: CardRarity) -> Int {
        let baseCost: Int
        switch mod {
        // Big mods cost more
        case .turbo:     baseCost = 200
        case .tune:      baseCost = 120
        case .suspension, .tires: baseCost = 100
        case .brakes, .exhaust, .weight, .aero: baseCost = 80
        case .intake, .headers, .gearing, .sway, .alignment: baseCost = 50
        case .intercooler, .fuelSystem: baseCost = 60
        case .hybrid:    baseCost = 300
        case .ecoTune:   baseCost = 40
        }
        
        // Stage multiplier: Stage 2 = 2x, Stage 3 = 4x
        let stageMultiplier: Double
        switch stage {
        case 1:  stageMultiplier = 1.0
        case 2:  stageMultiplier = 2.0
        case 3:  stageMultiplier = 4.0
        default: stageMultiplier = 1.0
        }
        
        // Rarity multiplier: modding a Legendary costs more
        let rarityMultiplier: Double
        switch cardRarity {
        case .common:    rarityMultiplier = 1.0
        case .uncommon:  rarityMultiplier = 1.2
        case .rare:      rarityMultiplier = 1.5
        case .epic:      rarityMultiplier = 2.0
        case .legendary: rarityMultiplier = 3.0
        }
        
        return Int(Double(baseCost) * stageMultiplier * rarityMultiplier)
    }
}

// MARK: - Mod Stat Calculator (nonisolated — usable from any context)

struct ModStatCalculator {
    
    /// Sum all stat boosts from applied mods on a card.
    /// Returns a dictionary of BattleCategory → total bonus points.
    static func totalBoosts(from mods: [AppliedMod]) -> [BattleCategory: Int] {
        var boosts: [BattleCategory: Int] = [:]
        
        for mod in mods {
            guard let category = mod.category else { continue }
            
            for boost in category.statBoosts {
                guard let battleCat = boost.battleCategory else { continue }
                
                // Stage multiplier with diminishing returns
                // Stage 1 = 1.0x, Stage 2 = 1.7x, Stage 3 = 2.3x
                let stageMultiplier: Double
                switch mod.stage {
                case 1:  stageMultiplier = 1.0
                case 2:  stageMultiplier = 1.7
                case 3:  stageMultiplier = 2.3
                default: stageMultiplier = 1.0
                }
                
                let adjustedBoost = Int(Double(boost.amount) * stageMultiplier)
                boosts[battleCat, default: 0] += adjustedBoost
            }
        }
        
        return boosts
    }
}

// MARK: - Performance Mod Service

@MainActor
class PerformanceModService: ObservableObject {
    static let shared = PerformanceModService()
    
    private let db = FirebaseManager.shared.db
    
    @Published var isApplyingMod = false
    
    private init() {}
    
    // MARK: - Get Applied Mods for Card
    
    /// Fetch all mods applied to a card from Firestore
    func getAppliedMods(cardId: String) async throws -> [AppliedMod] {
        let doc = try await db.collection("cards").document(cardId).getDocument()
        guard let data = doc.data(),
              let modsData = data["appliedMods"] as? [[String: Any]] else {
            return []
        }
        return modsData.compactMap { AppliedMod.fromDictionary($0) }
    }
    
    // MARK: - Calculate Total Stat Boosts from Mods
    
    /// Convenience wrapper — delegates to nonisolated ModStatCalculator
    static func totalBoosts(from mods: [AppliedMod]) -> [BattleCategory: Int] {
        ModStatCalculator.totalBoosts(from: mods)
    }
    
    // MARK: - Check Available Mods for Card
    
    /// Returns which mods are available for a card (not yet installed or next stage).
    func availableMods(for cardId: String, appliedMods: [AppliedMod]) -> [(ModCategory, Int)] {
        var available: [(ModCategory, Int)] = []
        
        for mod in ModCategory.allCases {
            let currentStage = appliedMods
                .filter { $0.modCategory == mod.rawValue }
                .map { $0.stage }
                .max() ?? 0
            
            if currentStage < mod.maxStage {
                available.append((mod, currentStage + 1))
            }
        }
        
        return available
    }
    
    // MARK: - Apply Mod
    
    /// Apply a mod to a card. Deducts coins, stores mod on card, recalculates power.
    func applyMod(
        cardId: String,
        mod: ModCategory,
        stage: Int,
        cardRarity: CardRarity
    ) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        isApplyingMod = true
        defer { isApplyingMod = false }
        
        let cost = ModPricing.coinCost(mod: mod, stage: stage, cardRarity: cardRarity)
        
        // Verify card ownership
        let cardDoc = try await db.collection("cards").document(cardId).getDocument()
        guard let cardData = cardDoc.data(),
              cardData["ownerId"] as? String == uid else {
            throw ModError.notOwner
        }
        
        // Verify player has enough coins
        let levelSystem = LevelSystem()
        guard levelSystem.spendCoins(cost) else {
            throw ModError.insufficientCoins
        }
        
        // Build new mod entry
        let newMod = AppliedMod(
            id: UUID().uuidString,
            modCategory: mod.rawValue,
            stage: stage,
            appliedAt: Date(),
            coinCost: cost
        )
        
        // Append to card's mod array in Firestore
        try await db.collection("cards").document(cardId).updateData([
            "appliedMods": FieldValue.arrayUnion([newMod.toDictionary])
        ])
        
        // Recalculate and store power rating
        let allMods = try await getAppliedMods(cardId: cardId)
        let specs = await loadSpecs(cardData: cardData)
        let rarity = CardRarity(rawValue: cardData["rarity"] as? String ?? "Common") ?? .common
        let power = PowerRating.calculate(specs: specs, rarity: rarity, mods: allMods)
        
        try await db.collection("cards").document(cardId).updateData([
            "powerRating": power.total
        ])
        
        print("🔧 Applied \(mod.rawValue) Stage \(stage) to card \(cardId) for \(cost) coins → Power: \(power.total)")
    }
    
    // MARK: - Helpers
    
    private func loadSpecs(cardData: [String: Any]) async -> CarSpecs {
        // Build CarSpecs from the vehicleSpecs subcollection or card data
        let make = cardData["make"] as? String ?? ""
        let model = cardData["model"] as? String ?? ""
        let year = cardData["year"] as? String ?? ""
        
        // Try fetching from shared Firestore vehicleSpecs cache
        let docId = "\(make)_\(model)_\(year)"
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        
        do {
            let doc = try await db.collection("vehicleSpecs").document(docId).getDocument()
            if let data = doc.data() {
                return CarSpecs(
                    horsepower: parseIntFrom(data["horsepower"]),
                    torque: parseIntFrom(data["torque"]),
                    zeroToSixty: parseDoubleFrom(data["zeroToSixty"]),
                    topSpeed: parseIntFrom(data["topSpeed"]),
                    engineType: data["engine"] as? String,
                    displacement: nil,
                    transmission: data["transmission"] as? String,
                    drivetrain: data["drivetrain"] as? String
                )
            }
        } catch {
            print("⚠️ Failed to load specs for mod: \(error)")
        }
        
        return .empty
    }
    
    private func parseIntFrom(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let s = value as? String {
            let cleaned = s.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            return Int(cleaned)
        }
        return nil
    }
    
    private func parseDoubleFrom(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let s = value as? String {
            let cleaned = s.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            return Double(cleaned)
        }
        return nil
    }
}

// MARK: - Errors

enum ModError: LocalizedError {
    case notOwner
    case insufficientCoins
    case maxStageReached
    case modNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notOwner:          return "You don't own this card"
        case .insufficientCoins: return "Not enough coins"
        case .maxStageReached:   return "This mod is already at max stage"
        case .modNotAvailable:   return "This mod isn't available for this card"
        }
    }
}
