//
//  LevelGating.swift
//  Car Collector
//
//  Central configuration for level-gated features, milestone rewards,
//  and prestige system. All level thresholds live here — tune progression
//  from one file.
//

import SwiftUI

// MARK: - Feature Unlock Definitions

/// Every feature that becomes available at a specific level.
enum GatedFeature: String, CaseIterable, Identifiable {
    case marketplace       // Tab 3
    case headToHead        // H2H from Home
    case customBackgrounds // Card customize → backgrounds tab
    case animatedEffects   // Card customize → animated holo / shimmer effects
    case prestigeBorder    // Level badge appears on your cards in Explore
    case duoBattles        // Duo team mode in H2H
    
    var id: String { rawValue }
    
    /// The level at which this feature unlocks.
    var requiredLevel: Int {
        switch self {
        case .marketplace:       return 3
        case .headToHead:        return 5
        case .customBackgrounds: return 10
        case .animatedEffects:   return 15
        case .prestigeBorder:    return 25
        case .duoBattles:        return 30
        }
    }
    
    /// Human-readable name shown in unlock popups and profile.
    var displayName: String {
        switch self {
        case .marketplace:       return "Marketplace"
        case .headToHead:        return "Head-to-Head"
        case .customBackgrounds: return "Custom Backgrounds"
        case .animatedEffects:   return "Animated Effects"
        case .prestigeBorder:    return "Prestige Border"
        case .duoBattles:        return "Duo Battles"
        }
    }
    
    /// Short description of the feature.
    var unlockDescription: String {
        switch self {
        case .marketplace:       return "Buy, sell, and trade cards with other collectors"
        case .headToHead:        return "Challenge friends to head-to-head voting battles"
        case .customBackgrounds: return "Add custom backgrounds to your cards"
        case .animatedEffects:   return "Unlock holographic and shimmer effects for cards"
        case .prestigeBorder:    return "Your level badge appears on every card you capture"
        case .duoBattles:        return "Team up with a friend for duo H2H battles"
        }
    }
    
    /// SF Symbol shown in unlock celebration.
    var iconName: String {
        switch self {
        case .marketplace:       return "cart.fill"
        case .headToHead:        return "bolt.fill"
        case .customBackgrounds: return "photo.artframe"
        case .animatedEffects:   return "sparkles"
        case .prestigeBorder:    return "shield.checkered"
        case .duoBattles:        return "person.2.fill"
        }
    }
    
    /// Gradient colors for the unlock celebration.
    var themeColors: [Color] {
        switch self {
        case .marketplace:       return [.green, .mint]
        case .headToHead:        return [.orange, .red]
        case .customBackgrounds: return [.purple, .indigo]
        case .animatedEffects:   return [.cyan, .blue]
        case .prestigeBorder:    return [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.85, green: 0.65, blue: 0.13)]
        case .duoBattles:        return [.pink, .orange]
        }
    }
}

// MARK: - Milestone Rewards

/// Every 10 levels, the user gets a free premium crate.
struct LevelMilestone {
    let level: Int
    let rewardCoins: Int
    let rewardGems: Int
    let guaranteedMinRarity: CardRarity  // Guaranteed rarity for the free crate
    let crateLabel: String
    
    /// Predefined milestones every 10 levels (up to 100, then pattern repeats).
    static func milestone(for level: Int) -> LevelMilestone? {
        guard level > 0 && level % 10 == 0 else { return nil }
        
        let tier = min(level / 10, 10) // Cap scaling at level 100
        
        return LevelMilestone(
            level: level,
            rewardCoins: tier * 500,
            rewardGems: tier * 5,
            guaranteedMinRarity: milestoneRarity(for: level),
            crateLabel: "Level \(level) Premium Crate"
        )
    }
    
    private static func milestoneRarity(for level: Int) -> CardRarity {
        switch level {
        case 10:           return .rare
        case 20:           return .rare
        case 30:           return .rare
        case 40:           return .epic
        case 50:           return .epic
        case 60...70:      return .epic
        case 80...90:      return .epic
        case 100:          return .legendary
        default:           return .rare  // Default for levels > 100
        }
    }
}

// MARK: - Level Gating Helpers

struct LevelGating {
    
    /// Check whether the user's current level unlocks a feature.
    static func isUnlocked(_ feature: GatedFeature, at level: Int) -> Bool {
        level >= feature.requiredLevel
    }
    
    /// Returns the next feature the user will unlock (nil if all unlocked).
    static func nextUnlock(at level: Int) -> GatedFeature? {
        GatedFeature.allCases
            .filter { $0.requiredLevel > level }
            .sorted { $0.requiredLevel < $1.requiredLevel }
            .first
    }
    
    /// Returns features that were just unlocked by reaching `newLevel` (came from `newLevel - 1`).
    static func newlyUnlocked(at newLevel: Int) -> [GatedFeature] {
        GatedFeature.allCases.filter { $0.requiredLevel == newLevel }
    }
    
    /// Returns all features with their lock/unlock status at a given level.
    static func allFeatureStatus(at level: Int) -> [(feature: GatedFeature, unlocked: Bool)] {
        GatedFeature.allCases
            .sorted { $0.requiredLevel < $1.requiredLevel }
            .map { ($0, isUnlocked($0, at: level)) }
    }
    
    /// Returns the next milestone level (multiple of 10) above the current level.
    static func nextMilestoneLevel(at level: Int) -> Int {
        ((level / 10) + 1) * 10
    }
    
    /// Whether this level is a milestone level.
    static func isMilestone(_ level: Int) -> Bool {
        level > 0 && level % 10 == 0
    }
    
    /// Whether the user has prestige badge visibility (level 25+).
    static func hasPrestigeBorder(at level: Int) -> Bool {
        isUnlocked(.prestigeBorder, at: level)
    }
}

// MARK: - UserDefaults Tracking for Claimed Milestones

extension LevelGating {
    
    private static let claimedMilestonesKey = "claimedLevelMilestones"
    
    /// Returns set of milestone levels already claimed.
    static func claimedMilestones() -> Set<Int> {
        let array = UserDefaults.standard.array(forKey: claimedMilestonesKey) as? [Int] ?? []
        return Set(array)
    }
    
    /// Mark a milestone as claimed.
    static func claimMilestone(_ level: Int) {
        var claimed = claimedMilestones()
        claimed.insert(level)
        UserDefaults.standard.set(Array(claimed), forKey: claimedMilestonesKey)
    }
    
    /// Whether a milestone has already been claimed.
    static func isMilestoneClaimed(_ level: Int) -> Bool {
        claimedMilestones().contains(level)
    }
    
    /// Returns unclaimed milestones up to and including the current level.
    static func unclaimedMilestones(at level: Int) -> [LevelMilestone] {
        let claimed = claimedMilestones()
        var results: [LevelMilestone] = []
        var l = 10
        while l <= level {
            if !claimed.contains(l), let ms = LevelMilestone.milestone(for: l) {
                results.append(ms)
            }
            l += 10
        }
        return results
    }
}
