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
//  PERFORMANCE NOTES:
//  - All animated overlays use drawingGroup() to rasterize into a single
//    Metal-backed texture, avoiding per-frame compositing of blend modes.
//  - Particle system uses TimelineView at ~30fps instead of Timer + @State.
//  - Motion-driven effects throttle updates to 30fps.
//  - Blur effects avoided entirely; use shadow or opacity instead.
//  - Only apply to full-size card views (detail, garage fullscreen, reveal).
//    NEVER on thumbnails or grid cells.
//

import SwiftUI

// MARK: - Full-Bleed Edge Overlay (Epic+)

/// Live SwiftUI vignette + accent edge for Epic+ cards shown in interactive views.
/// Complements the baked `CardRenderer.drawFullBleedOverlay` for static images.
/// This is purely static — zero per-frame cost.
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
            // Full-bleed vignette edge (Epic+ only) — static, cheap
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
        // Rasterize the entire overlay stack into one Metal texture.
        // This is the single biggest perf win — prevents per-frame
        // compositing of blend modes across multiple layers.
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Animated Shimmer Border

/// A traveling light streak that moves around the card border continuously.
/// Epic = purple/pink shimmer, Legendary = gold/white shimmer.
///
/// PERF: Single AngularGradient stroke, no blur, no duplicate overlay.
/// The animation is a simple rotation of the gradient angle — GPU-friendly.
struct AnimatedShimmerBorder: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    @State private var phase: CGFloat = 0
    
    private var shimmerColors: [Color] {
        switch rarity {
        case .epic:
            return [
                Color.purple.opacity(0),
                Color.pink.opacity(0.6),
                Color.white.opacity(0.8),
                Color.pink.opacity(0.6),
                Color.purple.opacity(0)
            ]
        case .legendary:
            return [
                Color.yellow.opacity(0),
                Color.orange.opacity(0.7),
                Color.white.opacity(0.9),
                Color.orange.opacity(0.7),
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
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: shimmerColors),
                    center: .center,
                    startAngle: .degrees(phase),
                    endAngle: .degrees(phase + 360)
                ),
                lineWidth: rarity == .legendary ? 3.0 : 2.0
            )
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
/// Uses CardMotionManager (throttled to 30fps) to shift a single
/// linear gradient that mimics holographic foil.
///
/// PERF: Single LinearGradient + overlay blend. No secondary layer.
/// Motion-driven redraws throttled by the manager itself.
struct HolographicOverlay: View {
    let cornerRadius: CGFloat
    
    @ObservedObject private var motion = CardMotionManager.shared
    
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
        Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.18),   // Red
        Color(red: 1.0, green: 1.0, blue: 0.2).opacity(0.15),   // Yellow
        Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.15),   // Green
        Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.18),   // Blue
        Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.15),   // Violet
        Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.18),   // Red (wrap)
    ]
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: holoColors),
            startPoint: gradientStart,
            endPoint: gradientEnd
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .blendMode(.overlay)
        .onAppear {
            motion.startIfNeeded()
        }
        .onDisappear {
            motion.stopIfNeeded()
        }
    }
}

// MARK: - Particle Spark Overlay

/// Small glowing particles that drift along the card border.
/// Epic = purple sparks, Legendary = gold sparks.
///
/// PERF: Uses TimelineView capped at ~30fps instead of Timer + @State.
/// Particle state is mutated in-place (no new array allocations).
/// No per-particle glow (was doubling draw calls). Single Canvas pass.
struct ParticleSparkOverlay: View {
    let rarity: CardRarity
    let cardSize: CGSize
    let cornerRadius: CGFloat
    
    // Use a class to avoid @State copy-on-write overhead on every frame
    @State private var engine = ParticleEngine()
    
    private var particleCount: Int {
        rarity == .legendary ? 8 : 4
    }
    
    private var particleColor: Color {
        rarity == .legendary ? .yellow : .purple
    }
    
    private var particleAccent: Color {
        rarity == .legendary ? .white : .pink
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                engine.tick(
                    cardSize: cardSize,
                    maxCount: particleCount,
                    borderInset: cardSize.height * 0.042
                )
                
                for i in 0..<engine.particles.count {
                    let particle = engine.particles[i]
                    guard particle.alive else { continue }
                    
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
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Mutable particle engine — avoids @State array diffing overhead.
/// Particles are stored in a fixed-size pre-allocated array.
final class ParticleEngine {
    struct Particle {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var opacity: Double = 0
        var scale: CGFloat = 1
        var isAccent: Bool = false
        var alive: Bool = false
    }
    
    // Pre-allocate max possible particles
    var particles: [Particle] = Array(repeating: Particle(), count: 12)
    private var activeCount = 0
    private var lastTick: Date = .distantPast
    
    func tick(cardSize: CGSize, maxCount: Int, borderInset: CGFloat) {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        guard dt > 0.03 else { return } // Cap at ~30fps
        lastTick = now
        
        // Update existing
        activeCount = 0
        for i in 0..<particles.count {
            guard particles[i].alive else { continue }
            particles[i].opacity -= 0.025
            particles[i].y -= 0.4
            particles[i].x += CGFloat.random(in: -0.3...0.3)
            
            if particles[i].opacity <= 0 {
                particles[i].alive = false
            } else {
                activeCount += 1
            }
        }
        
        // Spawn new if under count
        if activeCount < maxCount {
            if let slot = particles.firstIndex(where: { !$0.alive }) {
                particles[slot] = spawnBorderParticle(cardSize: cardSize, borderInset: borderInset)
            }
        }
    }
    
    private func spawnBorderParticle(cardSize: CGSize, borderInset: CGFloat) -> Particle {
        let edge = Int.random(in: 0...3)
        let x: CGFloat
        let y: CGFloat
        
        switch edge {
        case 0:
            x = CGFloat.random(in: borderInset...(cardSize.width - borderInset))
            y = CGFloat.random(in: 0...borderInset)
        case 1:
            x = CGFloat.random(in: (cardSize.width - borderInset)...cardSize.width)
            y = CGFloat.random(in: borderInset...(cardSize.height - borderInset))
        case 2:
            x = CGFloat.random(in: borderInset...(cardSize.width - borderInset))
            y = CGFloat.random(in: (cardSize.height - borderInset)...cardSize.height)
        default:
            x = CGFloat.random(in: 0...borderInset)
            y = CGFloat.random(in: borderInset...(cardSize.height - borderInset))
        }
        
        return Particle(
            x: x,
            y: y,
            opacity: Double.random(in: 0.5...0.9),
            scale: CGFloat.random(in: 0.7...1.3),
            isAccent: Bool.random(),
            alive: true
        )
    }
}

// MARK: - Glow Pulse Overlay

/// Soft pulsing glow around the entire card (Legendary only).
///
/// PERF: Uses shadow on a stroked path instead of blur(radius:12) which
/// was triggering a full offscreen render pass every frame. Shadow is
/// GPU-composited and much cheaper. The animation only changes opacity.
struct GlowPulseOverlay: View {
    let color: Color
    let cornerRadius: CGFloat
    
    @State private var glowIntensity: CGFloat = 0.25
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(color.opacity(Double(glowIntensity)), lineWidth: 4)
            .shadow(color: color.opacity(Double(glowIntensity) * 0.6), radius: 10)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    glowIntensity = 0.6
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
