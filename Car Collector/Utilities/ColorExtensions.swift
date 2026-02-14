//
//  ColorExtensions.swift
//  CarCardCollector
//
//  Shared color palette
//

import SwiftUI

extension Color {
    // Marketplace dark blue background
    static let appBackground = LinearGradient(
        colors: [
            Color(red: 0.1, green: 0.1, blue: 0.2),
            Color(red: 0.05, green: 0.05, blue: 0.15)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Solid version for non-gradient contexts
    static let appBackgroundSolid = Color(red: 0.075, green: 0.075, blue: 0.175)
    
    // Header and hub background - dark blue-gray with transparency
    // Matches the appearance of ultraThinMaterial on appBackgroundSolid
    static let headerBackground = Color(red: 0.15, green: 0.16, blue: 0.22).opacity(0.85)
}
