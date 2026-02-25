//
//  RarityUpgradeConfig.swift
//  Car Collector
//
//  Centralized configuration for the rarity upgrade system.
//  Two paths: Free (Evolution Points from battles) or Paid (Gems).
//

import Foundation

struct RarityUpgradeConfig {
    
    // MARK: - Evolution Point Requirements (Free Path)
    
    /// Points needed to upgrade FROM this rarity to the next tier
    static func evolutionPointsRequired(from rarity: CardRarity) -> Int {
        switch rarity {
        case .common:    return 100   // ~20 battles
        case .uncommon:  return 200   // ~40 battles
        case .rare:      return 400   // ~80 battles
        case .epic:      return 800   // ~160 battles
        case .legendary: return 0     // Max tier — cannot upgrade
        }
    }
    
    // MARK: - Gem Costs (Premium Path)
    
    /// Gems needed to instantly upgrade FROM this rarity to the next tier
    static func gemCost(from rarity: CardRarity) -> Int {
        switch rarity {
        case .common:    return 100
        case .uncommon:  return 300
        case .rare:      return 800
        case .epic:      return 2_000
        case .legendary: return 0    // Max tier
        }
    }
    
    // MARK: - Unlock Gate Requirements
    
    /// Minimum user level required to unlock upgrades TO this rarity
    static func requiredLevel(for targetRarity: CardRarity) -> Int {
        switch targetRarity {
        case .common:    return 1   // Already common
        case .uncommon:  return 5
        case .rare:      return 15
        case .epic:      return 30
        case .legendary: return 50
        }
    }
    
    /// Minimum total cards owned to unlock upgrades TO this rarity
    static func requiredCardsOwned(for targetRarity: CardRarity) -> Int {
        switch targetRarity {
        case .common:    return 0
        case .uncommon:  return 10
        case .rare:      return 50
        case .epic:      return 100
        case .legendary: return 200
        }
    }
    
    /// Minimum battle wins to unlock upgrades TO this rarity (0 = no requirement)
    static func requiredBattleWins(for targetRarity: CardRarity) -> Int {
        switch targetRarity {
        case .common:    return 0
        case .uncommon:  return 0
        case .rare:      return 0
        case .epic:      return 25
        case .legendary: return 100
        }
    }
    
    // MARK: - Evolution Point Earning Rates
    
    /// Points earned for a 1v1 WIN
    static let solo1v1Win = 5
    
    /// Points earned for a 1v1 LOSS
    static let solo1v1Loss = 2
    
    /// Points earned for 1v1 MVP (most votes overall)
    static let solo1v1MVP = 10
    
    /// Points earned for a 2v2 WIN
    static let duo2v2Win = 8
    
    /// Points earned for a 2v2 LOSS
    static let duo2v2Loss = 3
    
    /// Points earned for 2v2 team MVP
    static let duo2v2TeamMVP = 15
    
    // MARK: - Next Rarity Helper
    
    /// Returns the next rarity tier, or nil if already max
    static func nextRarity(from current: CardRarity) -> CardRarity? {
        switch current {
        case .common:    return .uncommon
        case .uncommon:  return .rare
        case .rare:      return .epic
        case .epic:      return .legendary
        case .legendary: return nil
        }
    }
    
    /// Whether the given rarity can be upgraded
    static func canUpgrade(from rarity: CardRarity) -> Bool {
        return rarity != .legendary
    }
    
    // MARK: - Gem IAP Product IDs
    
    /// StoreKit product identifiers for gem packs
    static let gemProductIDs: [String] = [
        "com.carcollector.gems.100",
        "com.carcollector.gems.550",
        "com.carcollector.gems.1200",
        "com.carcollector.gems.2500",
        "com.carcollector.gems.6500"
    ]
    
    /// Gem amounts per product
    static let gemAmounts: [String: Int] = [
        "com.carcollector.gems.100":  100,
        "com.carcollector.gems.550":  550,
        "com.carcollector.gems.1200": 1_200,
        "com.carcollector.gems.2500": 2_500,
        "com.carcollector.gems.6500": 6_500
    ]
}
