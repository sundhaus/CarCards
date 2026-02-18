//
//  ColorExtensions.swift
//  CarCardCollector
//
//  Shared color palette
//

import SwiftUI

extension Color {
    // Light background gradient
    static let appBackground = LinearGradient(
        colors: [
            Color(white: 0.96),
            Color(white: 0.93)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Solid light background
    static let appBackgroundSolid = Color(white: 0.95)
    
    // Header background - light with subtle transparency
    static let headerBackground = Color(white: 0.92).opacity(0.85)
}
