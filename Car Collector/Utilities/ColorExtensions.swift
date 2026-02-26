//
//  ColorExtensions.swift
//  CarCardCollector
//
//  Shared color palette
//

import SwiftUI

extension Color {
    // MARK: - App Accent
    
    /// Primary red racing accent — used for active tab, badges, highlights
    static let appAccent = Color(red: 232/255, green: 25/255, blue: 44/255)
    
    /// Soft red for subtle backgrounds and glows
    static let appAccentSoft = Color(red: 232/255, green: 25/255, blue: 44/255).opacity(0.12)
    
    // MARK: - Backgrounds
    
    // Light background gradient (used where gradient is required)
    static let appBackground = LinearGradient(
        colors: [appBackgroundSolid, appBackgroundSolid],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Solid background - adaptive
    static let appBackgroundSolid = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.11, alpha: 1)
            : UIColor.white
    })
    
    // Header background - adaptive with transparency
    static let headerBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.15, alpha: 0.85)
            : UIColor(white: 0.96, alpha: 0.85)
    })
}
