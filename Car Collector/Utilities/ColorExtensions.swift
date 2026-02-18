//
//  ColorExtensions.swift
//  CarCardCollector
//
//  Shared color palette
//

import SwiftUI

extension Color {
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
