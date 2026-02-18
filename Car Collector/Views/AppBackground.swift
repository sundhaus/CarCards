//
//  AppBackground.swift
//  CarCardCollector
//
//  Shared background with spline graphic and blur overlay
//  Provides the colorful underlayer that makes Liquid Glass containers refract light
//

import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Adaptive base: white in light mode, space gray in dark
            (colorScheme == .dark ? Color(white: 0.11) : Color.white)
                .ignoresSafeArea()
            
            // Spline graphic - right side, shifted above midline
            Image("SplineBackground")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 500)
                .offset(x: 80, y: -60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
            // Blur layer over everything
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }
}

// Convenience modifier to apply background to any view
extension View {
    func appBackground() -> some View {
        self.background {
            AppBackground()
        }
    }
}

#Preview {
    AppBackground()
}
