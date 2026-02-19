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
    var showFloatingShapes: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Adaptive base: white in light mode, space gray in dark
                (colorScheme == .dark ? Color(white: 0.11) : Color.white)
                
                // Spline graphic - right side, shifted above midline
                Image("SplineBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width * 1.2)
                    .offset(x: geo.size.width * 0.2, y: -60)
                
                // Floating shapes layer (home page only)
                if showFloatingShapes {
                    FloatingShapesView(size: geo.size)
                }
                
                // Blur layer over everything
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Floating Shapes

struct FloatingShapeItem: View {
    let imageName: String
    let size: CGFloat
    let startX: CGFloat
    let startY: CGFloat
    let driftX: CGFloat
    let driftY: CGFloat
    let duration: Double
    let rotationAmount: Double
    let opacity: Double
    
    @State private var animating = false
    
    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .opacity(opacity)
            .rotationEffect(.degrees(animating ? rotationAmount : 0))
            .offset(
                x: startX + (animating ? driftX : 0),
                y: startY + (animating ? driftY : 0)
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    animating = true
                }
            }
    }
}

struct FloatingShapesView: View {
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Circle - top left area, drifts down-right
            FloatingShapeItem(
                imageName: "FloatingCircle",
                size: 90,
                startX: -size.width * 0.25,
                startY: -size.height * 0.2,
                driftX: 40,
                driftY: 30,
                duration: 6.0,
                rotationAmount: 0,
                opacity: 0.6
            )
            
            // Hexagon - right area, drifts up-left
            FloatingShapeItem(
                imageName: "FloatingHexagon",
                size: 120,
                startX: size.width * 0.2,
                startY: size.height * 0.05,
                driftX: -35,
                driftY: -45,
                duration: 7.5,
                rotationAmount: 25,
                opacity: 0.5
            )
            
            // Triangle - bottom left, drifts up-right
            FloatingShapeItem(
                imageName: "FloatingTriangle",
                size: 140,
                startX: -size.width * 0.1,
                startY: size.height * 0.25,
                driftX: 50,
                driftY: -35,
                duration: 8.0,
                rotationAmount: -15,
                opacity: 0.5
            )
            
            // Second circle - bottom right, smaller, drifts left
            FloatingShapeItem(
                imageName: "FloatingCircle",
                size: 55,
                startX: size.width * 0.3,
                startY: size.height * 0.3,
                driftX: -30,
                driftY: -20,
                duration: 5.5,
                rotationAmount: 0,
                opacity: 0.4
            )
            
            // Second hexagon - top right, smaller
            FloatingShapeItem(
                imageName: "FloatingHexagon",
                size: 70,
                startX: size.width * 0.15,
                startY: -size.height * 0.3,
                driftX: -25,
                driftY: 40,
                duration: 9.0,
                rotationAmount: -20,
                opacity: 0.35
            )
        }
    }
}

// Convenience modifier to apply background to any view
extension View {
    func appBackground(showFloatingShapes: Bool = false) -> some View {
        self.background {
            AppBackground(showFloatingShapes: showFloatingShapes)
        }
    }
}

#Preview {
    AppBackground()
}
