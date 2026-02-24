//
//  RewardConfig.swift
//  CarCardCollector
//
//  Centralized reward definitions for XP and Coins.
//  All reward values live here — tune the economy from one file.
//

import Foundation

struct RewardConfig {
    
    // MARK: - Card Capture XP
    
    /// XP for capturing any car card
    static let cardCaptureXP = 25
    
    /// XP for capturing a driver card
    static let driverCaptureXP = 25
    
    /// XP for capturing a location card
    static let locationCaptureXP = 25
    
    // MARK: - Card Capture Coins
    
    /// Coins earned per car card capture
    static let cardCaptureCoins = 5
    
    /// Coins earned per driver card capture
    static let driverCaptureCoins = 5
    
    /// Coins earned per location card capture
    static let locationCaptureCoins = 5
    
    // MARK: - Marketplace XP
    
    /// XP for listing a card on the marketplace
    static let listCardXP = 10
    
    /// XP for completing a purchase (buyer)
    static let purchaseCardXP = 15
    
    /// XP for completing a sale (seller)
    static let soldCardXP = 15
    
    /// XP for placing a bid
    static let placeBidXP = 5
    
    // MARK: - Quick Sell (scaled by rarity)
    
    /// Base coins for quick-selling — overridden by rarity
    static let quickSellCoins = 50
    
    /// Coins received for quick-selling based on card rarity
    static func quickSellCoins(for rarity: CardRarity) -> Int {
        switch rarity {
        case .common:    return 50
        case .uncommon:  return 100
        case .rare:      return 250
        case .epic:      return 500
        case .legendary: return 1000
        }
    }
    
    /// XP for quick-selling based on card rarity
    static func quickSellXP(for rarity: CardRarity) -> Int {
        switch rarity {
        case .common:    return 5
        case .uncommon:  return 10
        case .rare:      return 20
        case .epic:      return 35
        case .legendary: return 50
        }
    }
    
    /// XP for quick-selling a card (fallback when rarity unknown)
    static let quickSellXP = 5
    
    // MARK: - Capture Bonuses (scaled by rarity)
    
    /// Bonus XP on top of base capture XP for rarer cards
    static func captureXP(for rarity: CardRarity) -> Int {
        switch rarity {
        case .common:    return cardCaptureXP         // 25
        case .uncommon:  return cardCaptureXP + 10    // 35
        case .rare:      return cardCaptureXP + 25    // 50
        case .epic:      return cardCaptureXP + 50    // 75
        case .legendary: return cardCaptureXP + 100   // 125
        }
    }
    
    /// Bonus coins on top of base capture coins for rarer cards
    static func captureCoins(for rarity: CardRarity) -> Int {
        switch rarity {
        case .common:    return cardCaptureCoins        // 5
        case .uncommon:  return cardCaptureCoins + 5    // 10
        case .rare:      return cardCaptureCoins + 15   // 20
        case .epic:      return cardCaptureCoins + 35   // 40
        case .legendary: return cardCaptureCoins + 70   // 75
        }
    }
    
    // MARK: - Social XP
    
    /// XP for following another user
    static let followUserXP = 5
    
    /// XP for receiving a new follower
    static let gainedFollowerXP = 5
    
    // MARK: - Daily Login
    
    /// Base XP for opening the app each day
    static let dailyLoginXP = 15
    
    /// Base coins for opening the app each day
    static let dailyLoginCoins = 10
    
    // MARK: - Streak Bonuses (multiplied by base daily values)
    
    /// Bonus XP at 3-day streak
    static let streak3BonusXP = 25
    
    /// Bonus XP at 7-day streak
    static let streak7BonusXP = 50
    
    /// Bonus coins at 7-day streak
    static let streak7BonusCoins = 25
    
    /// Bonus XP at 30-day streak
    static let streak30BonusXP = 150
    
    /// Bonus coins at 30-day streak
    static let streak30BonusCoins = 75
    
    // MARK: - Level-Up Coin Bonus
    
    /// Coins awarded on level-up = newLevel × this multiplier
    static let levelUpCoinMultiplier = 50
    
    /// Calculate coins for reaching a specific level
    static func levelUpCoins(for newLevel: Int) -> Int {
        return newLevel * levelUpCoinMultiplier
    }
    
    // MARK: - Starter Grant
    
    /// Coins given to brand-new users on account creation
    static let starterCoins = 500
    
    // MARK: - Head-to-Head (kept in sync with HeadToHeadService constants)
    // These are defined in HeadToHeadService.swift — listed here for reference only.
    // voterXP = 5
    // voterCorrectPickXP = 20
    // voterDuoSingleXP = 15
    // voterDuoPerfectXP = 40
    // winnerXP = 25
    // loserXP = 10
    // correctPickCoins = 10
}
