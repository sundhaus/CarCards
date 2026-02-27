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
    
    var body: some View {
        ZStack {
            if rarity == .legendary {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.yellow.opacity(0.4), lineWidth: 4)
                
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(rarity.gradient, lineWidth: 1.5)
                    .padding(1)
            } else if rarity == .epic {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(rarity.gradient, lineWidth: 2.5)
            } else if rarity == .rare {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - View Modifier (single drag drives tilt + prismatic)

struct UnifiedCardEffectModifier: ViewModifier {
    let rarity: CardRarity?
    let holoEffect: String?
    
    // Prismatic rainbow scroll (persists between drags)
    @State private var prismaticOffset: CGFloat = 0
    @State private var prismaticDragStart: CGFloat = 0
    
    // Card tilt (springs back to zero on release)
    @State private var tiltX: Double = 0  // Pitch (forward/back)
    @State private var tiltY: Double = 0  // Roll (left/right)
    
    func body(content: Content) -> some View {
        let hasEffects = (rarity ?? .common) >= .rare || holoEffect != nil
        let effectRarity = rarity ?? .common
        
        if hasEffects {
            content
                .overlay {
                    GeometryReader { geo in
                        UnifiedCardEffectOverlay(
                            rarity: effectRarity,
                            cardSize: geo.size,
                            cornerRadius: geo.size.height * 0.09,
                            holoEffect: holoEffect,
                            prismaticOffset: $prismaticOffset
                        )
                    }
                }
                // 3D tilt from drag
                .rotation3DEffect(
                    .degrees(tiltX),
                    axis: (x: -1, y: 0, z: 0),
                    perspective: 0.5
                )
                .rotation3DEffect(
                    .degrees(tiltY),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                // Single drag gesture drives everything
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            
                            // Prismatic scroll: both axes contribute
                            prismaticOffset = prismaticDragStart + (dx + dy) / 150.0
                            
                            // Card tilt: map drag to rotation degrees
                            let maxTilt: Double = 12.0
                            withAnimation(.interactiveSpring(response: 0.1)) {
                                tiltY = max(-maxTilt, min(maxTilt, Double(dx) / 12.0))
                                tiltX = max(-maxTilt, min(maxTilt, Double(dy) / 12.0))
                            }
                        }
                        .onEnded { _ in
                            prismaticDragStart = prismaticOffset
                            
                            // Spring back to flat
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                tiltX = 0
                                tiltY = 0
                            }
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
