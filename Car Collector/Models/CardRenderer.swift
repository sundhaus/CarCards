//
//  CardRenderer.swift
//  Car Collector
//
//  Renders card composites (image + border + text) into flat UIImages.
//  Used everywhere cards are displayed so we render once and reuse.
//

import UIKit
import SwiftUI

@MainActor
final class CardRenderer {
    static let shared = CardRenderer()
    
    // Cache: card UUID -> rendered landscape image
    private var landscapeCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 80 * 1024 * 1024 // 80MB
        return cache
    }()
    
    // Cache: card UUID -> rendered portrait image (driver cards only)
    private var portraitCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 40 * 1024 * 1024 // 40MB
        return cache
    }()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get a flattened landscape card image (all card types).
    /// This is the standard display format with border + text baked in.
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
    
    /// Get a flattened portrait card image (driver cards rotated 90°).
    /// Renders image+border in landscape, rotates, then draws text in portrait.
    /// Returns nil for non-driver cards.
    func portraitCard(for card: AnyCard, width: CGFloat = 300) -> UIImage? {
        guard case .driver(let dc) = card, !dc.isDriverPlusVehicle else { return nil }
        
        let rarityKey = card.rarity?.rawValue ?? "none"
        let frameKey = card.customFrame ?? "noframe"
        let key = "\(card.id.uuidString)-P-\(Int(width))-\(rarityKey)-\(frameKey)" as NSString
        if let cached = portraitCache.object(forKey: key) {
            return cached
        }
        
        guard card.thumbnail ?? card.image != nil else { return nil }
        
        // Use CardFlattener to get the canonical flat image, then resize
        guard let fullImage = CardFlattener.shared.flatten(card) else { return nil }
        
        // Scale down to requested width
        let aspectRatio = fullImage.size.height / fullImage.size.width
        let targetSize = CGSize(width: width, height: width * aspectRatio)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            fullImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        portraitCache.setObject(resized, forKey: key)
        return resized
    }
    
    /// Clear all caches
    func clearCache() {
        landscapeCache.removeAllObjects()
        portraitCache.removeAllObjects()
    }
    
    /// Clear cache for a specific card (clears entire cache since keys include rarity/frame variants)
    func clearCache(for cardId: UUID) {
        // NSCache doesn't support prefix removal or enumeration.
        // Since rarity/frame are part of the key, we must clear everything
        // to guarantee stale entries are removed.
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
            
            // Draw background gradient
            let colors = [
                UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1.0).cgColor,
                UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            
            // Draw source image (aspect fill)
            let imageRect = aspectFillRect(imageSize: sourceImage.size, targetRect: rect)
            sourceImage.draw(in: imageRect)
            
            // Draw border overlay
            let config = CardBorderConfig.forFrame(card.customFrame, rarity: card.rarity)
            if let borderName = config.borderImageName, let borderImage = UIImage(named: borderName) {
                borderImage.draw(in: rect)
            }
            
            // Draw text
            drawCardText(card: card, config: config, in: rect, height: height)
        }
    }
    
    private func drawCardText(card: AnyCard, config: CardBorderConfig, in rect: CGRect, height: CGFloat) {
        let textColor = uiColorFromSwiftUIColor(config.textColor)
        let shadowColor = UIColor.black.withAlphaComponent(0.8)
        let inset = height * 0.08
        
        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowBlurRadius = config.textShadow.radius
        shadow.shadowOffset = CGSize(width: config.textShadow.x, height: config.textShadow.y)
        
        switch card {
        case .driver(let dc):
            // Stacked: firstName (bold), nickname (light italic), lastName (bold)
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
            
            // First name (light weight to match garage)
            let firstName = dc.firstName.uppercased() as NSString
            firstName.draw(at: CGPoint(x: inset, y: yOffset), withAttributes: lightAttrs)
            yOffset += firstName.size(withAttributes: lightAttrs).height + 1
            
            // Nickname
            if !dc.nickname.isEmpty {
                let nickname = "\"\(dc.nickname.uppercased())\"" as NSString
                nickname.draw(at: CGPoint(x: inset, y: yOffset), withAttributes: nickAttrs)
                yOffset += nickname.size(withAttributes: nickAttrs).height + 1
            }
            
            // Last name
            let lastName = dc.lastName.uppercased() as NSString
            lastName.draw(at: CGPoint(x: inset, y: yOffset), withAttributes: boldAttrs)
            
        case .vehicle(let vc):
            // Horizontal: make (light) + model (bold)
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
            // Location name (bold)
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
