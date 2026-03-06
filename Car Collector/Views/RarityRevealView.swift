//
//  RarityRevealView.swift
//  Car Collector
//
//  Cinematic card reveal — the emotional payoff of every capture.
//
//  Sequence:
//    1. DARKNESS — screen is black, subtle light rays pulse from center
//    2. CARD RISES — card back floats up from bottom with slow spin,
//       rarity-colored edge glow builds as it rises
//    3. SLAM — card snaps to center, screen shakes, card cracks with light
//    4. FLIP — card flips over revealing the front, background explodes
//       with rarity-colored light burst
//    5. CELEBRATE — rarity badge slams in, particles burst, card settles
//       with live effects (shimmer, glow, tilt)
//    6. IDLE — "Tap to continue" fades in, card has drag-to-tilt
//
//  Higher rarity = longer build-up, more dramatic effects, heavier haptics.
//

import SwiftUI
import AVFoundation

// MARK: - Reveal View

struct RarityRevealView: View {
    let card: AnyCard
    let onComplete: () -> Void
    
    // Phase state
    @State private var phase: RevealPhase = .darkness
    
    // Card transform
    @State private var cardY: CGFloat = 800          // Start below screen
    @State private var cardScale: CGFloat = 0.6
    @State private var cardOpacity: Double = 0
    @State private var cardRotationY: Double = 0      // Y-axis flip
    @State private var cardRotationZ: Double = -8     // Slight initial tilt
    @State private var showFront = false
    
    // Background effects
    @State private var backgroundFlash: Double = 0
    @State private var lightRayOpacity: Double = 0
    @State private var lightRayScale: CGFloat = 0.5
    @State private var edgeGlowIntensity: Double = 0
    
    // Celebration
    @State private var showRarityBadge = false
    @State private var badgeScale: CGFloat = 0
    @State private var badgeY: CGFloat = 30
    @State private var showParticles = false
    @State private var shimmerOffset: CGFloat = -300
    @State private var screenShake: CGFloat = 0
    
    // Idle
    @State private var allowDismiss = false
    @State private var dismissOpacity: Double = 0
    
    // Card name display
    @State private var nameOpacity: Double = 0
    @State private var nameY: CGFloat = 20
    
    private var rarity: CardRarity {
        card.rarity ?? .common
    }
    
    enum RevealPhase {
        case darkness
        case rising
        case slam
        case flip
        case reveal
        case celebrate
        case idle
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Light rays from center (pre-reveal anticipation)
            lightRays
            
            // Rarity flash burst
            rarityFlash
            
            // Particle burst
            if showParticles && rarity >= .rare {
                RevealParticleBurst(rarity: rarity)
                    .ignoresSafeArea()
            }
            
            // Main content
            VStack(spacing: 0) {
                Spacer()
                
                // Card
                cardView
                    .offset(y: cardY)
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)
                    .rotation3DEffect(
                        .degrees(cardRotationY),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.4
                    )
                    .rotationEffect(.degrees(cardRotationZ))
                
