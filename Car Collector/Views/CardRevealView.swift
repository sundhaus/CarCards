//
//  CardRevealView.swift
//  Car Collector
//
//  Interactive card reveal:
//    1. Black screen, white rectangle (card sleeve) centered
//    2. User drags finger across top of rectangle — card slides up from behind
//    3. Card spins faster and faster once fully emerged
//    4. Rarity-colored poof/burst around card
//    5. Spin slows, card presents front with correct rarity border
//    6. Tap to flip and see stats
//

import SwiftUI
import AVFoundation

struct CardRevealView: View {
    let card: SavedCard
    @Binding var savedCards: [SavedCard]
    let onComplete: () -> Void
    
    // Phases
    @State private var phase: RevealPhase = .waiting
    
    // Drag to reveal
    @State private var dragProgress: CGFloat = 0     // 0 = hidden, 1 = fully emerged
    @State private var cardOffsetY: CGFloat = 0      // How far card has slid up
    
    // Spin
    @State private var spinAngle: Double = 0
    @State private var spinSpeed: Double = 0
    @State private var spinTimer: Timer?
    
    // Poof / burst
    @State private var showPoof = false
    @State private var poofScale: CGFloat = 0.3
    @State private var poofOpacity: Double = 1.0
    
    // Final presentation
    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0
    @State private var presentationScale: CGFloat = 1.0
    
    // Specs ready tracking
    @State private var specsReady = false
    @State private var cardSpecs: VehicleSpecs?
    
    private enum RevealPhase {
        case waiting      // Black screen + sleeve, waiting for drag
        case dragging     // User is dragging card out
        case spinning     // Card is spinning
        case poof         // Rarity burst
        case presenting   // Card shown, tappable
    }
    
    // Card dimensions
    private let cardHeight: CGFloat = 220
    private var cardWidth: CGFloat { cardHeight * (16.0 / 9.0) }
    private let sleeveHeight: CGFloat = 250
    private var sleeveWidth: CGFloat { 220 * (16.0 / 9.0) + 30 }
    private let cornerRadius: CGFloat = 15
    
    // Get live card from savedCards binding (has specs once they arrive)
    private var liveCard: SavedCard {
        savedCards.first(where: { $0.id == card.id }) ?? card
    }
    
