//
//  UnifiedCardEffects.swift
//  Car Collector
//
//  ZERO-CPU card effects overlay.
//
//  All effects are either static (rendered once) or touch-driven
//  (only costs CPU when user is actively dragging). No gyroscope,
//  no timers, no continuous animations on the card surface.
//
//  Border animations (shimmer rotation, glow pulse) use SwiftUI's
//  built-in animation system which runs on the render server thread
//  and costs negligible CPU.
//

import SwiftUI

// MARK: - Unified Full-Screen Effect Overlay

struct UnifiedCardEffectOverlay: View {
    let rarity: CardRarity
    let cardSize: CGSize
    let cornerRadius: CGFloat
    let holoEffect: String?
    
    // Touch-driven prismatic scroll
    @Binding var prismaticOffset: CGFloat
    
    private var holoPatternAsset: String? {
        guard let effectStr = holoEffect else { return nil }
        return HoloEffectType(rawValue: effectStr)?.assetName
    }
    
    var body: some View {
        ZStack {
            // STATIC VIGNETTE: Rendered once, zero per-frame cost.
            if rarity >= .epic {
                StaticVignette(cardSize: cardSize, cornerRadius: cornerRadius)
            }
            
            // HOLO EFFECTS: Pattern base + prismatic rainbow (touch-driven)
            if let asset = holoPatternAsset {
                // Base pattern (static)
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .clipped()
                    .blendMode(.screen)
                    .opacity(0.15)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .allowsHitTesting(false)
                
                // Prismatic rainbow — driven by external binding (touch or gyro)
                PrismaticRainbowLayer(
                    cardSize: cardSize,
                    cornerRadius: cornerRadius,
                    patternAsset: asset,
                    scrollOffset: prismaticOffset
                )
            }
            
            // OUTER EFFECTS: Border glow/shimmer (SwiftUI animation = render server, not CPU)
            OuterEffectsLayer(
                rarity: rarity,
                cornerRadius: cornerRadius
            )
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Static Vignette

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

// MARK: - Prismatic Rainbow Layer (driven by external offset, no gyro)

private struct PrismaticRainbowLayer: View {
    let cardSize: CGSize
    let cornerRadius: CGFloat
    let patternAsset: String
    let scrollOffset: CGFloat  // Normalized -2…2, driven externally
    
    var body: some View {
        let w = cardSize.width
        let h = cardSize.height
        let imgWidth = w * 5.0
        let maxScroll = imgWidth - w
        let pixelOffset = scrollOffset * w
        let clampedOffset = max(-maxScroll / 2, min(maxScroll / 2, pixelOffset))
        
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
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .allowsHitTesting(false)
    }
}

// MARK: - Outer Effects Layer

private struct OuterEffectsLayer: View {
    let rarity: CardRarity
    let cornerRadius: CGFloat
    
    @State private var borderPhase: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0.2
    
    var body: some View {
        ZStack {
            if rarity == .legendary {
                // Glow pulse (SwiftUI animation = render server, negligible CPU)
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

// MARK: - View Modifier (manages touch gesture + prismatic state)

struct UnifiedCardEffectModifier: ViewModifier {
    let rarity: CardRarity?
    let holoEffect: String?
    
    @State private var prismaticOffset: CGFloat = 0
    @State private var dragStart: CGFloat = 0
    
    func body(content: Content) -> some View {
        if let rarity = rarity, rarity >= .rare || holoEffect != nil {
            content
                .overlay {
                    GeometryReader { geo in
                        UnifiedCardEffectOverlay(
                            rarity: rarity,
                            cardSize: geo.size,
                            cornerRadius: geo.size.height * 0.09,
                            holoEffect: holoEffect,
                            prismaticOffset: $prismaticOffset
                        )
                    }
                }
                // Touch-driven prismatic scroll: drag across card to shift rainbow
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dragDistance = value.translation.width + value.translation.height
                            prismaticOffset = dragStart + dragDistance / 150.0
                        }
                        .onEnded { _ in
                            dragStart = prismaticOffset
                        }
                )
        } else if holoEffect != nil {
            content
                .overlay {
                    GeometryReader { geo in
                        UnifiedCardEffectOverlay(
                            rarity: .common,
                            cardSize: geo.size,
                            cornerRadius: geo.size.height * 0.09,
                            holoEffect: holoEffect,
                            prismaticOffset: $prismaticOffset
                        )
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dragDistance = value.translation.width + value.translation.height
                            prismaticOffset = dragStart + dragDistance / 150.0
                        }
                        .onEnded { _ in
                            dragStart = prismaticOffset
                        }
                )
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
