//
//  RarityVisualEffects.swift
//  Car Collector
//
//  Animated visual effects that make rarity FEEL different.
//  - Common/Uncommon/Rare: Static borders (existing behavior)
//  - Epic: Animated shimmer border + subtle particle sparks
//  - Legendary: Full holographic surface (gyro-driven prismatic),
//    animated gold shimmer border, particle effects, glow pulse
//
//  These are SwiftUI overlays applied ON TOP of the card view,
//  separate from the baked CardRenderer border (which remains for thumbnails/exports).
//

import SwiftUI

// MARK: - Full-Bleed Edge Overlay (Epic+)

/// Live SwiftUI vignette + accent edge for Epic+ cards shown in interactive views.
/// Complements the baked `CardRenderer.drawFullBleedOverlay` for static images.
struct FullBleedEdgeOverlay: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    var body: some View {
        ZStack {
            // Radial vignette (dark edges)
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.15), location: 0.85),
                    .init(color: .black.opacity(0.45), location: 1.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            
            // Thin rarity accent stroke
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    rarity.gradient,
                    lineWidth: 1.5
                )
                .padding(1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Rarity Effect Overlay

/// Main entry point — wraps any card view with rarity-appropriate live effects.
/// Use this on full-size card displays (detail view, garage fullscreen, reveal).
/// Thumbnails/grid views should NOT use this (too expensive).
struct RarityEffectOverlay: View {
    let rarity: CardRarity
    let cardSize: CGSize
    let cornerRadius: CGFloat
    
    init(rarity: CardRarity, cardSize: CGSize, cornerRadius: CGFloat = 0) {
        self.rarity = rarity
        self.cardSize = cardSize
        self.cornerRadius = cornerRadius > 0 ? cornerRadius : cardSize.height * 0.09
    }
    
    var body: some View {
        ZStack {
            // Full-bleed vignette edge (Epic+ only)
            if rarity.hasFullBleedArt {
                FullBleedEdgeOverlay(
                    rarity: rarity,
                    cornerRadius: cornerRadius
                )
            }
            
            // Holographic prismatic surface (Legendary only)
            if rarity == .legendary {
                HolographicOverlay(cornerRadius: cornerRadius)
            }
            
            // Animated shimmer border (Epic + Legendary)
            if rarity >= .epic {
                AnimatedShimmerBorder(
                    rarity: rarity,
                    cornerRadius: cornerRadius
                )
            }
            
            // Particle sparks (Epic + Legendary)
            if rarity >= .epic {
                ParticleSparkOverlay(
                    rarity: rarity,
                    cardSize: cardSize,
                    cornerRadius: cornerRadius
                )
            }
            
            // Ambient glow pulse (Legendary only)
            if rarity == .legendary {
                GlowPulseOverlay(
                    color: Color.yellow,
                    cornerRadius: cornerRadius
                )
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Animated Shimmer Border

/// A traveling light streak that moves around the card border continuously.
/// Epic = purple/pink shimmer, Legendary = gold/white shimmer
struct AnimatedShimmerBorder: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    @State private var phase: CGFloat = 0
    
    private var shimmerColors: [Color] {
        switch rarity {
        case .epic:
            return [
                Color.purple.opacity(0),
                Color.purple.opacity(0.4),
                Color.pink.opacity(0.8),
                Color.white.opacity(0.9),
                Color.pink.opacity(0.8),
                Color.purple.opacity(0.4),
                Color.purple.opacity(0)
            ]
        case .legendary:
            return [
                Color.yellow.opacity(0),
                Color.yellow.opacity(0.5),
                Color.orange.opacity(0.8),
                Color.white.opacity(1.0),
                Color.orange.opacity(0.8),
                Color.yellow.opacity(0.5),
                Color.yellow.opacity(0)
            ]
        default:
            return [Color.clear]
        }
    }
    
    private var animationDuration: Double {
        rarity == .legendary ? 2.5 : 3.5
    }
    
    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: shimmerColors),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: rarity == .legendary ? 3.5 : 2.5
                )
                .blur(radius: 1)
                .overlay(
                    // Sharp inner edge for definition
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: shimmerColors),
                                center: .center,
                                startAngle: .degrees(phase),
                                endAngle: .degrees(phase + 360)
                            ),
                            lineWidth: 1.5
                        )
                )
        }
        .onAppear {
            withAnimation(
                .linear(duration: animationDuration)
                .repeatForever(autoreverses: false)
            ) {
                phase = 360
            }
        }
    }
}

// MARK: - Holographic / Prismatic Surface Overlay

/// Gyroscope-driven rainbow refraction effect for Legendary cards.
/// Uses the existing CardMotionManager to read device attitude,
/// then maps tilt to a shifting linear gradient that mimics
/// a holographic foil surface.
struct HolographicOverlay: View {
    let cornerRadius: CGFloat
    
    @ObservedObject private var motion = CardMotionManager.shared
    @State private var idlePhase: CGFloat = 0
    
    /// Map device pitch/roll to gradient start/end for prismatic shift
    private var gradientStart: UnitPoint {
        let x = 0.5 + motion.roll * 3.0
        let y = 0.5 + motion.pitch * 3.0
        return UnitPoint(x: x, y: y)
    }
    
    private var gradientEnd: UnitPoint {
        let x = 0.5 - motion.roll * 3.0
        let y = 0.5 - motion.pitch * 3.0
        return UnitPoint(x: x, y: y)
    }
    