                // Car name (appears after flip)
                if showFront {
                    VStack(spacing: 6) {
                        Text(card.displayTitle.uppercased())
                            .font(.custom("Futura-Bold", fixedSize: 22))
                            .foregroundStyle(.white)
                            .shadow(color: rarity.color.opacity(0.8), radius: 8)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        if let subtitle = card.displaySubtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.pSubheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .opacity(nameOpacity)
                    .offset(y: nameY)
                    .padding(.top, 24)
                }
                
                // Rarity badge
                if showRarityBadge {
                    rarityBadge
                        .scaleEffect(badgeScale)
                        .offset(y: badgeY)
                        .padding(.top, 16)
                }
                
                Spacer()
                
                // Tap to continue
                if allowDismiss {
                    Button(action: { onComplete() }) {
                        Text("TAP TO CONTINUE")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.bottom, 50)
                    }
                    .opacity(dismissOpacity)
                    .transition(.opacity)
                }
            }
        }
        .offset(x: screenShake)
        .onTapGesture {
            if allowDismiss { onComplete() }
        }
        .onAppear {
            startSequence()
        }
    }
    
    // MARK: - Card View
    
    @ViewBuilder
    private var cardView: some View {
        let cardHeight: CGFloat = 240
        let cardWidth = cardHeight * (16.0 / 9.0)
        let cornerRadius = cardHeight * 0.09
        
        ZStack {
            if !showFront {
                // Card back — mystery card
                cardBack(width: cardWidth, height: cardHeight, cornerRadius: cornerRadius)
            } else {
                // Card front — the real card with effects
                cardFront(width: cardWidth, height: cardHeight, cornerRadius: cornerRadius)
            }
        }
        // Edge glow (builds during rise, pulses during anticipation)
        .shadow(color: rarity.color.opacity(edgeGlowIntensity), radius: 20, x: 0, y: 0)
        .shadow(color: rarity.color.opacity(edgeGlowIntensity * 0.5), radius: 40, x: 0, y: 0)
    }
    
    // MARK: - Card Back
    
    private func cardBack(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        ZStack {
            // Dark gradient base
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.08, blue: 0.12),
                            Color(red: 0.04, green: 0.04, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Rarity-colored radial glow from center
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: rarity.color.opacity(0.15), location: 0),
                    .init(color: .clear, location: 0.7)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: min(width, height) * 0.6
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            
            // Diagonal line pattern (subtle texture)
            Canvas { context, size in
                context.opacity = 0.06
                for i in stride(from: -size.width, to: size.width * 2, by: 12) {
                    var path = Path()
                    path.move(to: CGPoint(x: i, y: 0))
                    path.addLine(to: CGPoint(x: i + size.height, y: size.height))
                    context.stroke(path, with: .color(.white), lineWidth: 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            
            // Question mark
            Image(systemName: "questionmark")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [rarity.color.opacity(0.4), rarity.color.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Border
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [rarity.color.opacity(0.5), rarity.color.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        }
        .frame(width: width, height: height)
    }
    
    // MARK: - Card Front
    
    private func cardFront(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        ZStack {
            if let rendered = CardRenderer.shared.landscapeCard(for: card, height: height * 2) {
                Image(uiImage: rendered)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    // Shimmer sweep on reveal
                    .overlay {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.7),
                                Color.white.opacity(0.4),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 100)
                        .offset(x: shimmerOffset)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .blendMode(.overlay)
                    }
                    // Rarity border effects (once celebrating)
                    .overlay {
                        if phase == .celebrate || phase == .idle {
                            if rarity >= .epic {
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(rarity.gradient, lineWidth: 2.5)
                            } else if rarity >= .rare {
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(rarity.color.opacity(0.6), lineWidth: 2)
                            }
                        }
                    }
            } else {
                // Fallback if renderer hasn't produced the card yet
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(white: 0.15))
                    .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
    }
    
    // MARK: - Light Rays
    
    private var lightRays: some View {
        ZStack {
            // Radial light behind the card
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: rarity.color.opacity(0.3), location: 0),
                    .init(color: rarity.color.opacity(0.05), location: 0.5),
                    .init(color: .clear, location: 1.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .scaleEffect(lightRayScale)
            .opacity(lightRayOpacity)
            
            // Directional rays (fan out from center)
            if phase == .reveal || phase == .celebrate || phase == .idle {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height * 0.45)
                    let rayCount = rarity >= .epic ? 24 : (rarity >= .rare ? 16 : 10)
                    
                    for i in 0..<rayCount {
                        let angle = (CGFloat(i) / CGFloat(rayCount)) * .pi * 2
                        let length: CGFloat = max(size.width, size.height) * 0.8
                        let spread: CGFloat = 0.03
                        
                        var path = Path()
                        path.move(to: center)
                        path.addLine(to: CGPoint(
                            x: center.x + cos(angle - spread) * length,
                            y: center.y + sin(angle - spread) * length
                        ))
                        path.addLine(to: CGPoint(
                            x: center.x + cos(angle + spread) * length,
                            y: center.y + sin(angle + spread) * length
                        ))
                        path.closeSubpath()
                        
                        context.opacity = 0.08
                        context.fill(path, with: .color(rarity.color))
                    }
                }
                .ignoresSafeArea()
                .opacity(lightRayOpacity)
            }
        }
    }
    
    // MARK: - Rarity Flash
    
    private var rarityFlash: some View {
        rarity.color
            .opacity(backgroundFlash)
            .ignoresSafeArea()
            .blendMode(.screen)
    }
    
    // MARK: - Rarity Badge
    
    private var rarityBadge: some View {
        VStack(spacing: 8) {
            Text(rarity.rawValue.uppercased())
                .font(.custom("Futura-Bold", fixedSize: 32))
                .foregroundStyle(rarity.gradient)
                .shadow(color: rarity.color.opacity(0.5), radius: 12)
            
            Text(rarity.description)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    // MARK: - Reveal Sequence
    
    private func startSequence() {
        // Timing scales with rarity — higher = more dramatic
        let riseDuration: Double = rarity >= .legendary ? 1.4 : (rarity >= .epic ? 1.2 : (rarity >= .rare ? 1.0 : 0.8))
        let anticipationHold: Double = rarity >= .legendary ? 0.8 : (rarity >= .epic ? 0.5 : 0.3)
        
        // ---- PHASE 1: DARKNESS (brief) ----
        phase = .darkness
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            
            // ---- PHASE 2: RISING ----
            phase = .rising
            
            // Card appears and floats up
            withAnimation(.spring(response: riseDuration, dampingFraction: 0.75)) {
                cardY = 0
                cardScale = 0.85
                cardOpacity = 1
                cardRotationZ = 0
            }
            
            // Edge glow builds as card rises
            withAnimation(.easeIn(duration: riseDuration * 0.8)) {
                edgeGlowIntensity = 0.4
            }
            
            // Light rays start
            withAnimation(.easeIn(duration: riseDuration)) {
                lightRayOpacity = 0.5
                lightRayScale = 1.0
            }
            
            // Haptic build during rise
            triggerRiseHaptics()
            
            // ---- PHASE 3: SLAM (card snaps to final position) ----
            let slamTime = riseDuration + anticipationHold
            DispatchQueue.main.asyncAfter(deadline: .now() + slamTime) {
                phase = .slam
                
                // Snap scale slightly bigger then settle
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    cardScale = 1.05
                }
                
                // Screen shake
                triggerScreenShake()
                
                // Edge glow pulse
                withAnimation(.easeOut(duration: 0.2)) {
                    edgeGlowIntensity = 0.8
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                    edgeGlowIntensity = 0.3
                }
                
                // Impact haptic
                let heavy = UIImpactFeedbackGenerator(style: .heavy)
                heavy.impactOccurred(intensity: 1.0)
                
                // ---- PHASE 4: FLIP ----
                let flipDelay = 0.4
                DispatchQueue.main.asyncAfter(deadline: .now() + flipDelay) {
                    performFlip()
                }
            }
        }
    }
    
    private func performFlip() {
        phase = .flip
        
        // Sound
        RarityRevealSoundManager.shared.playRevealSound(for: rarity)
        
        // Flip haptics
        triggerFlipHaptics()
        
        // Flip animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            cardRotationY = 90
            cardScale = 0.95
        }
        
        // At 90° (edge-on), swap to front face
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showFront = true
            phase = .reveal
            
            // Complete flip to 0° (front facing)
            // We set it to -90 first so it continues the rotation direction
            cardRotationY = -90
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                cardRotationY = 0
                cardScale = 1.0
            }
            
            // Background flash burst
            withAnimation(.easeOut(duration: 0.15)) {
                backgroundFlash = rarity >= .epic ? 0.7 : (rarity >= .rare ? 0.4 : 0.2)
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                backgroundFlash = 0
            }
            
            // Light rays intensify
            withAnimation(.easeOut(duration: 0.5)) {
                lightRayOpacity = rarity >= .epic ? 0.8 : 0.4
                lightRayScale = 1.5
            }
            
            // Shimmer sweep across card
            withAnimation(.easeInOut(duration: 0.7).delay(0.1)) {
                shimmerOffset = 500
            }
            
            // Edge glow settles to rarity level
            withAnimation(.easeOut(duration: 0.8)) {
                edgeGlowIntensity = rarity >= .epic ? 0.6 : (rarity >= .rare ? 0.4 : 0.2)
            }
            
            // Car name fades in
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                nameOpacity = 1
                nameY = 0
            }
        }
        
        // ---- PHASE 5: CELEBRATE ----
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            phase = .celebrate
            showParticles = true
            
            // Rarity badge entrance
            showRarityBadge = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                badgeScale = 1.0
                badgeY = 0
            }
            
            // Impact haptic for badge
            triggerCelebrateHaptics()
            
            // Light rays settle
            withAnimation(.easeOut(duration: 1.0)) {
                lightRayOpacity = 0.15
                lightRayScale = 1.2
            }
        }
        
        // ---- PHASE 6: IDLE ----
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.4)) {
                phase = .idle
                allowDismiss = true
                dismissOpacity = 1
            }
        }
    }
    
    // MARK: - Screen Shake
    
    private func triggerScreenShake() {
        let intensity: CGFloat = rarity >= .legendary ? 12 : (rarity >= .epic ? 8 : (rarity >= .rare ? 5 : 3))
        let shakeCount = rarity >= .epic ? 6 : 4
        
        for i in 0..<shakeCount {
            let delay = Double(i) * 0.04
            let dampening = 1.0 - (Double(i) / Double(shakeCount))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 0.04)) {
                    screenShake = (i % 2 == 0 ? 1 : -1) * intensity * dampening
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(shakeCount) * 0.04) {
            withAnimation(.spring(response: 0.2)) {
                screenShake = 0
            }
        }
    }
    
    // MARK: - Haptics
    
    private func triggerRiseHaptics() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        
        // Soft taps during rise — faster for higher rarity
        let tapCount = rarity >= .epic ? 6 : (rarity >= .rare ? 4 : 2)
        let interval = rarity >= .legendary ? 0.12 : 0.15
        
        for i in 0..<tapCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                generator.impactOccurred(intensity: 0.3 + Double(i) * 0.1)
            }
        }
    }
    
    private func triggerFlipHaptics() {
        switch rarity {
        case .common, .uncommon:
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred(intensity: 0.6)
            
        case .rare:
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred(intensity: 0.5 + Double(i) * 0.15)
                }
            }
            
        case .epic:
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                    heavy.impactOccurred(intensity: 0.5 + Double(i) * 0.15)
                }
            }
            
        case .legendary:
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            for i in 0..<6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                    heavy.impactOccurred(intensity: 0.3 + Double(i) * 0.14)
                }
            }
        }
    }
    
    private func triggerCelebrateHaptics() {
        switch rarity {
        case .common:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
        case .uncommon:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
            
        case .rare:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            
        case .epic:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
            }
            
        case .legendary:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Reveal Particle Burst

struct RevealParticleBurst: View {
    let rarity: CardRarity
    
    @State private var particles: [BurstParticle] = []
    @State private var hasSpawned = false
    
    private var burstCount: Int {
        switch rarity {
        case .common: return 0
        case .uncommon: return 12
        case .rare: return 24
        case .epic: return 40
        case .legendary: return 60
        }
    }
    
    struct BurstParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var targetX: CGFloat
        var targetY: CGFloat
        var opacity: Double
        var size: CGFloat
        var isAccent: Bool
    }
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for p in particles {
                    let color: Color = p.isAccent ? .white : rarity.color
                    let rect = CGRect(
                        x: p.x - p.size / 2,
                        y: p.y - p.size / 2,
                        width: p.size,
                        height: p.size
                    )
                    context.opacity = p.opacity
                    
                    if p.isAccent {
                        // Stars for accent particles
                        let star = Path { path in
                            let center = CGPoint(x: rect.midX, y: rect.midY)
                            let r = p.size / 2
                            for i in 0..<4 {
                                let angle = CGFloat(i) * .pi / 2
                                let start = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                                if i == 0 { path.move(to: start) } else { path.addLine(to: start) }
                            }
                            path.closeSubpath()
                        }
                        context.fill(star, with: .color(color))
                    } else {
                        context.fill(Circle().path(in: rect), with: .color(color))
                    }
                }
            }
            .onAppear {
                guard !hasSpawned else { return }
                hasSpawned = true
                
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)
                
                particles = (0..<burstCount).map { _ in
                    let angle = CGFloat.random(in: 0...(2 * .pi))
                    let distance = CGFloat.random(in: 100...450)
                    return BurstParticle(
                        x: center.x,
                        y: center.y,
                        targetX: center.x + cos(angle) * distance,
                        targetY: center.y + sin(angle) * distance,
                        opacity: 1.0,
                        size: CGFloat.random(in: 2...7),
                        isAccent: Double.random(in: 0...1) < 0.25
                    )
                }
                
                withAnimation(.easeOut(duration: 1.2)) {
                    particles = particles.map { p in
                        var u = p
                        u.x = p.targetX
                        u.y = p.targetY
                        return u
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        particles = particles.map { p in
                            var u = p
                            u.opacity = 0
                            return u
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sound Effects

class RarityRevealSoundManager {
    static let shared = RarityRevealSoundManager()
    private init() {}
    
    func playRevealSound(for rarity: CardRarity) {
        let soundID: SystemSoundID = {
            switch rarity {
            case .common:    return 1057  // Tink
            case .uncommon:  return 1075  // Swish
            case .rare:      return 1025  // Short ding
            case .epic:      return 1026  // Ascending chime
            case .legendary: return 1335  // Triumphant
            }
        }()
        
        AudioServicesPlaySystemSound(soundID)
        
        if rarity == .legendary {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AudioServicesPlaySystemSound(1335)
            }
        }
    }
}
