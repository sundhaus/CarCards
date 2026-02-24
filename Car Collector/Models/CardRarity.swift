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
    
    private var sortIndex: Int {
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
}