    private var rarity: CardRarity {
        liveCard.specs?.rarity ?? .common
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch phase {
            case .waiting, .dragging:
                dragRevealView
            case .spinning:
                spinningView
            case .poof:
                poofView
            case .presenting:
                presentationView
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SpecsReady"))) { notification in
            if let cardId = notification.object as? UUID, cardId == card.id {
                specsReady = true
                cardSpecs = liveCard.specs
            }
        }
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
            // Check if specs already exist
            if liveCard.specs != nil {
                specsReady = true
                cardSpecs = liveCard.specs
            }
        }
        .onDisappear {
            spinTimer?.invalidate()
            OrientationManager.unlockOrientation()
        }
    }
    
    // MARK: - Phase 1: Drag Reveal
    
    private var dragRevealView: some View {
        VStack {
            Spacer()
            
            ZStack {
                // Card sliding up from behind the sleeve
                cardBackImage
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .offset(y: -dragProgress * (sleeveHeight * 0.6))
                    .opacity(dragProgress > 0.05 ? 1 : 0)
                
                // White sleeve (card pack)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.95),
                                Color(white: 0.88),
                                Color(white: 0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: sleeveWidth, height: sleeveHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.15), radius: 12)
                
                // Sleeve label
                VStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.gray.opacity(0.4))
                    
                    Text("CARCARDS")
                        .font(.custom("Futura-Bold", fixedSize: 14))
                        .tracking(4)
                        .foregroundStyle(.gray.opacity(0.3))
                }
                
                // Drag hint
                if phase == .waiting {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .medium))
                            Text("Swipe up to reveal")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .offset(y: -sleeveHeight / 2 - 30)
                    }
                }
            }
            
            Spacer()
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    // Only respond to upward drags
                    let dragAmount = -value.translation.height
                    guard dragAmount > 0 else { return }
                    
                    if phase == .waiting { phase = .dragging }
                    
                    // Map drag distance to 0...1 progress
                    let maxDrag: CGFloat = 250
                    dragProgress = min(1.0, dragAmount / maxDrag)
                    
                    // Light haptic feedback as card emerges
                    if dragProgress > 0.1 && dragProgress < 0.15 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
                    }
                    if dragProgress > 0.5 && dragProgress < 0.55 {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.6)
                    }
                }
                .onEnded { value in
                    let dragAmount = -value.translation.height
                    
                    if dragAmount > 150 || dragProgress > 0.6 {
                        // Enough drag — trigger spin
                        withAnimation(.easeOut(duration: 0.3)) {
                            dragProgress = 1.0
                        }
                        
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.8)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            startSpinning()
                        }
                    } else {
                        // Not enough — snap back
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            dragProgress = 0
                            phase = .waiting
                        }
                    }
                }
        )
    }
    
    // MARK: - Phase 2: Spinning
    
    private var spinningView: some View {
        ZStack {
            // Rarity glow builds behind card during spin
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: rarity.color.opacity(specsReady ? 0.3 : 0.05), location: 0),
                    .init(color: .clear, location: 0.7)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            cardBackImage
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .rotation3DEffect(
                    .degrees(spinAngle),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.4
                )
                .shadow(color: rarity.color.opacity(specsReady ? 0.4 : 0.1), radius: 16)
        }
    }
    
    // MARK: - Phase 3: Poof
    
    private var poofView: some View {
        ZStack {
            // Burst particles
            if showPoof {
                RevealPoofBurst(rarity: rarity)
                    .ignoresSafeArea()
            }
            
            // Card front emerging from poof
            cardFrontView
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .scaleEffect(presentationScale)
                .shadow(color: rarity.color.opacity(0.6), radius: 20)
        }
    }
    
    // MARK: - Phase 4: Presentation
    
    private var presentationView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Tappable card that flips
            ZStack {
                if !isFlipped {
                    cardFrontView
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
                }
                
                if isFlipped {
                    cardBackStatsView
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
                }
            }
            .shadow(color: rarity.color.opacity(0.5), radius: 20)
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    flipDegrees += 180
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isFlipped.toggle()
                    }
                }
            }
            
            // Car name + rarity
            VStack(spacing: 8) {
                Text("\(liveCard.make.uppercased()) \(liveCard.model.uppercased())")
                    .font(.custom("Futura-Bold", fixedSize: 20))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(rarity.rawValue.uppercased())
                    .font(.custom("Futura-Bold", fixedSize: 16))
                    .foregroundStyle(rarity.gradient)
                
                if !liveCard.year.isEmpty {
                    Text(liveCard.year)
                        .font(.pSubheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.top, 24)
            
            Spacer()
            
            // Tap to flip hint + continue
            VStack(spacing: 16) {
                if !isFlipped {
                    Text("Tap card to see stats")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Button(action: onComplete) {
                    Text("CONTINUE")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 14)
                        .background(rarity.color.opacity(0.8))
                        .cornerRadius(12)
                }
            }
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Card Views
    
    private var cardBackImage: some View {
        ZStack {
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
            
            // Diagonal line texture
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
            
            Image(systemName: "questionmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white.opacity(0.15))
            
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
        }
    }
    
    @ViewBuilder
    private var cardFrontView: some View {
        if let rendered = CardRenderer.shared.landscapeCard(for: liveCard.asAnyCard, height: cardHeight * 2) {
            Image(uiImage: rendered)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            // Fallback — just show the raw capture image
            if let image = liveCard.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }
    
    @ViewBuilder
    private var cardBackStatsView: some View {
        if let specs = liveCard.specs {
            RarityCardBackView(
                make: liveCard.make,
                model: liveCard.model,
                year: liveCard.year,
                specs: specs,
                rarity: specs.rarity ?? .common,
                customFrame: liveCard.customFrame,
                cardHeight: cardHeight,
                capturedBy: liveCard.capturedBy,
                capturedLocation: liveCard.capturedLocation,
                mintNumber: liveCard.mintNumber
            )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(white: 0.1))
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Loading specs...")
                        .font(.pCaption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
    
    // MARK: - Spin Logic
    
    private func startSpinning() {
        phase = .spinning
        spinAngle = 0
        spinSpeed = 3
        
        // Accelerating spin
        spinTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            DispatchQueue.main.async {
                spinAngle += spinSpeed
                
                // Accelerate over time
                if spinSpeed < 25 {
                    spinSpeed += 0.15
                }
                
                // Once we've done enough spins AND specs are ready, trigger poof
                if spinAngle > 720 && specsReady && spinSpeed >= 15 {
                    triggerPoof()
                }
                
                // Safety: if spinning too long without specs, poof anyway
                if spinAngle > 2160 {
                    triggerPoof()
                }
            }
        }
        
        // Haptic during spin — escalating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.6)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.8)
        }
    }
    
    private func triggerPoof() {
        spinTimer?.invalidate()
        spinTimer = nil
        
        phase = .poof
        showPoof = true
        presentationScale = 0.5
        
        // Sound
        RarityRevealSoundManager.shared.playRevealSound(for: rarity)
        
        // Big impact haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        }
        
        // Card scales up from poof center
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            presentationScale = 1.0
        }
        
        // Transition to presentation after poof settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = .presenting
            }
        }
    }
}

