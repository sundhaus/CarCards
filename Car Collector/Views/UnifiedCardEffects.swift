//
//  UnifiedCardEffects.swift
//  Car Collector
//
//  Consolidated full-screen card effects overlay.
//
//  PERFORMANCE ARCHITECTURE:
//  - Static layers (vignette, pattern base) rendered once via drawingGroup()
//  - Image-based layers (rainbow, specular) use GPU texture offset only
//  - Particles use Timer at 5fps (not TimelineView which forces full redraws)
//  - Gyro-driven layers are isolated into separate structs so gyro updates
//    don't cascade redraws to static siblings
//  - Border animations use SwiftUI's animation system (GPU-composited)
//

import SwiftUI

// MARK: - Unified Full-Screen Effect Overlay

struct UnifiedCardEffectOverlay: View {
    let rarity: CardRarity
    let cardSize: CGSize
    let cornerRadius: CGFloat
    let holoEffect: String?
    
    // NO @ObservedObject motion here — gyro observation is pushed
    // down to only the child views that need it, preventing the
    // entire ZStack from re-evaluating on every gyro tick.
    
    private var holoPatternAsset: String? {
        guard let effectStr = holoEffect else { return nil }
        return HoloEffectType(rawValue: effectStr)?.assetName
    }
    
    var body: some View {
        ZStack {
            // STATIC VIGNETTE: Rendered once, never redrawn.
            if rarity >= .epic {
                StaticVignette(cardSize: cardSize, cornerRadius: cornerRadius)
            }
            
            // PARTICLES: Timer-driven at 5fps, no gyro dependency.
            if rarity >= .epic {
                ParticleLayer(
                    rarity: rarity,
                    cardSize: cardSize,
                    cornerRadius: cornerRadius
                )
            }
            
            // HOLO EFFECTS: Pattern base + prismatic rainbow
            if let asset = holoPatternAsset {
                // Base pattern (static, rendered once)
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipped()
                    .blendMode(.screen)
                    .opacity(0.15)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .allowsHitTesting(false)
                
                // Prismatic rainbow: observes gyro independently
                HoloRainbowLayer(
                    cardSize: cardSize,
                    cornerRadius: cornerRadius,
                    patternAsset: asset
                )
            }
            
            // OUTER EFFECTS: Border glow/shimmer
            OuterEffectsLayer(
                rarity: rarity,
                cornerRadius: cornerRadius
            )
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Static Vignette (rendered once, zero per-frame cost)

private struct StaticVignette: View {
    let cardSize: CGSize
    let cornerRadius: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let edgeInset = min(w, h) * 0.15
            
            context.opacity = 0.25
            context.fill(
                Path(CGRect(x: 0, y: 0, width: w, height: edgeInset)),
                with: .linearGradient(
                    Gradient(colors: [.black, .clear]),
                    startPoint: CGPoint(x: w/2, y: 0),
                    endPoint: CGPoint(x: w/2, y: edgeInset)
                )
            )
            context.fill(
                Path(CGRect(x: 0, y: h - edgeInset, width: w, height: edgeInset)),
                with: .linearGradient(
                    Gradient(colors: [.clear, .black]),
                    startPoint: CGPoint(x: w/2, y: h - edgeInset),
                    endPoint: CGPoint(x: w/2, y: h)
                )
            )
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Particle Layer (timer-driven at 5fps, no gyro dependency)

private struct ParticleLayer: View {
    let rarity: CardRarity
    let cardSize: CGSize
    let cornerRadius: CGFloat
    
    @State private var particles = ParticleEngine()
    @State private var tick: UInt64 = 0
    @State private var timer: Timer?
    
    private var maxCount: Int { rarity == .legendary ? 4 : 2 }
    
    private var particleRGB: (r: Double, g: Double, b: Double) {
        rarity == .legendary ? (1.0, 0.9, 0.2) : (0.7, 0.3, 1.0)
    }
    
    private var particleAccentRGB: (r: Double, g: Double, b: Double) {
        rarity == .legendary ? (1.0, 1.0, 1.0) : (1.0, 0.5, 0.8)
    }
    
    var body: some View {
        Canvas { context, size in
            _ = tick  // Trigger redraw when tick changes
            
            particles.tick(
                cardSize: cardSize,
                maxCount: maxCount,
                borderInset: cardSize.height * 0.042
            )
            
            let pColor = particleRGB
            let aColor = particleAccentRGB
            
            for particle in particles.particles where particle.alive {
                let rgb = particle.isAccent ? aColor : pColor
                let rect = CGRect(
                    x: particle.x - 2 * particle.scale,
                    y: particle.y - 2 * particle.scale,
                    width: 4 * particle.scale,
                    height: 4 * particle.scale
                )
                context.opacity = particle.opacity
                context.fill(
                    Circle().path(in: rect),
                    with: .color(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                )
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
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

// MARK: - Holo Rainbow Layer (image-based, isolated gyro observer)

private struct HoloRainbowLayer: View {
    let cardSize: CGSize
    let cornerRadius: CGFloat
    let patternAsset: String
    
    @ObservedObject private var motion = CardMotionManager.shared
    
    /// Raw scroll factor from gyro: roll drives primary scroll, pitch adds offset.
    private var rawScroll: CGFloat {
        let rollRange: CGFloat = 0.15
        let rollNorm = max(-rollRange, min(rollRange, motion.roll)) / rollRange  // -1…1
        let pitchRange: CGFloat = 0.15
        let pitchNorm = max(-pitchRange, min(pitchRange, motion.pitch)) / pitchRange  // -1…1
        return rollNorm * 1.5 + pitchNorm * 0.3
    }
    
    var body: some View {
        let w = cardSize.width
        let h = cardSize.height
        
        // Wrap the scroll offset so it always stays within one tile width.
        // This way the 3-tile strip always has the visible card window
        // fully covered regardless of how far the user tilts.
        let rawOffset = rawScroll * w
        let tileW = w  // One tile = one card width
        // fmod + re-add to handle negative values cleanly
        let wrappedOffset = rawOffset.truncatingRemainder(dividingBy: tileW)
        
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                Image("PrismaticGradient")
                    .resizable()
                    .frame(width: w, height: h)
            }
        }
        .frame(width: w * 3, height: h)
        .offset(x: wrappedOffset - w)  // Center tile at rest, wrapped scroll
        .frame(width: w, height: h, alignment: .leading)
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
    }
}

// MARK: - Outer Effects Layer (borders + glow)

private struct OuterEffectsLayer: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    @State private var borderPhase: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0.2
    
    var body: some View {
        ZStack {
            if rarity == .legendary {
                LegendaryRimLight(cornerRadius: cornerRadius)
                
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.yellow.opacity(Double(glowIntensity)), lineWidth: 4)
                    .shadow(color: Color.yellow.opacity(Double(glowIntensity) * 0.5), radius: 8)
            } else if rarity == .epic {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.clear, Color.clear,
                                Color.purple.opacity(0.15),
                                Color.pink.opacity(0.5),
                                Color.white.opacity(0.75),
                                Color.pink.opacity(0.5),
                                Color.purple.opacity(0.15),
                                Color.clear, Color.clear,
                                Color.clear, Color.clear, Color.clear,
                            ]),
                            center: .center,
                            startAngle: .degrees(borderPhase),
                            endAngle: .degrees(borderPhase + 360)
                        ),
                        lineWidth: 2.5
                    )
            } else if rarity == .rare {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                    .shadow(color: Color.cyan.opacity(0.4), radius: 8)
            }
            
            if rarity >= .epic {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(rarity.gradient, lineWidth: 1.5)
                    .padding(1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { startBorderAnimations() }
    }
    
    private func startBorderAnimations() {
        if rarity == .epic {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                borderPhase = 360
            }
        }
        if rarity == .legendary {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                borderPhase = 360
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowIntensity = 0.6
            }
        }
    }
}

// MARK: - Legendary Rim Light (isolated gyro observer)

private struct LegendaryRimLight: View {
    let cornerRadius: CGFloat
    
    @ObservedObject private var motion = CardMotionManager.shared
    
    private var rimHighlightAngle: Double {
        let r = motion.roll * 8.0
        let p = motion.pitch * 8.0
        return atan2(p, r) * (180.0 / .pi)
    }
    
    var body: some View {
        if motion.isMoving {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.clear, Color.clear,
                            Color.orange.opacity(0.4),
                            Color.yellow.opacity(0.7),
                            Color.white.opacity(0.95),
                            Color.yellow.opacity(0.7),
                            Color.orange.opacity(0.4),
                            Color.clear, Color.clear,
                            Color.clear, Color.clear, Color.clear,
                        ]),
                        center: .center,
                        startAngle: .degrees(rimHighlightAngle - 180),
                        endAngle: .degrees(rimHighlightAngle + 180)
                    ),
                    lineWidth: 3.5
                )
                .shadow(color: Color.yellow.opacity(0.4), radius: 6)
                .transition(.opacity)
        }
    }
}

// MARK: - Unified View Modifier

struct UnifiedCardEffectModifier: ViewModifier {
    let rarity: CardRarity?
    let holoEffect: String?
    
    func body(content: Content) -> some View {
        if let rarity = rarity, rarity >= .rare || holoEffect != nil {
            content
                .overlay {
                    GeometryReader { geo in
                        UnifiedCardEffectOverlay(
                            rarity: rarity,
                            cardSize: geo.size,
                            cornerRadius: geo.size.height * 0.09,
                            holoEffect: holoEffect
                        )
                    }
                }
        } else if holoEffect != nil {
            content
                .overlay {
                    GeometryReader { geo in
                        UnifiedCardEffectOverlay(
                            rarity: .common,
                            cardSize: geo.size,
                            cornerRadius: geo.size.height * 0.09,
                            holoEffect: holoEffect
                        )
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func unifiedCardEffects(rarity: CardRarity?, holoEffect: String?) -> some View {
        modifier(UnifiedCardEffectModifier(rarity: rarity, holoEffect: holoEffect))
    }
}
