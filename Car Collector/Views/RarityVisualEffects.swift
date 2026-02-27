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
        
        // Rare: static blue glow border
        if rarity == .rare {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                .shadow(color: Color.cyan.opacity(0.4), radius: 8)
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
    
    // Smooth-wrapping gradient: the highlight fades out fully before
    // reaching the end, so there's no visible seam at 0°/360°.
    private var shimmerColors: [Color] {
        [
            Color.clear,
            Color.clear,
            Color.purple.opacity(0.15),
            Color.pink.opacity(0.5),
            Color.white.opacity(0.75),
            Color.pink.opacity(0.5),
            Color.purple.opacity(0.15),
            Color.clear,
            Color.clear,
            Color.clear,
            Color.clear,
            Color.clear,
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
                if let rarity = rarity, rarity >= .rare {
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
    
    /// One-shot shimmer sweep for Epic+ thumbnails. Plays once on appear.
    func thumbnailShimmer(for rarity: CardRarity?) -> some View {
        modifier(ThumbnailShimmerModifier(rarity: rarity))
    }
}

// MARK: - Thumbnail Shimmer (One-Shot)

/// A single diagonal light sweep that plays once when the view appears.
/// Lightweight enough for scroll views and grids. Color-coded by rarity:
/// purple for Epic, gold for Legendary.
struct ThumbnailShimmerModifier: ViewModifier {
    let rarity: CardRarity?
    
    @State private var shimmerOffset: CGFloat = -1.5
    
    func body(content: Content) -> some View {
        if let rarity = rarity, rarity >= .epic {
            content
                .overlay {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let shimmerWidth = w * 0.4
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        shimmerColor(for: rarity).opacity(0.15),
                                        Color.white.opacity(0.25),
                                        shimmerColor(for: rarity).opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: shimmerWidth)
                            .offset(x: shimmerOffset * w)
                            .blendMode(.screen)
                    }
                    .clipped()
                }
                .onAppear {
                    // Reset to start position instantly
                    shimmerOffset = -1.5
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeInOut(duration: 1.2)) {
                            shimmerOffset = 1.5
                        }
                    }
                }
        } else {
            content
        }
    }
    
    private func shimmerColor(for rarity: CardRarity) -> Color {
        switch rarity {
        case .legendary: return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .epic: return Color(red: 0.7, green: 0.4, blue: 1.0)
        default: return .white
        }
    }
}

// MARK: - Holographic Pattern Overlay (Legendary)

/// Geometric pattern overlay that refracts like a holographic foil when
/// the specular light sweeps across it. The pattern is a mostly-transparent
/// geometric tile; where the gyro-driven (or auto-animated) light band
/// intersects pattern pixels, they bloom into prismatic rainbow color.
///
/// Two modes:
/// - Full-size cards: gyro-driven via CardMotionManager
/// - Thumbnails: auto-animated sweep (lightweight for scroll views)
struct HolographicPatternOverlay: View {
    let cornerRadius: CGFloat
    var patternAsset: String = "HoloPattern"  // Asset name for the pattern
    var useGyro: Bool = true  // false = auto-animate for thumbnails
    
    @ObservedObject private var motion = CardMotionManager.shared
    @State private var autoPhase: CGFloat = 0
    
    /// Normalized 0...1 position of the specular highlight across the card width
    private var specularCenter: CGFloat {
        if useGyro {
            let pitchRange: CGFloat = 0.15
            let clamped = max(-pitchRange, min(pitchRange, motion.pitch))
            return 0.5 + (clamped / pitchRange) * 0.5
        } else {
            return autoPhase
        }
    }
    
    /// Rainbow gradient colors for the holographic refraction
    private let rainbowColors: [Color] = [
        Color(red: 1.0, green: 0.3, blue: 0.3),  // Red
        Color(red: 1.0, green: 0.6, blue: 0.2),  // Orange
        Color(red: 1.0, green: 1.0, blue: 0.3),  // Yellow
        Color(red: 0.3, green: 1.0, blue: 0.3),  // Green
        Color(red: 0.3, green: 0.8, blue: 1.0),  // Cyan
        Color(red: 0.4, green: 0.4, blue: 1.0),  // Blue
        Color(red: 0.7, green: 0.3, blue: 1.0),  // Violet
        Color(red: 1.0, green: 0.3, blue: 0.8),  // Magenta
        Color(red: 1.0, green: 0.3, blue: 0.3),  // Red (wrap)
    ]
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Layer 1: Static base pattern (subtle white texture always visible)
                Image(patternAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: w, height: h)
                    .clipped()
                    .blendMode(.screen)
                
