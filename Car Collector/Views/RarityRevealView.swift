//
//  RarityRevealView.swift
//  Car Collector
//
//  Dramatic card reveal animation — makes every new card capture exciting.
//  Rarity determines:
//    - Background flash color & intensity
//    - Reveal animation speed & style
//    - Haptic pattern (more impactful for higher rarity)
//    - Sound effect (different per tier)
//    - Post-reveal particle burst
//
//  Usage:
//    .fullScreenCover(isPresented: $showReveal) {
//        RarityRevealView(card: newCard) { onDismiss() }
//    }
//

import SwiftUI
import AVFoundation

// MARK: - Reveal View

struct RarityRevealView: View {
    let card: AnyCard
    let onComplete: () -> Void
    
    @State private var phase: RevealPhase = .hidden
    @State private var cardScale: CGFloat = 0.3
    @State private var cardOpacity: Double = 0
    @State private var cardRotation: Double = 0
    @State private var backgroundFlash: Double = 0
    @State private var showRarityBadge = false
    @State private var showParticleBurst = false
    @State private var badgeScale: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -200
    
    private var rarity: CardRarity {
        card.rarity ?? .common
    }
    
    enum RevealPhase {
        case hidden
        case anticipation   // Card back visible, building tension
        case flip           // Card flips over
        case reveal         // Card face visible, rarity effects kick in
        case celebrate      // Particles + badge + full effects
        case idle           // User can interact
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Rarity flash
            rarityFlashBackground
            
            // Particle burst (post-reveal)
            if showParticleBurst && rarity >= .rare {
                RevealParticleBurst(rarity: rarity)
                    .ignoresSafeArea()
            }
            
            // Card
            VStack(spacing: 30) {
                Spacer()
                
                cardView
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)
                    .rotation3DEffect(
                        .degrees(cardRotation),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                
                // Rarity badge
                if showRarityBadge {
                    rarityBadge
                        .scaleEffect(badgeScale)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // Tap to continue
                if phase == .idle {
                    Text("Tap anywhere to continue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
        }
        .onTapGesture {
            if phase == .idle {
                onComplete()
            }
        }
        .onAppear {
            startRevealSequence()
        }
    }
    
    // MARK: - Card View
    
    @ViewBuilder
    private var cardView: some View {
        let cardHeight: CGFloat = 260
        let cardWidth = cardHeight * (16.0 / 9.0)
        
        ZStack {
            if phase == .hidden || phase == .anticipation {
                // Card back (mystery)
                revealCardBack
                    .frame(width: cardWidth, height: cardHeight)
            } else {
                // Card front with rarity effects
                if let rendered = CardRenderer.shared.landscapeCard(for: card, height: cardHeight * 2) {
                    Image(uiImage: rendered)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
                        .overlay {
                            // Live shimmer sweep on reveal
                            if phase == .reveal || phase == .celebrate {
                                revealShimmerSweep(width: cardWidth, height: cardHeight)
                            }
                        }
                        .rarityEffects(for: phase == .celebrate || phase == .idle ? rarity : nil)
                }
            }
        }
    }
    
    // MARK: - Card Back (Mystery — Rarity-Themed)
    
    private var revealCardBack: some View {
        let cornerRadius: CGFloat = 20.0
        
        return ZStack {
            // Rarity-tinted gradient background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: rarity.cardBackGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Subtle rarity-colored radial glow from center
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: rarity.color.opacity(0.2), location: 0),
                    .init(color: .clear, location: 0.7)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 120
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            
            // Question mark — tinted by rarity
            Image(systemName: "questionmark")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [rarity.color.opacity(0.5), rarity.color.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Rarity-colored border
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    rarity.gradient,
                    lineWidth: rarity >= .epic ? 2.5 : 1.5
                )
            
            // Epic+ gets a subtle inner shimmer on the card back too
            if rarity >= .epic {
                RoundedRectangle(cornerRadius: cornerRadius - 3)
                    .stroke(rarity.color.opacity(0.2), lineWidth: 0.5)
                    .padding(4)
            }
        }
    }
    
    // MARK: - Shimmer Sweep (reveal moment)
    
    private func revealShimmerSweep(width: CGFloat, height: CGFloat) -> some View {
        let cornerRadius = height * 0.09
        
        return LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.5),
                Color.white.opacity(0.8),
                Color.white.opacity(0.5),
                Color.white.opacity(0)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 80)
        .offset(x: shimmerOffset)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .blendMode(.overlay)
    }
    
    // MARK: - Rarity Badge
    
