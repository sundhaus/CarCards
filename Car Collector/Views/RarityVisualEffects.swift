//
//  RarityVisualEffects.swift
//  Car Collector
//
//  Animated visual effects that make rarity FEEL different.
//  - Common/Uncommon/Rare: Static borders (existing behavior)
//  - Epic: Auto-rotating shimmer border + subtle particle sparks
//  - Legendary: Gyro-driven specular rim light (Apple Card style),
//    Gaussian specular strip (holographic surface sweep),
//    particle effects, ambient glow pulse
//
//  PERFORMANCE NOTES:
//  - drawingGroup() rasterizes overlay stack into one Metal texture.
//  - Particle system uses TimelineView at ~30fps.
//  - Motion manager throttled to 30fps.
//  - No blur() calls anywhere.
//

import SwiftUI

// MARK: - Full-Bleed Edge Overlay (Epic+)

/// Static vignette + thin accent stroke. Zero per-frame cost.
struct FullBleedEdgeOverlay: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    var body: some View {
        ZStack {
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
            
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(rarity.gradient, lineWidth: 1.5)
                .padding(1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Rarity Effect Overlay

/// Main entry point. Full-size card displays only — never thumbnails.
/// Split into inner effects (clipped to card shape) and outer effects
/// (glow/shadow that bleeds past the card edge).
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
            // Inner effects — clipped to card shape, rasterized for performance
            innerEffects
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .drawingGroup()
            
            // Outer effects — glow/shadow that bleeds past the edge.
            // NOT in drawingGroup() so shadows aren't rasterized/clipped.
            outerEffects
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var innerEffects: some View {
        ZStack {
            if rarity.hasFullBleedArt {
                FullBleedEdgeOverlay(rarity: rarity, cornerRadius: cornerRadius)
            }
            
            // Specular strip (Epic + Legendary)
            if rarity >= .epic {
                GyroSpecularStrip(rarity: rarity, cornerRadius: cornerRadius)
            }
            
            // Particles (Epic + Legendary)
            if rarity >= .epic {
                ParticleSparkOverlay(
                    rarity: rarity,
                    cardSize: cardSize,
                    cornerRadius: cornerRadius
                )
            }
        }
    }
    
    @ViewBuilder
    private var outerEffects: some View {
        // Legendary: gyro rim light + glow pulse — these have shadows
        // that need to bleed past the card edge for the full effect
        if rarity == .legendary {
            GyroRimLight(rarity: rarity, cornerRadius: cornerRadius)
            GlowPulseOverlay(color: Color.yellow, cornerRadius: cornerRadius)
        }
        
        // Epic: shimmer border (stroke sits on edge, shadow bleeds)
        if rarity == .epic {
            AnimatedShimmerBorder(rarity: rarity, cornerRadius: cornerRadius)
        }
    }
}

// MARK: - Gyro-Driven Rim Light (Legendary)

/// Apple Card–style specular highlight that travels around the card border
/// based on device tilt. Maps combined roll+pitch to an angle around
/// the card perimeter, then renders a concentrated bright spot via
/// AngularGradient whose "hot zone" follows the tilt direction.
///
/// The effect: tilt the phone and a gold-white light slides along
/// the card edge like sunlight catching a metallic surface.
struct GyroRimLight: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    @ObservedObject private var motion = CardMotionManager.shared
    
    /// Convert device tilt into an angle (degrees) around the card perimeter.
    /// roll = left/right tilt, pitch = forward/back tilt.
    /// atan2 gives us a natural circular mapping.
    private var highlightAngle: Double {
        // Scale motion values for more responsive feel
        let r = motion.roll * 8.0
        let p = motion.pitch * 8.0
        // atan2 maps (pitch, roll) to angle in radians → convert to degrees
        let angle = atan2(p, r) * (180.0 / .pi)
        return angle
    }
    
    /// How focused the highlight is — larger spread = softer, more diffuse
    private let spreadDegrees: Double = 50
    
    /// Rim light colors: concentrated bright spot with soft falloff
    private var rimColors: [Gradient.Stop] {
        let baseAngle = highlightAngle / 360.0
        // Normalize to 0...1 range
        let center = baseAngle - floor(baseAngle)
        
        return [
            .init(color: Color.yellow.opacity(0), location: 0),
            .init(color: Color.yellow.opacity(0), location: max(0, center - 0.15)),
            .init(color: Color.orange.opacity(0.5), location: max(0, center - 0.06)),
            .init(color: Color.white.opacity(0.95), location: center),
            .init(color: Color.orange.opacity(0.5), location: min(1, center + 0.06)),
            .init(color: Color.yellow.opacity(0), location: min(1, center + 0.15)),
            .init(color: Color.yellow.opacity(0), location: 1)
        ]
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.clear,
                        Color.orange.opacity(0.4),
                        Color.yellow.opacity(0.7),
                        Color.white.opacity(0.95),
                        Color.yellow.opacity(0.7),
                        Color.orange.opacity(0.4),
                        Color.clear,
                        Color.clear,
                        Color.clear,
                        Color.clear,
                        Color.clear,
                    ]),
                    center: .center,
                    startAngle: .degrees(highlightAngle - 180),
                    endAngle: .degrees(highlightAngle + 180)
                ),
                lineWidth: 3.5
            )
            .shadow(
                color: Color.yellow.opacity(0.4),
                radius: 6
            )
            .onAppear { motion.startIfNeeded() }
            .onDisappear { motion.stopIfNeeded() }
    }
}

