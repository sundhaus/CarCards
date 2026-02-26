//
//  CardRarity.swift
//  CarCardCollector
//
//  Rarity tiers for vehicle cards — drives economy values and visual badges.
//  Assigned by Gemini AI during vehicle identification based on real-world rarity.
//

import SwiftUI

enum CardRarity: String, Codable, CaseIterable, Comparable {
    case common     = "Common"
    case uncommon   = "Uncommon"
    case rare       = "Rare"
    case epic       = "Epic"
    case legendary  = "Legendary"
    
    // MARK: - Sort Order (for Comparable)
    
    var sortIndex: Int {
        switch self {
        case .common:    return 0
        case .uncommon:  return 1
        case .rare:      return 2
        case .epic:      return 3
        case .legendary: return 4
        }
    }
    
    static func < (lhs: CardRarity, rhs: CardRarity) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }
    
    // MARK: - Display
    
    var emoji: String {
        switch self {
        case .common:    return "⚪"
        case .uncommon:  return "🟢"
        case .rare:      return "🔵"
        case .epic:      return "🟣"
        case .legendary: return "🟡"
        }
    }
    
    /// SF Symbol icon for rarity badges — replaces emoji in card views
    var iconName: String {
        switch self {
        case .common:    return "circle"
        case .uncommon:  return "shield"
        case .rare:      return "diamond"
        case .epic:      return "star.fill"
        case .legendary: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .common:    return Color(.systemGray)
        case .uncommon:  return Color(.systemGreen)
        case .rare:      return Color(.systemBlue)
        case .epic:      return Color(.systemPurple)
        case .legendary: return Color(.systemYellow)
        }
    }
    
    /// Gradient for card borders / badges
    var gradient: LinearGradient {
        switch self {
        case .common:
            return LinearGradient(
                colors: [Color(.systemGray4), Color(.systemGray2)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .uncommon:
            return LinearGradient(
                colors: [Color.green.opacity(0.7), Color.green],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .rare:
            return LinearGradient(
                colors: [Color.blue.opacity(0.7), Color.cyan],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .epic:
            return LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .legendary:
            return LinearGradient(
                colors: [Color.yellow, Color.orange],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
    
    var description: String {
        switch self {
        case .common:    return "Everyday vehicles"
        case .uncommon:  return "Above-average rides"
        case .rare:      return "Enthusiast favorites"
        case .epic:      return "Supercars & high luxury"
        case .legendary: return "Hypercars & unicorns"
        }
    }
    
    /// Asset name for the rarity border PNG
    var borderAssetName: String {
        switch self {
        case .common:    return "Border_Common"
        case .uncommon:  return "Border_Uncommon"
        case .rare:      return "Border_Rare"
        case .epic:      return "Border_Epic"
        case .legendary: return "Border_Legendary"
        }
    }
    
    /// Next rarity tier, or nil if already max
    var nextRarity: CardRarity? {
        switch self {
        case .common:    return .uncommon
        case .uncommon:  return .rare
        case .rare:      return .epic
        case .epic:      return .legendary
        case .legendary: return nil
        }
    }
    
    /// Whether this rarity can be upgraded
    var canUpgrade: Bool {
        return self != .legendary
    }
    
    // MARK: - Visual Effect Configuration
    
    /// Whether this rarity gets animated border effects (shimmer, particles)
    var hasAnimatedBorder: Bool {
        return self >= .epic
    }
    
    /// Whether this rarity gets the holographic/prismatic surface effect
    var hasHolographicSurface: Bool {
        return self == .legendary
    }
    
    /// Whether this rarity gets the full-bleed art treatment
    /// (removes standard border, goes edge-to-edge with subtle overlay)
    var hasFullBleedArt: Bool {
        return self >= .epic
    }
    
    /// Whether the card back shows enhanced detail (description, extra stats)
    var hasEnhancedCardBack: Bool {
        return self >= .rare
    }
    
    /// Whether the card back shows animated effects (shimmer, glow)
    var hasAnimatedCardBack: Bool {
        return self >= .epic
    }
    
    /// Intensity of the card tilt effect (higher rarity = more dramatic)
    var tiltIntensity: Double {
        switch self {
        case .common:    return 0.6
        case .uncommon:  return 0.8
        case .rare:      return 1.0
        case .epic:      return 1.2
        case .legendary: return 1.5
        }
    }
    
    /// Duration of the reveal animation (higher rarity = more build-up)
    var revealBuildUpDuration: Double {
        switch self {
        case .common:    return 0.8
        case .uncommon:  return 1.0
        case .rare:      return 1.2
        case .epic:      return 1.5
        case .legendary: return 2.0
        }
    }
    
    /// Background colors for the rarity card back
    var cardBackGradient: [Color] {
        switch self {
        case .common:
            return [Color(red: 0.15, green: 0.15, blue: 0.2), Color(red: 0.08, green: 0.08, blue: 0.12)]
        case .uncommon:
            return [Color(red: 0.08, green: 0.2, blue: 0.12), Color(red: 0.05, green: 0.12, blue: 0.08)]
        case .rare:
            return [Color(red: 0.08, green: 0.12, blue: 0.25), Color(red: 0.05, green: 0.08, blue: 0.18)]
        case .epic:
            return [Color(red: 0.18, green: 0.08, blue: 0.28), Color(red: 0.12, green: 0.05, blue: 0.2)]
        case .legendary:
            return [Color(red: 0.28, green: 0.2, blue: 0.05), Color(red: 0.18, green: 0.12, blue: 0.02)]
        }
    }
}
