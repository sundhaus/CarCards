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
    
    // MARK: - Quick Sell
    
    /// Coins received for quick-selling a card
    static let quickSellCoins = 250
    
    /// XP for quick-selling a card
    static let quickSellXP = 5
    
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