// MARK: - Rarity Poof Burst

struct RevealPoofBurst: View {
    let rarity: CardRarity
    
    @State private var particles: [PoofParticle] = []
    @State private var spawned = false
    
    struct PoofParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var targetX: CGFloat
        var targetY: CGFloat
        var size: CGFloat
        var opacity: Double
        var isGlow: Bool
    }
    
    private var count: Int {
        switch rarity {
        case .common: return 20
        case .uncommon: return 30
        case .rare: return 45
        case .epic: return 60
        case .legendary: return 80
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for p in particles {
                    let rect = CGRect(
                        x: p.x - p.size / 2,
                        y: p.y - p.size / 2,
                        width: p.size,
                        height: p.size
                    )
                    context.opacity = p.opacity
                    
                    if p.isGlow {
                        // Soft glow circles
                        context.fill(
                            Circle().path(in: rect.insetBy(dx: -2, dy: -2)),
                            with: .color(rarity.color.opacity(0.3))
                        )
                    }
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(p.isGlow ? .white : rarity.color)
                    )
                }
            }
            .onAppear {
                guard !spawned else { return }
                spawned = true
                
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.43)
                
                particles = (0..<count).map { _ in
                    let angle = CGFloat.random(in: 0...(2 * .pi))
                    let dist = CGFloat.random(in: 60...300)
                    return PoofParticle(
                        x: center.x + CGFloat.random(in: -20...20),
                        y: center.y + CGFloat.random(in: -15...15),
                        targetX: center.x + cos(angle) * dist,
                        targetY: center.y + sin(angle) * dist,
                        size: CGFloat.random(in: 3...9),
                        opacity: 1.0,
                        isGlow: Double.random(in: 0...1) < 0.3
                    )
                }
                
                // Burst outward
                withAnimation(.easeOut(duration: 0.6)) {
                    particles = particles.map { p in
                        var u = p; u.x = p.targetX; u.y = p.targetY; return u
                    }
                }
                
                // Fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        particles = particles.map { p in
                            var u = p; u.opacity = 0; return u
                        }
                    }
                }
            }
        }
    }
}
