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
    
    private var highlightAngle: Double {
        let r = motion.roll * 8.0
        let p = motion.pitch * 8.0
        return atan2(p, r) * (180.0 / .pi)
    }
    
    var body: some View {
        Group {
            if motion.isMoving {
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
                    .shadow(color: Color.yellow.opacity(0.4), radius: 6)
                    .transition(.opacity)
            }
        }
        .onAppear { motion.startIfNeeded() }
        .onDisappear { motion.stopIfNeeded() }
    }
}

// MARK: - Gyro Specular Strip (Legendary)

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
    @State private var tick: UInt64 = 0
    @State private var timer: Timer?
    
    private var particleCount: Int {
        rarity == .legendary ? 4 : 2
    }
    
    private var particleColor: Color {
        rarity == .legendary ? .yellow : .purple
    }
    
    private var particleAccent: Color {
        rarity == .legendary ? .white : .pink
    }
    
    var body: some View {
        Canvas { context, size in
            _ = tick  // Trigger redraw when tick changes
            
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 5.0, repeats: true) { _ in
                Task { @MainActor in
                    tick &+= 1
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
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
///
/// PRISMATIC RAINBOW: Instead of a Gaussian spotlight, the rainbow is
/// an infinitely-repeating spectrum that extends well past the card
/// boundaries. Gyro roll scrolls the rainbow laterally through the
/// pattern, creating a real holographic foil look where every tilt
/// angle reveals different colors sliding through the pattern shapes.
struct HolographicPatternOverlay: View {
    let cornerRadius: CGFloat
    var patternAsset: String = "HoloPattern"  // Asset name for the pattern
    var useGyro: Bool = true  // false = auto-animate for thumbnails
    
    @ObservedObject private var motion = CardMotionManager.shared
    @State private var autoPhase: CGFloat = 0
    
    /// Rainbow scroll offset: how far the infinite rainbow has shifted.
    /// Driven by gyro roll (left/right tilt) for full-size,
    /// or auto-animated phase for thumbnails.
    /// Range: normalized 0…1, but maps to multiple card-widths of travel.
    private var rainbowScroll: CGFloat {
        if useGyro {
            let rollRange: CGFloat = 0.15
            let rollNorm = max(-rollRange, min(rollRange, motion.roll)) / rollRange
            let pitchRange: CGFloat = 0.15
            let pitchNorm = max(-pitchRange, min(pitchRange, motion.pitch)) / pitchRange
            return (rollNorm + pitchNorm) * 1.0
        } else {
            return (autoPhase - 0.5) * 2.0
        }
    }
    
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
                    .opacity(0.15)
                
                // Layer 2: Infinite prismatic rainbow masked to pattern
                prismaticRainbowLayer(width: w, height: h)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
        .onAppear {
            if useGyro {
                motion.startIfNeeded()
            } else {
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
    private func prismaticRainbowLayer(width w: CGFloat, height h: CGFloat) -> some View {
        let imgWidth = w * 5.0
        let maxScroll = imgWidth - w
        let rawOffset = rainbowScroll * w
        let clampedOffset = max(-maxScroll / 2, min(maxScroll / 2, rawOffset))
        
        Image("PrismaticGradient")
            .resizable()
            .frame(width: imgWidth, height: h)
            .offset(x: clampedOffset)
            .frame(width: w, height: h)
            .clipped()
            .opacity(0.7)
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
