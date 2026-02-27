//
//  UnifiedCardEffects.swift
//  Car Collector
//
//  Consolidated full-screen card effects that merge holographic pattern,
//  specular strip, particles, rim light, shimmer border, and glow pulse
//  into minimal draw calls.
//
//  BEFORE: 6+ separate animated views, each independently observing gyro,
//  each with its own Canvas or gradient — one gyro tick triggers redraws
//  across all of them.
//
//  AFTER: One TimelineView driving a single Canvas for inner effects
//  (holo rainbow + specular + particles), plus one SwiftUI view for
//  outer effects (border glow). Gyro read once per frame, shared.
//
//  PERFORMANCE: ~3x fewer draw calls, single gyro subscription,
//  single rasterization via drawingGroup().
//

import SwiftUI

// MARK: - Unified Full-Screen Effect Overlay

/// Replaces the combination of `.holoEffect()` + `.rarityEffects()` for
/// full-size card displays. Renders all visual effects in consolidated
/// draw passes to minimize GPU compositing overhead.
struct UnifiedCardEffectOverlay: View {
    let rarity: CardRarity
    let cardSize: CGSize
    let cornerRadius: CGFloat
    let holoEffect: String?
    
    @ObservedObject private var motion = CardMotionManager.shared
    @State private var particles = ParticleEngine()
    @State private var borderPhase: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0.2
    
    // Gyro-derived values computed once per body evaluation
    private var specularCenter: CGFloat {
        let pitchRange: CGFloat = 0.15
        let clamped = max(-pitchRange, min(pitchRange, motion.pitch))
        return 0.5 + (clamped / pitchRange) * 0.5
    }
    
    private var isMoving: Bool {
        motion.isMoving
    }
    
    private var rimHighlightAngle: Double {
        let r = motion.roll * 8.0
        let p = motion.pitch * 8.0
        return atan2(p, r) * (180.0 / .pi)
    }
    
    // Holo pattern config
    private var holoPatternAsset: String? {
        guard let effectStr = holoEffect else { return nil }
        return HoloEffectType(rawValue: effectStr)?.assetName
    }
    
    // Rarity tint colors for specular strip
    private var specularTintRGB: (r: Double, g: Double, b: Double) {
        switch rarity {
        case .legendary: return (1.0, 0.85, 0.4)
        case .epic:      return (0.7, 0.4, 1.0)
        default:         return (1.0, 1.0, 1.0)
        }
    }
    
    // Particle colors
    private var particleRGB: (r: Double, g: Double, b: Double) {
        rarity == .legendary ? (1.0, 0.9, 0.2) : (0.7, 0.3, 1.0)
    }
    
    private var particleAccentRGB: (r: Double, g: Double, b: Double) {
        rarity == .legendary ? (1.0, 1.0, 1.0) : (1.0, 0.5, 0.8)
    }
    
    var body: some View {
        ZStack {
            // INNER EFFECTS: Single Canvas for vignette + specular + particles
            // Driven by TimelineView at 15fps for particle ticks
            if rarity >= .epic {
                innerCanvas
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .drawingGroup()
            }
            
            // HOLO EFFECTS: Pattern base + rainbow masked to pattern
            // These need Image views for the asset texture, so they stay
            // as separate SwiftUI layers — but share the same gyro data
            if let asset = holoPatternAsset {
                // Base pattern (subtle white texture always visible)
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipped()
                    .blendMode(.screen)
                    .opacity(0.15)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .allowsHitTesting(false)
                
                // Rainbow refraction — masked to pattern pixels, always visible
                // as a prismatic foil. Gyro roll scrolls the rainbow through the pattern.
                holoRainbowView
                    .frame(width: cardSize.width, height: cardSize.height)
                    .mask {
                        Image(asset)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardSize.width, height: cardSize.height)
                            .clipped()
                    }
                    .blendMode(.screen)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .allowsHitTesting(false)
            }
            
            // OUTER EFFECTS: Border glow/shimmer (needs shadow bleed, not clipped)
            outerEffects
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .allowsHitTesting(false)
        .onAppear {
            motion.startIfNeeded()
            startBorderAnimations()
        }
        .onDisappear {
            motion.stopIfNeeded()
        }
    }
    
    // MARK: - Inner Canvas (Specular + Particles in one draw)
    
