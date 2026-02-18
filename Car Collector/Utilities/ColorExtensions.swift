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
        colors: [.white, .white],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Solid light background
    static let appBackgroundSolid = Color.white
    
    // Header background - light with subtle transparency
    static let headerBackground = Color(white: 0.92).opacity(0.85)
}
