//
//  LiquidGlassShimmer.swift
//  Car Collector
//
//  Dynamic liquid glass border effect for legendary cards.
//  Uses CoreMotion gyroscope data to create a shimmering,
//  iridescent edge glow that responds to phone tilt.
//

import SwiftUI

// MARK: - Liquid Glass Shimmer Overlay

/// A gyroscope-driven shimmering border that sits on top of a card.
/// Only applied to legendary-rarity cards.
struct LiquidGlassShimmer: View {
    @ObservedObject private var motion = CardMotionManager.shared
    
    /// Corner radius to match the card's clip shape
    let cornerRadius: CGFloat
    
    /// Thickness of the shimmer border
    let borderWidth: CGFloat
    
    /// Overall intensity multiplier
    let intensity: Double
    
    /// Continuous animation timer for the idle shimmer
    @State private var phase: CGFloat = 0
    
    init(cornerRadius: CGFloat = 18, borderWidth: CGFloat = 3.5, intensity: Double = 1.0) {
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.intensity = intensity
    }
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            // Gyro-driven angle: maps phone tilt to gradient rotation
            let gyroAngle = Angle.degrees(
                (motion.roll * 180 + motion.pitch * 180) * intensity
            )
            
            // Phase-shifted secondary angle for the iridescent sweep
            let sweepAngle = Angle.degrees(
                Double(phase) * 360 + motion.roll * 120
            )
            
            ZStack {
                // Layer 1: Primary iridescent border stroke
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9),   // Gold
                                Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.7),    // Amber
                                Color(red: 1.0, green: 0.4, blue: 0.6).opacity(0.6),    // Rose
                                Color(red: 0.7, green: 0.3, blue: 1.0).opacity(0.5),    // Violet
                                Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.6),    // Cyan
                                Color(red: 0.4, green: 1.0, blue: 0.6).opacity(0.5),    // Mint
                                Color(red: 1.0, green: 0.9, blue: 0.3).opacity(0.7),    // Yellow
                                Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9),   // Gold (wrap)
                            ]),
                            center: .center,
                            angle: gyroAngle
                        ),
                        lineWidth: borderWidth
                    )
                
                // Layer 2: Bright specular highlight that sweeps with tilt
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.3),
                                .init(color: .white.opacity(0.8), location: 0.45),
                                .init(color: .white.opacity(0.95), location: 0.5),
                                .init(color: .white.opacity(0.8), location: 0.55),
                                .init(color: .clear, location: 0.7),
                                .init(color: .clear, location: 1.0),
                            ]),
                            center: .center,
                            angle: sweepAngle
                        ),
                        lineWidth: borderWidth * 0.6
                    )
                    .blendMode(.overlay)
                
                // Layer 3: Soft outer glow that breathes
                RoundedRectangle(cornerRadius: cornerRadius + 2)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.yellow.opacity(0.3),
                                Color.orange.opacity(0.15),
                                Color.pink.opacity(0.1),
                                Color.purple.opacity(0.15),
                                Color.cyan.opacity(0.1),
                                Color.yellow.opacity(0.3),
                            ]),
                            center: .center,
                            angle: gyroAngle + Angle.degrees(90)
                        ),
                        lineWidth: borderWidth * 1.5
                    )
                    .blur(radius: 4)
                    .opacity(0.5 + 0.3 * sin(phase * .pi * 2))
                
                // Layer 4: Inner light refraction edge
                RoundedRectangle(cornerRadius: cornerRadius - 1)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.0),
                                .white.opacity(0.3 * (0.5 + 0.5 * sin(phase * .pi * 2 + 1.5))),
                                .white.opacity(0.0),
                            ],
                            startPoint: UnitPoint(
                                x: 0.5 + CGFloat(motion.roll) * 2,
                                y: 0.0
                            ),
                            endPoint: UnitPoint(
                                x: 0.5 - CGFloat(motion.roll) * 2,
                                y: 1.0
                            )
                        ),
                        lineWidth: 1.0
                    )
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .onAppear {
            motion.startIfNeeded()
            // Continuous idle animation — slow rotation for ambient shimmer
            withAnimation(
                .linear(duration: 4.0)
                .repeatForever(autoreverses: false)
            ) {
                phase = 1.0
            }
        }
        .onDisappear {
            motion.stopIfNeeded()
        }
    }
}

// MARK: - View Modifier

struct LiquidGlassModifier: ViewModifier {
    let rarity: CardRarity?
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if rarity == .legendary {
                    LiquidGlassShimmer(
                        cornerRadius: cornerRadius,
                        borderWidth: borderWidth
                    )
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Adds a dynamic liquid glass shimmer border if the card is legendary rarity.
    /// - Parameters:
    ///   - rarity: The card's rarity tier. Effect only activates for `.legendary`.
    ///   - cornerRadius: Corner radius to match the card shape (default 18).
    ///   - borderWidth: Shimmer border thickness (default 3.5).
    func liquidGlassShimmer(
        rarity: CardRarity?,
        cornerRadius: CGFloat = 18,
        borderWidth: CGFloat = 3.5
    ) -> some View {
        modifier(LiquidGlassModifier(
            rarity: rarity,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth
        ))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        RoundedRectangle(cornerRadius: 18)
            .fill(
                LinearGradient(
                    colors: [.gray.opacity(0.3), .gray.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 320, height: 180)
            .overlay {
                Text("LEGENDARY")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .overlay {
                LiquidGlassShimmer(cornerRadius: 18)
            }
    }
}