    private var innerCanvas: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            Canvas { context, size in
                let w = size.width
                let h = size.height
                
                // === Full-bleed vignette (Epic+) ===
                if rarity >= .epic {
                    // Darken edges — simple radial approximation via corner rects
                    let edgeInset = min(w, h) * 0.15
                    let edgeOpacity = 0.25
                    // Top edge
                    context.opacity = edgeOpacity
                    context.fill(
                        Path(CGRect(x: 0, y: 0, width: w, height: edgeInset)),
                        with: .linearGradient(
                            Gradient(colors: [.black, .clear]),
                            startPoint: CGPoint(x: w/2, y: 0),
                            endPoint: CGPoint(x: w/2, y: edgeInset)
                        )
                    )
                    // Bottom edge
                    context.fill(
                        Path(CGRect(x: 0, y: h - edgeInset, width: w, height: edgeInset)),
                        with: .linearGradient(
                            Gradient(colors: [.clear, .black]),
                            startPoint: CGPoint(x: w/2, y: h - edgeInset),
                            endPoint: CGPoint(x: w/2, y: h)
                        )
                    )
                    context.opacity = 1.0
                }
                
                // === Specular strip (Epic+) ===
                if rarity >= .epic && isMoving {
                    let sigma = w * 0.15
                    let center = specularCenter * w
                    let tint = specularTintRGB
                    let step: CGFloat = 4.0
                    var x: CGFloat = 0
                    
                    while x < w {
                        let dist = x - center
                        let gaussian = exp(-0.5 * (dist * dist) / (sigma * sigma))
                        let intensity = 0.25 * gaussian
                        
                        if intensity > 0.01 {
                            let rect = CGRect(x: x, y: 0, width: step, height: h)
                            context.opacity = intensity
                            context.fill(
                                Path(rect),
                                with: .color(Color(red: tint.r, green: tint.g, blue: tint.b))
                            )
                        }
                        x += step
                    }
                    context.opacity = 1.0
                }
                
                // === Particles (Epic+) ===
                if rarity >= .epic {
                    let maxCount = rarity == .legendary ? 4 : 2
                    particles.tick(
                        cardSize: size,
                        maxCount: maxCount,
                        borderInset: h * 0.042
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
                    context.opacity = 1.0
                }
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }
    
    // MARK: - Holo Rainbow (image-based prismatic strip, masked to pattern externally)
    
    /// Scroll offset for the prismatic rainbow: gyro roll drives left/right scroll,
    /// pitch adds a subtle secondary offset. The rainbow repeats infinitely so
    /// every tilt angle shows full-saturation color flowing through the pattern.
    private var rainbowScroll: CGFloat {
        let rollRange: CGFloat = 0.15
        let rollNorm = max(-rollRange, min(rollRange, motion.roll)) / rollRange  // -1…1
        let pitchRange: CGFloat = 0.15
        let pitchNorm = max(-pitchRange, min(pitchRange, motion.pitch)) / pitchRange  // -1…1
        return rollNorm * 1.5 + pitchNorm * 0.3
    }
    
    @ViewBuilder
    private var holoRainbowView: some View {
        // Pre-rendered rainbow image tiled 3x wide, scrolled by gyro.
        // Replaces per-frame Canvas drawing — zero CPU cost per frame.
        let w = cardSize.width
        let h = cardSize.height
        let scrollOffset = rainbowScroll * w
        
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                Image("PrismaticRainbow")
                    .resizable()
                    .frame(width: w, height: h)
            }
        }
        .frame(width: w * 3, height: h)
        .offset(x: scrollOffset - w)
        .frame(width: w, height: h, alignment: .leading)
        .clipped()
        .opacity(0.7)
    }
    
    // MARK: - Outer Effects (Border + Glow)
    
    @ViewBuilder
    private var outerEffects: some View {
        if rarity == .legendary {
            // Consolidated: rim light + glow pulse in one ZStack
            ZStack {
                // Gyro rim light
                if isMoving {
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
                }
                
                // Glow pulse
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.yellow.opacity(Double(glowIntensity)), lineWidth: 4)
                    .shadow(color: Color.yellow.opacity(Double(glowIntensity) * 0.6), radius: 10)
            }
        } else if rarity == .epic {
            // Animated shimmer border
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
            // Static cyan glow border
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                .shadow(color: Color.cyan.opacity(0.4), radius: 8)
        }
        
        // Thin accent stroke for Epic+ (static)
        if rarity >= .epic {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(rarity.gradient, lineWidth: 1.5)
                .padding(1)
        }
    }
    
    // MARK: - Animations
    
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

// MARK: - Unified View Modifier

/// Single modifier that replaces `.holoEffect()` + `.rarityEffects()` for
/// full-size card displays. Consolidates all GPU work into fewer draw calls.
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
            // Has holo but rarity below rare — still show holo pattern
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
    /// Unified full-screen card effects — replaces `.holoEffect()` + `.rarityEffects()`
    /// with a single consolidated overlay for better GPU performance.
    func unifiedCardEffects(rarity: CardRarity?, holoEffect: String?) -> some View {
        modifier(UnifiedCardEffectModifier(rarity: rarity, holoEffect: holoEffect))
    }
}
