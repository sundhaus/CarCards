//
//  CardRenderer.swift
//  Car Collector
//
//  Renders card composites (image + border + text) into flat UIImages.
//  Used everywhere cards are displayed so we render once and reuse.
//
//  Rarity borders are drawn programmatically with a brushed-metal aesthetic.
//  Non-rarity borders (driver/location placeholder) still use PNG overlays.
//

import UIKit
import SwiftUI

// MARK: - Rarity Border Color Palette

struct RarityBorderPalette {
    let primary: UIColor      // Main border body
    let secondary: UIColor    // Gradient mid-tone
    let highlight: UIColor    // Bright edge / accent
    let inner: UIColor        // Dark edge
    let glow: UIColor         // Outer glow color
    let tierIndex: Int        // 0-4, drives progressive effects
    
    // Progressive feature flags
    var hasInnerGlow: Bool     { tierIndex >= 1 }
    var hasCornerAccents: Bool { tierIndex >= 2 }
    var hasPinstripe: Bool     { tierIndex >= 3 }
    var hasShimmerStreak: Bool { tierIndex >= 4 }
    
    static func forRarity(_ rarity: CardRarity) -> RarityBorderPalette {
        switch rarity {
        case .common:
            return RarityBorderPalette(
                primary:   UIColor(red: 0.54, green: 0.55, blue: 0.58, alpha: 1),
                secondary: UIColor(red: 0.69, green: 0.70, blue: 0.72, alpha: 1),
                highlight: UIColor(red: 0.83, green: 0.84, blue: 0.85, alpha: 1),
                inner:     UIColor(red: 0.42, green: 0.43, blue: 0.45, alpha: 1),
                glow:      UIColor(red: 0.69, green: 0.70, blue: 0.72, alpha: 0.3),
                tierIndex: 0
            )
        case .uncommon:
            return RarityBorderPalette(
                primary:   UIColor(red: 0.18, green: 0.55, blue: 0.31, alpha: 1),
                secondary: UIColor(red: 0.24, green: 0.69, blue: 0.39, alpha: 1),
                highlight: UIColor(red: 0.50, green: 0.85, blue: 0.60, alpha: 1),
                inner:     UIColor(red: 0.12, green: 0.42, blue: 0.22, alpha: 1),
                glow:      UIColor(red: 0.24, green: 0.69, blue: 0.39, alpha: 0.35),
                tierIndex: 1
            )
        case .rare:
            return RarityBorderPalette(
                primary:   UIColor(red: 0.12, green: 0.37, blue: 0.69, alpha: 1),
                secondary: UIColor(red: 0.23, green: 0.51, blue: 0.84, alpha: 1),
                highlight: UIColor(red: 0.48, green: 0.71, blue: 0.94, alpha: 1),
                inner:     UIColor(red: 0.08, green: 0.25, blue: 0.48, alpha: 1),
                glow:      UIColor(red: 0.23, green: 0.51, blue: 0.84, alpha: 0.4),
                tierIndex: 2
            )
        case .epic:
            return RarityBorderPalette(
                primary:   UIColor(red: 0.48, green: 0.18, blue: 0.71, alpha: 1),
                secondary: UIColor(red: 0.61, green: 0.31, blue: 0.84, alpha: 1),
                highlight: UIColor(red: 0.79, green: 0.54, blue: 0.94, alpha: 1),
                inner:     UIColor(red: 0.35, green: 0.12, blue: 0.54, alpha: 1),
                glow:      UIColor(red: 0.61, green: 0.31, blue: 0.84, alpha: 0.45),
                tierIndex: 3
            )
        case .legendary:
            return RarityBorderPalette(
                primary:   UIColor(red: 0.72, green: 0.53, blue: 0.04, alpha: 1),
                secondary: UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1),
                highlight: UIColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1),
                inner:     UIColor(red: 0.55, green: 0.40, blue: 0.03, alpha: 1),
                glow:      UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 0.5),
                tierIndex: 4
            )
        }
    }
}

// MARK: - Card Renderer

@MainActor
final class CardRenderer {
    static let shared = CardRenderer()
    
    private var landscapeCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()
    