    private var rarityBadge: some View {
        VStack(spacing: 6) {
            Text(rarity.emoji)
                .font(.system(size: 36))
            
            Text(rarity.rawValue.uppercased())
                .font(.custom("Futura-Bold", fixedSize: 28))
                .foregroundStyle(rarity.gradient)
            
            Text(rarity.description)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }
    
    // MARK: - Flash Background
    
    @ViewBuilder
    private var rarityFlashBackground: some View {
        let flashColor: Color = {
            switch rarity {
            case .common: return .gray
            case .uncommon: return .green
            case .rare: return .blue
            case .epic: return .purple
            case .legendary: return .yellow
            }
        }()
        
        flashColor
            .opacity(backgroundFlash)
            .ignoresSafeArea()
            .blendMode(.screen)
    }
    
    // MARK: - Reveal Sequence
    
    private func startRevealSequence() {
        // Phase 1: Show card back with anticipation
        phase = .anticipation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            cardScale = 0.85
            cardOpacity = 1
        }
        
        // Phase 2: Flip (timing varies by rarity — higher = more build-up)
        let flipDelay: Double = {
            switch rarity {
            case .common: return 0.8
            case .uncommon: return 1.0
            case .rare: return 1.2
            case .epic: return 1.5
            case .legendary: return 2.0
            }
        }()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + flipDelay) {
            performFlip()
        }
    }
    
    private func performFlip() {
        phase = .flip
        
        // Haptic build-up
        triggerRevealHaptics()
        
        // Sound effect — plays at the dramatic flip moment
        RarityRevealSoundManager.shared.playRevealSound(for: rarity)
        
        // Flip animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
            cardRotation = 180
        }
        
        // Mid-flip: swap to card front (at 90°)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            phase = .reveal
            
            // Background flash
            withAnimation(.easeOut(duration: 0.3)) {
                backgroundFlash = rarity >= .epic ? 0.6 : (rarity >= .rare ? 0.3 : 0.15)
            }
            
            // Shimmer sweep across card
            withAnimation(.easeInOut(duration: 0.8)) {
                shimmerOffset = 500
            }
        }
        
        // Flash fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.5)) {
                backgroundFlash = 0
            }
        }
        
        // Scale up to full size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                cardScale = 1.0
                cardRotation = 360  // Complete the flip
            }
        }
        
        // Phase 3: Celebrate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            phase = .celebrate
            showParticleBurst = true
            
            // Rarity badge entrance
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showRarityBadge = true
                badgeScale = 1.0
            }
            
            // Final impact haptic
            triggerRevealImpact()
        }
        
        // Phase 4: Idle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                phase = .idle
            }
        }
    }
    
    // MARK: - Haptics
    
    private func triggerRevealHaptics() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        
        switch rarity {
        case .common:
            generator.impactOccurred(intensity: 0.5)
            
        case .uncommon:
            generator.impactOccurred(intensity: 0.6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generator.impactOccurred(intensity: 0.4)
            }
            
        case .rare:
            // Triple tap build
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                    generator.impactOccurred(intensity: 0.5 + Double(i) * 0.15)
                }
            }
            
        case .epic:
            // Ascending rumble
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.07) {
                    heavy.impactOccurred(intensity: 0.4 + Double(i) * 0.15)
                }
            }
            
        case .legendary:
            // Full rumble cascade
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            for i in 0..<6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                    heavy.impactOccurred(intensity: 0.3 + Double(i) * 0.14)
                }
            }
        }
    }
    
    private func triggerRevealImpact() {
        switch rarity {
        case .common, .uncommon:
            let light = UIImpactFeedbackGenerator(style: .light)
            light.impactOccurred()
            
        case .rare:
            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.impactOccurred(intensity: 0.8)
            
        case .epic:
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            }
            
        case .legendary:
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let heavy = UIImpactFeedbackGenerator(style: .heavy)
                heavy.impactOccurred(intensity: 1.0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                notification.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Reveal Particle Burst

/// Explosion of particles outward from center on reveal
struct RevealParticleBurst: View {
    let rarity: CardRarity
    
    @State private var particles: [BurstParticle] = []
    @State private var hasSpawned = false
    
    private var burstCount: Int {
        switch rarity {
        case .common: return 0
        case .uncommon: return 8
        case .rare: return 16
        case .epic: return 30
        case .legendary: return 50
        }
    }
    
    private var burstColor: Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .cyan
        case .epic: return .purple
        case .legendary: return .yellow
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
                    let color: Color = p.isAccent ? .white : burstColor
                    let rect = CGRect(
                        x: p.x - p.size / 2,
                        y: p.y - p.size / 2,
                        width: p.size,
                        height: p.size
                    )
                    context.opacity = p.opacity
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(color)
                    )
                }
            }
            .onAppear {
                guard !hasSpawned else { return }
                hasSpawned = true
                
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                
                // Create particles at center
                particles = (0..<burstCount).map { _ in
                    let angle = CGFloat.random(in: 0...(2 * .pi))
                    let distance = CGFloat.random(in: 150...400)
                    return BurstParticle(
                        x: center.x,
                        y: center.y,
                        targetX: center.x + cos(angle) * distance,
                        targetY: center.y + sin(angle) * distance,
                        opacity: 1.0,
                        size: CGFloat.random(in: 3...8),
                        isAccent: Double.random(in: 0...1) < 0.3
                    )
                }
                
                // Animate outward
                withAnimation(.easeOut(duration: 1.0)) {
                    particles = particles.map { p in
                        var updated = p
                        updated.x = p.targetX
                        updated.y = p.targetY
                        return updated
                    }
                }
                
                // Fade
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        particles = particles.map { p in
                            var updated = p
                            updated.opacity = 0
                            return updated
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sound Effects Manager

class RarityRevealSoundManager {
    static let shared = RarityRevealSoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    /// Play a system sound appropriate for the rarity tier.
    /// Falls back to haptics if custom sounds aren't bundled.
    func playRevealSound(for rarity: CardRarity) {
        // Use system sounds as placeholders — replace with custom audio files
        let soundID: SystemSoundID = {
            switch rarity {
            case .common:    return 1057  // Tink
            case .uncommon:  return 1075  // Swish
            case .rare:      return 1025  // Short ding
            case .epic:      return 1026  // Ascending chime
            case .legendary: return 1335  // Triumphant (payment success)
            }
        }()
        
        AudioServicesPlaySystemSound(soundID)
        
        // Legendary gets a second delayed sound for dramatic effect
        if rarity == .legendary {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AudioServicesPlaySystemSound(1335)
            }
        }
    }
}