// MARK: - Gyro Specular Strip (Legendary)

/// A Gaussian-intensity light band oriented along the card's height.
/// Sweeps left/right across the card width driven by device pitch.
/// Purple tint for Epic, gold tint for Legendary.
struct GyroSpecularStrip: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    @ObservedObject private var motion = CardMotionManager.shared
    
    private let sigmaFraction: CGFloat = 0.15
    private let shineBoost: CGFloat = 0.25
    
    private var tintColor: Color {
        switch rarity {
        case .legendary:
            return Color(red: 1.0, green: 0.85, blue: 0.4)  // Gold
        case .epic:
            return Color(red: 0.7, green: 0.4, blue: 1.0)   // Purple
        default:
            return .white
        }
    }
    
    private var normalizedCenter: CGFloat {
        let pitchRange: CGFloat = 0.15
        let clamped = max(-pitchRange, min(pitchRange, motion.pitch))
        return 0.5 + (clamped / pitchRange) * 0.5
    }
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let sigma = w * sigmaFraction
            let center = normalizedCenter * w
            
            let step: CGFloat = 2.0
            var x: CGFloat = 0
            
            while x < w {
                let dist = x - center
                let gaussian = exp(-0.5 * (dist * dist) / (sigma * sigma))
                let intensity = shineBoost * gaussian
                
                guard intensity > 0.005 else { x += step; continue }
                
                let rect = CGRect(x: x, y: 0, width: step, height: h)
                context.opacity = intensity
                context.fill(Path(rect), with: .color(tintColor))
                
                x += step
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .blendMode(.screen)
        .allowsHitTesting(false)
        .onAppear { motion.startIfNeeded() }
        .onDisappear { motion.stopIfNeeded() }
    }
}

// MARK: - Animated Shimmer Border (Epic)

/// Auto-rotating angular gradient shimmer for Epic cards.
/// Legendary uses GyroRimLight instead.
struct AnimatedShimmerBorder: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    @State private var phase: CGFloat = 0
    
    private var shimmerColors: [Color] {
        [
            Color.purple.opacity(0),
            Color.pink.opacity(0.5),
            Color.white.opacity(0.75),
            Color.pink.opacity(0.5),
            Color.purple.opacity(0),
            Color.purple.opacity(0),
            Color.purple.opacity(0),
        ]
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
                lineWidth: 2.5
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 3.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 360
                }
            }
    }
}

// MARK: - Particle Spark Overlay

struct ParticleSparkOverlay: View {
    let rarity: CardRarity
    let cardSize: CGSize
    let cornerRadius: CGFloat
    
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
                    context.fill(Circle().path(in: rect), with: .color(color))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

final class ParticleEngine {
    struct Particle {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var opacity: Double = 0
        var scale: CGFloat = 1
        var isAccent: Bool = false
        var alive: Bool = false
    }
    
    var particles: [Particle] = Array(repeating: Particle(), count: 12)
    private var activeCount = 0
    private var lastTick: Date = .distantPast
    
    func tick(cardSize: CGSize, maxCount: Int, borderInset: CGFloat) {
        let now = Date()
        guard now.timeIntervalSince(lastTick) > 0.03 else { return }
        lastTick = now
        
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
        
        if activeCount < maxCount {
            if let slot = particles.firstIndex(where: { !$0.alive }) {
                particles[slot] = spawnBorderParticle(cardSize: cardSize, borderInset: borderInset)
            }
        }
    }
    
    private func spawnBorderParticle(cardSize: CGSize, borderInset: CGFloat) -> Particle {
        let edge = Int.random(in: 0...3)
        let x: CGFloat, y: CGFloat
        switch edge {
        case 0:
            x = .random(in: borderInset...(cardSize.width - borderInset))
            y = .random(in: 0...borderInset)
        case 1:
            x = .random(in: (cardSize.width - borderInset)...cardSize.width)
            y = .random(in: borderInset...(cardSize.height - borderInset))
        case 2:
            x = .random(in: borderInset...(cardSize.width - borderInset))
            y = .random(in: (cardSize.height - borderInset)...cardSize.height)
        default:
            x = .random(in: 0...borderInset)
            y = .random(in: borderInset...(cardSize.height - borderInset))
        }
        return Particle(x: x, y: y, opacity: .random(in: 0.5...0.9),
                        scale: .random(in: 0.7...1.3), isAccent: .random(), alive: true)
    }
}

// MARK: - Glow Pulse Overlay (Legendary)

struct GlowPulseOverlay: View {
    let color: Color
    let cornerRadius: CGFloat
    
    @State private var glowIntensity: CGFloat = 0.25
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(color.opacity(Double(glowIntensity)), lineWidth: 4)
            .shadow(color: color.opacity(Double(glowIntensity) * 0.6), radius: 10)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.6
                }
            }
    }
}

// MARK: - View Modifier

struct RarityEffectModifier: ViewModifier {
    let rarity: CardRarity?
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if let rarity = rarity, rarity >= .epic {
                    GeometryReader { geo in
                        RarityEffectOverlay(rarity: rarity, cardSize: geo.size)
                    }
                }
            }
    }
}

extension View {
    func rarityEffects(for rarity: CardRarity?) -> some View {
        modifier(RarityEffectModifier(rarity: rarity))
    }
}
