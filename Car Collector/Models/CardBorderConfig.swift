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
        textColor: .white,
        textShadow: Shadow(
            color: .black.opacity(0.8),
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
        textColor: .black,
        textShadow: Shadow(
            color: .white.opacity(0.8),
            radius: 3,
            x: 0,
            y: 2
        ),
        heatPosition: .bottomRight
    )
    
    // No border - just card with text
    static let none = CardBorderConfig(
        borderImageName: nil,
        textPosition: .topRight,
        textColor: .white,
        textShadow: Shadow(
            color: .black.opacity(0.8),
            radius: 3,
            x: 0,
            y: 2
        ),
        heatPosition: .bottomRight
    )
    
    // Get config based on customFrame value
    static func forFrame(_ frameName: String?) -> CardBorderConfig {
        switch frameName {
        case "Border_Def_Blk", "Black":
            return .defaultBlack
        case "Border_Def_Wht", "White":
            return .defaultWhite
        case "None", nil:
            return .none
        default:
            return .defaultBlack // Default fallback
        }
    }
}