                // Layer 2: Rainbow gradient masked to pattern — the holographic refraction
                // The gradient shifts position based on specular center, creating
                // the effect of light refracting through the foil pattern
                rainbowLayer(width: w, height: h)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
        .onAppear {
            if useGyro {
                motion.startIfNeeded()
            } else {
                // Auto-animate: sweep back and forth
                withAnimation(
                    .easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: true)
                ) {
                    autoPhase = 1.0
                }
            }
        }
        .onDisappear {
            if useGyro {
                motion.stopIfNeeded()
            }
        }
    }
    
    @ViewBuilder
    private func rainbowLayer(width w: CGFloat, height h: CGFloat) -> some View {
        // The rainbow gradient is offset based on specular position
        // so different parts of the pattern catch different hues
        let gradientOffset = (specularCenter - 0.5) * w * 0.6
        
        // Gaussian falloff: rainbow is strongest near the specular center,
        // fading to transparent away from it
        let sigma = w * 0.25
        
        Canvas { context, size in
            // Draw rainbow bands that fade based on distance from specular center
            let center = specularCenter * w
            let bandCount = rainbowColors.count - 1
            let totalRainbowWidth = w * 1.2  // Rainbow spans wider than card
            let bandWidth = totalRainbowWidth / CGFloat(bandCount)
            
            for i in 0..<bandCount {
                let bandX = gradientOffset + CGFloat(i) * bandWidth - w * 0.1
                let bandCenterX = bandX + bandWidth * 0.5
                
                // Gaussian intensity based on distance from specular highlight
                let dist = bandCenterX - center
                let gaussian = exp(-0.5 * (dist * dist) / (sigma * sigma))
                let intensity = gaussian * 0.35  // Peak opacity for rainbow
                
                guard intensity > 0.01 else { continue }
                
                let rect = CGRect(x: bandX, y: 0, width: bandWidth + 1, height: h)
                context.opacity = intensity
                context.fill(Path(rect), with: .color(rainbowColors[i]))
            }
        }
        .frame(width: w, height: h)
        // Mask to the pattern shape: only pattern pixels get the rainbow
        .mask {
            Image(patternAsset)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: w, height: h)
                .clipped()
        }
        .blendMode(.screen)
    }
}

// MARK: - Thumbnail Rarity Border Overlay

/// Lightweight animated border effects for card thumbnails in feeds.
/// Epic: rotating shimmer border. Legendary: glow pulse + shimmer border.
/// Designed to be performant in scroll views.
struct ThumbnailRarityBorderOverlay: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    @State private var phase: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0.2
    
    // Smooth-wrapping gradients: highlight fades to clear on both sides
    // with enough clear padding to eliminate the seam at 0°/360°.
    private var borderColors: [Color] {
        switch rarity {
        case .legendary:
            return [
                Color.clear,
                Color.clear,
                Color.yellow.opacity(0.15),
                Color.orange.opacity(0.6),
                Color.white.opacity(0.85),
                Color.orange.opacity(0.6),
                Color.yellow.opacity(0.15),
                Color.clear,
                Color.clear,
                Color.clear,
                Color.clear,
                Color.clear,
            ]
        case .epic:
            return [
                Color.clear,
                Color.clear,
                Color.purple.opacity(0.15),
                Color.pink.opacity(0.5),
                Color.white.opacity(0.75),
                Color.pink.opacity(0.5),
                Color.purple.opacity(0.15),
                Color.clear,
                Color.clear,
                Color.clear,
                Color.clear,
                Color.clear,
            ]
        default:
            return [Color.clear]
        }
    }
    
    var body: some View {
        ZStack {
            // Animated shimmer border — gradient travels along the border path
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: borderColors),
                        center: .center,
                        startAngle: .degrees(phase),
                        endAngle: .degrees(phase + 360)
                    ),
                    lineWidth: 2.0
                )
            
            // Legendary gets an additional glow pulse
            if rarity == .legendary {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.yellow.opacity(Double(glowIntensity)), lineWidth: 3)
                    .shadow(color: Color.yellow.opacity(Double(glowIntensity) * 0.5), radius: 6)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(
                .linear(duration: 4.0)
                .repeatForever(autoreverses: false)
            ) {
                phase = 360
            }
            
            if rarity == .legendary {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.5
                }
            }
        }
    }
}

// MARK: - Holographic Effect Configuration

/// Maps holoEffect string values to pattern asset names
enum HoloEffectType: String, CaseIterable {
    case geometric = "geometric"
    case waves = "waves"
    case stripes = "stripes"
    case stars = "stars"
    
    var assetName: String {
        switch self {
        case .geometric: return "HoloPattern"
        case .waves:     return "HoloPatternWaves"
        case .stripes:   return "HoloPatternStripes"
        case .stars:     return "HoloPatternStars"
        }
    }
    
    var displayName: String {
        switch self {
        case .geometric: return "Geometric"
        case .waves:     return "Waves"
        case .stripes:   return "Stripes"
        case .stars:     return "Stars"
        }
    }
    
    var iconName: String {
        switch self {
        case .geometric: return "square.grid.3x3.fill"
        case .waves:     return "water.waves"
        case .stripes:   return "line.diagonal"
        case .stars:     return "sparkle"
        }
    }
}

// MARK: - Holographic Effect View Modifier

/// Applies the holographic pattern overlay to any card view.
/// Use on full-size cards (gyro) or thumbnails (auto-animated).
struct HoloEffectModifier: ViewModifier {
    let holoEffect: String?
    var useGyro: Bool = true
    var cornerRadius: CGFloat = 0
    
    func body(content: Content) -> some View {
        if let effectStr = holoEffect, let effect = HoloEffectType(rawValue: effectStr) {
            content
                .overlay {
                    GeometryReader { geo in
                        HolographicPatternOverlay(
                            cornerRadius: cornerRadius > 0 ? cornerRadius : geo.size.height * 0.09,
                            patternAsset: effect.assetName,
                            useGyro: useGyro
                        )
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    /// Apply holographic foil effect overlay (gyro-driven for full-size cards)
    func holoEffect(_ effect: String?, cornerRadius: CGFloat = 0) -> some View {
        modifier(HoloEffectModifier(holoEffect: effect, useGyro: true, cornerRadius: cornerRadius))
    }
    
    /// Apply holographic foil effect overlay (auto-animated for thumbnails)
    func holoEffectThumbnail(_ effect: String?, cornerRadius: CGFloat = 0) -> some View {
        modifier(HoloEffectModifier(holoEffect: effect, useGyro: false, cornerRadius: cornerRadius))
    }
}