    private var portraitCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 40 * 1024 * 1024
        return cache
    }()
    
    private init() {}
    
    // MARK: - Public API
    
    func landscapeCard(for card: AnyCard, height: CGFloat = 400) -> UIImage? {
        let rarityKey = card.rarity?.rawValue ?? "none"
        let frameKey = card.customFrame ?? "noframe"
        let key = "\(card.id.uuidString)-L-\(Int(height))-\(rarityKey)-\(frameKey)" as NSString
        if let cached = landscapeCache.object(forKey: key) {
            return cached
        }
        
        guard let sourceImage = card.thumbnail ?? card.image else { return nil }
        
        let rendered = renderLandscape(card: card, sourceImage: sourceImage, height: height)
        if let rendered {
            landscapeCache.setObject(rendered, forKey: key)
        }
        return rendered
    }
    
    func portraitCard(for card: AnyCard, width: CGFloat = 300) -> UIImage? {
        guard case .driver(let dc) = card, !dc.isDriverPlusVehicle else { return nil }
        
        let rarityKey = card.rarity?.rawValue ?? "none"
        let frameKey = card.customFrame ?? "noframe"
        let key = "\(card.id.uuidString)-P-\(Int(width))-\(rarityKey)-\(frameKey)" as NSString
        if let cached = portraitCache.object(forKey: key) {
            return cached
        }
        
        guard card.thumbnail ?? card.image != nil else { return nil }
        guard let fullImage = CardFlattener.shared.flatten(card) else { return nil }
        
        let aspectRatio = fullImage.size.height / fullImage.size.width
        let targetSize = CGSize(width: width, height: width * aspectRatio)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            fullImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        portraitCache.setObject(resized, forKey: key)
        return resized
    }
    
    func clearCache() {
        landscapeCache.removeAllObjects()
        portraitCache.removeAllObjects()
    }
    
    func clearCache(for cardId: UUID) {
        landscapeCache.removeAllObjects()
        portraitCache.removeAllObjects()
    }
    
    // MARK: - Rendering
    
    private func renderLandscape(card: AnyCard, sourceImage: UIImage, height: CGFloat) -> UIImage? {
        let width = height * 16.0 / 9.0
        let size = CGSize(width: width, height: height)
        let cornerRadius = height * 0.09
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let context = ctx.cgContext
            
            // Clip to rounded rect
            let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.addPath(clipPath.cgPath)
            context.clip()
            
            // Background gradient (visible if image doesn't fully cover)
            let bgColors = [
                UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1.0).cgColor,
                UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors as CFArray, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            
            // Source image (aspect fill)
            let imageRect = aspectFillRect(imageSize: sourceImage.size, targetRect: rect)
            sourceImage.draw(in: imageRect)
            
            // Border — full-bleed for Epic+, brushed-metal for lower tiers
            let config = CardBorderConfig.forFrame(card.customFrame, rarity: card.rarity)
            
            if let rarity = card.rarity {
                if rarity.hasFullBleedArt {
                    // Epic+ : No border frame — edge-to-edge art with subtle vignette
                    drawFullBleedOverlay(context: context, rect: rect, cornerRadius: cornerRadius, rarity: rarity)
                } else {
                    // Common/Uncommon/Rare: Programmatic brushed-metal border
                    let palette = RarityBorderPalette.forRarity(rarity)
                    drawBrushedMetalBorder(context: context, rect: rect, cornerRadius: cornerRadius, height: height, palette: palette)
                }
            } else if let borderName = config.borderImageName, let borderImage = UIImage(named: borderName) {
                // PNG fallback for non-rarity cards
                let borderInset: CGFloat = -3
                let borderRect = rect.insetBy(dx: borderInset, dy: borderInset)
                borderImage.draw(in: borderRect)
            }
            
            // Text
            drawCardText(card: card, config: config, in: rect, height: height)
        }
    }
    
    // MARK: - Full-Bleed Art Overlay (Epic+)
    
    /// Edge-to-edge card treatment for Epic and Legendary.
    /// Instead of a thick border, uses:
    ///   1. A subtle darkened vignette around the edges
    ///   2. A thin 1.5pt rarity-colored accent line at the card edge
    ///   3. (Legendary) A faint gold inner-glow to hint at the shimmer
    private func drawFullBleedOverlay(context: CGContext, rect: CGRect, cornerRadius: CGFloat, rarity: CardRarity) {
        let palette = RarityBorderPalette.forRarity(rarity)
        
        // --- 1. Edge vignette (dark fade from edges inward) ---
        context.saveGState()
        let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.addPath(clipPath.cgPath)
        context.clip()
        
        // Radial gradient from center (clear) to edges (dark)
        let vignetteColors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.15).cgColor,
            UIColor.black.withAlphaComponent(0.45).cgColor
        ] as CFArray
        let vignetteLocs: [CGFloat] = [0.0, 0.55, 0.85, 1.0]
        
        if let vignetteGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: vignetteColors, locations: vignetteLocs) {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let maxRadius = sqrt(pow(rect.width / 2, 2) + pow(rect.height / 2, 2))
            context.drawRadialGradient(vignetteGrad, startCenter: center, startRadius: 0, endCenter: center, endRadius: maxRadius, options: [])
        }
        context.restoreGState()
        
        // --- 2. Thin rarity accent stroke at card edge ---
        context.saveGState()
        let strokeInset: CGFloat = 1.0
        let strokeRect = rect.insetBy(dx: strokeInset, dy: strokeInset)
        let strokePath = UIBezierPath(roundedRect: strokeRect, cornerRadius: cornerRadius - strokeInset)
        
        context.setStrokeColor(palette.highlight.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.5)
        context.addPath(strokePath.cgPath)
        context.strokePath()
        context.restoreGState()
        
        // --- 3. Legendary inner glow ---
        if rarity == .legendary {
            context.saveGState()
            let glowInset: CGFloat = 3.0
            let glowRect = rect.insetBy(dx: glowInset, dy: glowInset)
            let glowPath = UIBezierPath(roundedRect: glowRect, cornerRadius: cornerRadius - glowInset)
            
            context.setShadow(offset: .zero, blur: 8, color: palette.glow.cgColor)
            context.setStrokeColor(palette.glow.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(2.0)
            context.addPath(glowPath.cgPath)
            context.strokePath()
            context.restoreGState()
        }
    }
    
    // MARK: - Brushed Metal Border
    
    private func drawBrushedMetalBorder(context: CGContext, rect: CGRect, cornerRadius: CGFloat, height: CGFloat, palette: RarityBorderPalette) {
        let borderWidth = height * 0.042
        let innerRect = rect.insetBy(dx: borderWidth, dy: borderWidth)
        let innerCornerRadius = max(cornerRadius * 0.6, 2)
        
        let outerPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: innerCornerRadius)
        
        // --- 1. Main diagonal gradient fill ---
        context.saveGState()
        context.addPath(outerPath.cgPath)
        context.addPath(innerPath.reversing().cgPath)
        context.clip(using: .evenOdd)
        
        let gradientColors = [
            palette.highlight.cgColor,
            palette.primary.cgColor,
            palette.secondary.cgColor,
            palette.primary.cgColor,
            palette.inner.cgColor
        ] as CFArray
        let gradientLocs: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: gradientLocs) {
            let startPt = CGPoint(x: rect.minX, y: rect.minY)
            let endPt = CGPoint(x: rect.maxX * 0.85, y: rect.maxY)
            context.drawLinearGradient(gradient, start: startPt, end: endPt, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        context.restoreGState()
        
        // --- 2. Brushed metal horizontal lines ---
        context.saveGState()
        context.addPath(outerPath.cgPath)
        context.addPath(innerPath.reversing().cgPath)
        context.clip(using: .evenOdd)
        
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.07).cgColor)
        context.setLineWidth(0.5)
        var y = rect.minY
        while y < rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += 3.0
        }
        context.strokePath()
        context.restoreGState()
        
        // --- 3. Top highlight / bottom shadow (vertical bevel) ---
        context.saveGState()
        context.addPath(outerPath.cgPath)
        context.addPath(innerPath.reversing().cgPath)
        context.clip(using: .evenOdd)
        
        let bevelColors = [
            palette.highlight.withAlphaComponent(0.35).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            palette.inner.withAlphaComponent(0.3).cgColor
        ] as CFArray
        let bevelLocs: [CGFloat] = [0.0, 0.4, 0.85, 1.0]
        
        if let bevel = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bevelColors, locations: bevelLocs) {
            context.drawLinearGradient(bevel, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.minX, y: rect.maxY), options: [])
        }
        context.restoreGState()
        
        // --- 4. Dark outer edge ---
        context.saveGState()
        let outerEdgeRect = rect.insetBy(dx: 0.75, dy: 0.75)
        let outerEdgePath = UIBezierPath(roundedRect: outerEdgeRect, cornerRadius: cornerRadius - 0.75)
        context.setStrokeColor(palette.inner.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.5)
        context.addPath(outerEdgePath.cgPath)
        context.strokePath()
        context.restoreGState()
        
        // --- 5. Inner glow along photo edge (uncommon+) ---
        if palette.hasInnerGlow {
            context.saveGState()
            let glowClip = UIBezierPath(roundedRect: innerRect.insetBy(dx: -1, dy: -1), cornerRadius: innerCornerRadius)
            context.addPath(glowClip.cgPath)
            context.clip()
            
            context.setShadow(offset: .zero, blur: borderWidth * 1.2, color: palette.glow.cgColor)
            context.setStrokeColor(palette.glow.cgColor)
            context.setLineWidth(2)
            
            let strokeRect = innerRect.insetBy(dx: -borderWidth * 0.5, dy: -borderWidth * 0.5)
            let strokePath = UIBezierPath(roundedRect: strokeRect, cornerRadius: innerCornerRadius + borderWidth * 0.5)
            context.addPath(strokePath.cgPath)
            context.strokePath()
            context.restoreGState()
        }
        
        // --- 6. Inner pinstripe (epic+) ---
        if palette.hasPinstripe {
            context.saveGState()
            let pinRect = innerRect.insetBy(dx: -2, dy: -2)
            let pinPath = UIBezierPath(roundedRect: pinRect, cornerRadius: innerCornerRadius + 1)
            context.setStrokeColor(palette.highlight.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(1.0)
            context.addPath(pinPath.cgPath)
            context.strokePath()
            context.restoreGState()
        }
        
        // --- 7. Corner accent diamonds (rare+) ---
        if palette.hasCornerAccents {
            let diamondSize: CGFloat = 4.0
            let offset: CGFloat = borderWidth * 0.5
            let corners = [
                CGPoint(x: rect.minX + offset, y: rect.minY + offset),
                CGPoint(x: rect.maxX - offset, y: rect.minY + offset),
                CGPoint(x: rect.maxX - offset, y: rect.maxY - offset),
                CGPoint(x: rect.minX + offset, y: rect.maxY - offset)
            ]
            
            for center in corners {
                context.saveGState()
                let dp = UIBezierPath()
                dp.move(to: CGPoint(x: center.x, y: center.y - diamondSize))
                dp.addLine(to: CGPoint(x: center.x + diamondSize, y: center.y))
                dp.addLine(to: CGPoint(x: center.x, y: center.y + diamondSize))
                dp.addLine(to: CGPoint(x: center.x - diamondSize, y: center.y))
                dp.close()
                
                context.setShadow(offset: .zero, blur: 3, color: palette.glow.cgColor)
                context.setFillColor(palette.highlight.withAlphaComponent(0.7).cgColor)
                context.addPath(dp.cgPath)
                context.fillPath()
                context.restoreGState()
            }
        }
        
        // --- 8. Shimmer streak (legendary) — static diagonal bright band ---
        if palette.hasShimmerStreak {
            context.saveGState()
            context.addPath(outerPath.cgPath)
            context.addPath(innerPath.reversing().cgPath)
            context.clip(using: .evenOdd)
            
            let streakWidth: CGFloat = rect.width * 0.12
            let streakCenter = rect.width * 0.35
            
            let streakColors = [
                UIColor.clear.cgColor,
                palette.highlight.withAlphaComponent(0.25).cgColor,
                palette.highlight.withAlphaComponent(0.5).cgColor,
                palette.highlight.withAlphaComponent(0.25).cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            let streakLocs: [CGFloat] = [0.0, 0.35, 0.5, 0.65, 1.0]
            
            if let streakGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: streakColors, locations: streakLocs) {
                context.saveGState()
                context.translateBy(x: rect.midX, y: rect.midY)
                context.rotate(by: .pi * 0.18)
                context.translateBy(x: -rect.midX, y: -rect.midY)
                
                context.drawLinearGradient(streakGrad,
                    start: CGPoint(x: streakCenter - streakWidth, y: rect.minY),
                    end: CGPoint(x: streakCenter + streakWidth, y: rect.minY),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                context.restoreGState()
            }
            context.restoreGState()
        }
    }
    
    // MARK: - Text Drawing
    
    private func drawCardText(card: AnyCard, config: CardBorderConfig, in rect: CGRect, height: CGFloat) {
        let textColor = uiColorFromSwiftUIColor(config.textColor)
        let shadowColor = UIColor.black.withAlphaComponent(0.8)
        let borderWidth = height * 0.042
        let inset = borderWidth + height * 0.03
        
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowBlurRadius = config.textShadow.radius
        shadow.shadowOffset = CGSize(width: config.textShadow.x, height: config.textShadow.y)
        
        switch card {
        case .driver(let dc):
            var yOffset = inset
            let boldSize = height * 0.09
            let nickSize = height * 0.06
            
            let boldAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Futura-Bold", size: boldSize) ?? UIFont.boldSystemFont(ofSize: boldSize),
                .foregroundColor: textColor,
                .shadow: shadow
            ]
            let lightAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Futura-Light", size: boldSize) ?? UIFont.systemFont(ofSize: boldSize),
                .foregroundColor: textColor,
                .shadow: shadow
            ]
            let nickAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Futura-Light", size: nickSize) ?? UIFont.systemFont(ofSize: nickSize),
                .foregroundColor: textColor.withAlphaComponent(0.8),
                .shadow: shadow
            ]
            
            let firstName = dc.firstName.uppercased() as NSString
            firstName.draw(at: CGPoint(x: inset, y: yOffset), withAttributes: lightAttrs)
            yOffset += firstName.size(withAttributes: lightAttrs).height + 1
            
            if !dc.nickname.isEmpty {
                let nickname = "\"\(dc.nickname.uppercased())\"" as NSString
                nickname.draw(at: CGPoint(x: inset, y: yOffset), withAttributes: nickAttrs)
                yOffset += nickname.size(withAttributes: nickAttrs).height + 1
            }
            
            let lastName = dc.lastName.uppercased() as NSString
            lastName.draw(at: CGPoint(x: inset, y: yOffset), withAttributes: boldAttrs)
            
        case .vehicle(let vc):
            let fontSize = height * 0.08
            let lightAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Futura-Light", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: textColor,
                .shadow: shadow
            ]
            let boldAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Futura-Bold", size: fontSize) ?? UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: textColor,
                .shadow: shadow
            ]
            
            let make = vc.make.uppercased() as NSString
            let makeSize = make.size(withAttributes: lightAttrs)
            make.draw(at: CGPoint(x: inset, y: inset), withAttributes: lightAttrs)
            
            if !vc.model.isEmpty {
                let model = vc.model.uppercased() as NSString
                model.draw(at: CGPoint(x: inset + makeSize.width + 6, y: inset), withAttributes: boldAttrs)
            }
            
        case .location(let lc):
            let fontSize = height * 0.08
            let boldAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Futura-Bold", size: fontSize) ?? UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: textColor,
                .shadow: shadow
            ]
            
            let name = lc.locationName.uppercased() as NSString
            name.draw(at: CGPoint(x: inset, y: inset), withAttributes: boldAttrs)
        }
    }
    
    // MARK: - Helpers
    
    private func aspectFillRect(imageSize: CGSize, targetRect: CGRect) -> CGRect {
        let widthRatio = targetRect.width / imageSize.width
        let heightRatio = targetRect.height / imageSize.height
        let scale = max(widthRatio, heightRatio)
        let newSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let x = (targetRect.width - newSize.width) / 2
        let y = (targetRect.height - newSize.height) / 2
        return CGRect(x: x, y: y, width: newSize.width, height: newSize.height)
    }
    
    private func rotateImage(_ image: UIImage, degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        let newSize = CGSize(width: image.size.height, height: image.size.width)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.rotate(by: radians)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                  width: image.size.width, height: image.size.height))
        }
    }
    
    private func uiColorFromSwiftUIColor(_ color: SwiftUI.Color) -> UIColor {
        return UIColor(color)
    }
}
