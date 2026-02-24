//
//  CardBorderConfig.swift
//  CarCardCollector
//
//  Defines layout rules for each card border template
//

import SwiftUI

// MARK: - Border Configuration

struct CardBorderConfig {
    let borderImageName: String?
    let textPosition: TextPosition
    let textColor: Color
    let textShadow: Shadow
    let heatPosition: HeatPosition
    
    enum TextPosition {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
        case center
    }
    
    enum HeatPosition {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
        case hidden
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Border Templates

extension CardBorderConfig {
    
    // Default black border - simple overlay
    static let defaultBlack = CardBorderConfig(
        borderImageName: "Border_Def_Blk",
        textPosition: .topLeft,
        textColor: .black,
        textShadow: Shadow(
            color: .white.opacity(0.6),
            radius: 3,
            x: 0,
            y: 2
        ),
        heatPosition: .bottomRight
    )
    
    // Default white border - simple overlay
    static let defaultWhite = CardBorderConfig(
        borderImageName: "Border_Def_Wht",
        textPosition: .topLeft,
        textColor: .white,
        textShadow: Shadow(
            color: .black.opacity(0.8),
            radius: 3,
            x: 0,
            y: 2
        ),
        heatPosition: .bottomRight
    )
    
    // MARK: - Rarity Borders
    
    static let rarityCommon = CardBorderConfig(
        borderImageName: "Border_Common",
        textPosition: .topLeft,
        textColor: .white,
        textShadow: Shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2),
        heatPosition: .bottomRight
    )
    
    static let rarityUncommon = CardBorderConfig(
        borderImageName: "Border_Uncommon",
        textPosition: .topLeft,
        textColor: .white,
        textShadow: Shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2),
        heatPosition: .bottomRight
    )
    
    static let rarityRare = CardBorderConfig(
        borderImageName: "Border_Rare",
        textPosition: .topLeft,
        textColor: .white,
        textShadow: Shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2),
        heatPosition: .bottomRight
    )
    
    static let rarityEpic = CardBorderConfig(
        borderImageName: "Border_Epic",
        textPosition: .topLeft,
        textColor: .white,
        textShadow: Shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2),
        heatPosition: .bottomRight
    )
    
    static let rarityLegendary = CardBorderConfig(
        borderImageName: "Border_Legendary",
        textPosition: .topLeft,
        textColor: .white,
        textShadow: Shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2),
        heatPosition: .bottomRight
    )
    
    // Get config for a rarity tier
    static func forRarity(_ rarity: CardRarity) -> CardBorderConfig {
        switch rarity {
        case .common:    return .rarityCommon
        case .uncommon:  return .rarityUncommon
        case .rare:      return .rarityRare
        case .epic:      return .rarityEpic
        case .legendary: return .rarityLegendary
        }
    }
    
    // Get config based on customFrame value, with optional rarity fallback
    // If customFrame is nil and rarity is provided, use the rarity border
    static func forFrame(_ frameName: String?, rarity: CardRarity? = nil) -> CardBorderConfig {
        // Custom frame takes priority
        if let frameName = frameName {
            switch frameName {
            case "Border_Def_Blk", "Black":
                return .defaultBlack
            case "Border_Common":
                return .rarityCommon
            case "Border_Uncommon":
                return .rarityUncommon
            case "Border_Rare":
                return .rarityRare
            case "Border_Epic":
                return .rarityEpic
            case "Border_Legendary":
                return .rarityLegendary
            default:
                return .defaultWhite
            }
        }
        
        // No custom frame — fall back to rarity border if available
        if let rarity = rarity {
            return forRarity(rarity)
        }
        
        // Default fallback
        return .defaultWhite
    }
}