    private let holoColors: [Color] = [
        Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.15),   // Red
        Color(red: 1.0, green: 0.6, blue: 0.1).opacity(0.12),   // Orange
        Color(red: 1.0, green: 1.0, blue: 0.2).opacity(0.15),   // Yellow
        Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.12),   // Green
        Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.15),   // Blue
        Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.12),   // Violet
        Color(red: 1.0, green: 0.3, blue: 0.8).opacity(0.15),   // Pink
        Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.15),   // Red (wrap)
    ]
    
    var body: some View {
        ZStack {
            // Primary prismatic gradient
            LinearGradient(
                gradient: Gradient(colors: holoColors),
                startPoint: gradientStart,
                endPoint: gradientEnd
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .blendMode(.overlay)
            
            // Secondary sparkle layer — subtle diagonal streaks
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.08 + motion.roll * 0.15),
                    Color.white.opacity(0),
                    Color.white.opacity(0.06 + motion.pitch * 0.12),
                    Color.white.opacity(0)
                ]),
                startPoint: UnitPoint(x: 0.0 + idlePhase * 0.01, y: 0),
                endPoint: UnitPoint(x: 1.0 + idlePhase * 0.01, y: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .blendMode(.screen)
        }
        .onAppear {
            motion.startIfNeeded()
            // Subtle idle animation for when device is stationary
            withAnimation(
                .easeInOut(duration: 4)
                .repeatForever(autoreverses: true)
            ) {
                idlePhase = 10
            }
        }
        .onDisappear {
            motion.stopIfNeeded()
        }
    }
}

// MARK: - Particle Spark Overlay

/// Small glowing particles that drift along the card border.
/// Epic = purple sparks, Legendary = gold sparks (more particles, brighter)
struct ParticleSparkOverlay: View {
    let rarity: CardRarity
    let cardSize: CGSize
    let cornerRadius: CGFloat
    
    @State private var particles: [Particle] = []
    @State private var timer: Timer?
    
    private var particleCount: Int {
        rarity == .legendary ? 12 : 6
    }
    
    private var particleColor: Color {
        rarity == .legendary ? .yellow : .purple
    }
    
    private var particleAccent: Color {
        rarity == .legendary ? .white : .pink
    }
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var opacity: Double
        var scale: CGFloat
        var isAccent: Bool
    }
    
    var body: some View {
        Canvas { context, size in
            for particle in particles {
                let color = particle.isAccent ? particleAccent : particleColor
                let rect = CGRect(
                    x: particle.x - 2 * particle.scale,
                    y: particle.y - 2 * particle.scale,
                    width: 4 * particle.scale,
                    height: 4 * particle.scale
                )
                
                context.opacity = particle.opacity
                context.fill(
                    Circle().path(in: rect),
                    with: .color(color)
                )
                
                // Glow
                let glowRect = rect.insetBy(dx: -3 * particle.scale, dy: -3 * particle.scale)
                context.opacity = particle.opacity * 0.3
                context.fill(
                    Circle().path(in: glowRect),
                    with: .color(color)
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            spawnInitialParticles()
            startParticleTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func spawnInitialParticles() {
        particles = (0..<particleCount).map { _ in
            spawnBorderParticle()
        }
    }
    
    private func startParticleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            // Fade existing
            particles = particles.compactMap { p in
                var updated = p
                updated.opacity -= 0.02
                // Gentle drift upward
                updated.y -= 0.3
                updated.x += CGFloat.random(in: -0.5...0.5)
                return updated.opacity > 0 ? updated : nil
            }
            
            // Spawn new if under count
            if particles.count < particleCount {
                withAnimation(.easeIn(duration: 0.3)) {
                    particles.append(spawnBorderParticle())
                }
            }
        }
    }
    
    private func spawnBorderParticle() -> Particle {
        // Spawn along the border perimeter
        let edge = Int.random(in: 0...3)
        let x: CGFloat
        let y: CGFloat
        let borderInset: CGFloat = cardSize.height * 0.042
        
        switch edge {
        case 0: // Top
            x = CGFloat.random(in: borderInset...(cardSize.width - borderInset))
            y = CGFloat.random(in: 0...borderInset)
        case 1: // Right
            x = CGFloat.random(in: (cardSize.width - borderInset)...cardSize.width)
            y = CGFloat.random(in: borderInset...(cardSize.height - borderInset))
        case 2: // Bottom
            x = CGFloat.random(in: borderInset...(cardSize.width - borderInset))
            y = CGFloat.random(in: (cardSize.height - borderInset)...cardSize.height)
        default: // Left
            x = CGFloat.random(in: 0...borderInset)
            y = CGFloat.random(in: borderInset...(cardSize.height - borderInset))
        }
        
        return Particle(
            x: x,
            y: y,
            opacity: Double.random(in: 0.4...0.9),
            scale: CGFloat.random(in: 0.6...1.4),
            isAccent: Bool.random()
        )
    }
}

// MARK: - Glow Pulse Overlay

/// Soft pulsing glow around the entire card (Legendary only)
struct GlowPulseOverlay: View {
    let color: Color
    let cornerRadius: CGFloat
    
    @State private var glowIntensity: CGFloat = 0.3
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(color.opacity(Double(glowIntensity)), lineWidth: 6)
            .blur(radius: 12)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    glowIntensity = 0.7
                }
            }
    }
}

// MARK: - View Modifier for Easy Application

struct RarityEffectModifier: ViewModifier {
    let rarity: CardRarity?
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if let rarity = rarity, rarity >= .epic {
                    GeometryReader { geo in
                        RarityEffectOverlay(
                            rarity: rarity,
                            cardSize: geo.size
                        )
                    }
                }
            }
    }
}

extension View {
    /// Adds animated rarity effects (shimmer, holographic, particles) for Epic+ cards.
    /// Only use on full-size card views, not thumbnails.
    func rarityEffects(for rarity: CardRarity?) -> some View {
        modifier(RarityEffectModifier(rarity: rarity))
    }
}
