//
//  CardFlattener.swift
//  Car Collector
//
//  Renders the canonical "flat" card image that matches the fullscreen view.
//  This single image is used everywhere: garage grid, friends feed, marketplace, card options.
//
//  - Vehicle/Location: landscape 16:9 (1920×1080)
//  - Driver: portrait 9:16 (1080×1920) with text baked in
//
//  The original raw photo is kept for re-rendering when borders/frames change.
//

import SwiftUI
import UIKit
import FirebaseStorage

@MainActor
class CardFlattener {
    static let shared = CardFlattener()
    
    private let storage = FirebaseManager.shared.storage
    
    /// Standard render sizes
    private let landscapeSize = CGSize(width: 1920, height: 1080)
    private let portraitSize = CGSize(width: 1080, height: 1920)
    
    private init() {}
    
    // MARK: - Public API
    
    /// Flatten a card to a UIImage matching the fullscreen view
    func flatten(_ card: AnyCard) -> UIImage? {
        switch card {
        case .driver(let dc):
            return flattenDriver(dc, frame: card.customFrame)
        case .vehicle, .location:
            return flattenLandscape(card)
        }
    }
    
    /// Flatten + upload to Firebase Storage, returns download URL
    func flattenAndUpload(_ card: AnyCard) async throws -> String {
        guard let flatImage = flatten(card) else {
            throw FlattenError.renderFailed
        }
        
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FlattenError.notAuthenticated
        }
        
        guard let cardFirebaseId = card.firebaseId else {
            throw FlattenError.noFirebaseId
        }
        
        // Upload flat image
        let url = try await uploadFlatImage(flatImage, uid: uid, cardId: cardFirebaseId)
        
        // Update Firestore document with flatImageURL
        try await FirebaseManager.shared.db.collection("cards").document(cardFirebaseId).updateData([
            "flatImageURL": url
        ])
        
        print("✅ Flattened card uploaded: \(card.displayTitle)")
        return url
    }
    
    /// Re-flatten a card (e.g. after frame change) and replace old flat image
    func reflatten(_ card: AnyCard) async throws -> String {
        // Same as flattenAndUpload — overwrites the same Storage path
        return try await flattenAndUpload(card)
    }
    
    // MARK: - Migration (one-time for existing cards)
    
    /// Flatten all existing cards that don't have a flatImageURL yet
    func migrateExistingCards(vehicles: [SavedCard], drivers: [DriverCard], locations: [LocationCard]) async {
        let db = FirebaseManager.shared.db
        
        print("🔄 Starting flatten migration...")
        var count = 0
        
        // Vehicles
        for card in vehicles {
            guard let firebaseId = card.firebaseId else { continue }
            // Check if already has flatImageURL
            if let doc = try? await db.collection("cards").document(firebaseId).getDocument(),
               doc.data()?["flatImageURL"] != nil {
                continue
            }
            do {
                _ = try await flattenAndUpload(AnyCard.vehicle(card))
                count += 1
                print("🔄 Flattened vehicle \(count): \(card.make) \(card.model)")
            } catch {
                print("⚠️ Failed to flatten vehicle \(card.make) \(card.model): \(error)")
            }
        }
        
        // Drivers
        for card in drivers {
            guard let firebaseId = card.firebaseId else { continue }
            if let doc = try? await db.collection("cards").document(firebaseId).getDocument(),
               doc.data()?["flatImageURL"] != nil {
                continue
            }
            do {
                _ = try await flattenAndUpload(AnyCard.driver(card))
                count += 1
                print("🔄 Flattened driver \(count): \(card.firstName) \(card.lastName)")
            } catch {
                print("⚠️ Failed to flatten driver \(card.firstName): \(error)")
            }
        }
        
        // Locations
        for card in locations {
            guard let firebaseId = card.firebaseId else { continue }
            if let doc = try? await db.collection("cards").document(firebaseId).getDocument(),
               doc.data()?["flatImageURL"] != nil {
                continue
            }
            do {
                _ = try await flattenAndUpload(AnyCard.location(card))
                count += 1
                print("🔄 Flattened location \(count): \(card.locationName)")
            } catch {
                print("⚠️ Failed to flatten location \(card.locationName): \(error)")
            }
        }
        
        print("✅ Flatten migration complete: \(count) cards processed")
    }
    
    // MARK: - Landscape Rendering (Vehicle / Location)
    
    private func flattenLandscape(_ card: AnyCard) -> UIImage? {
        guard let sourceImage = card.image ?? card.thumbnail else { return nil }
        
        let size = landscapeSize
        let cardHeight = size.height
        let cornerRadius = cardHeight * 0.09
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let context = ctx.cgContext
            
            // Clip to rounded rect
            let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.addPath(clipPath.cgPath)
            context.clip()
            
            // Background gradient
            let colors = [
                UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1.0).cgColor,
                UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            
            // Source image (aspect fill)
            let imageRect = aspectFillRect(imageSize: sourceImage.size, targetRect: rect)
            sourceImage.draw(in: imageRect)
            
            // Border overlay
            let config = CardBorderConfig.forFrame(card.customFrame)
            if let borderName = config.borderImageName, let borderImage = UIImage(named: borderName) {
                borderImage.draw(in: rect)
            }
            
            // Text overlay — matches AnyCardDetailsFrontView exactly
            let shadow = NSShadow()
            shadow.shadowColor = UIColor(config.textShadow.color)
            shadow.shadowBlurRadius = config.textShadow.radius
            shadow.shadowOffset = CGSize(width: config.textShadow.x, height: config.textShadow.y)
            
            let textColor = UIColor(config.textColor)
            let fontSize = cardHeight * 0.08
            let textPadding = cardHeight * 0.08
            
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
            
            let line1 = card.titleLine1.uppercased() as NSString
            let line2 = card.titleLine2.uppercased() as NSString
            
            let line1Size = line1.size(withAttributes: lightAttrs)
            let line2Size = line2.size(withAttributes: boldAttrs)
            
            // Draw line1 + line2 side by side with 6pt spacing (matching SwiftUI HStack spacing: 6)
            let spacing: CGFloat = 6 * (size.width / 393) // Scale spacing
            var xOffset = textPadding
            let yOffset = textPadding
            
            line1.draw(at: CGPoint(x: xOffset, y: yOffset), withAttributes: lightAttrs)
            xOffset += line1Size.width + spacing
            
            if line2.length > 0 {
                line2.draw(at: CGPoint(x: xOffset, y: yOffset), withAttributes: boldAttrs)
            }
        }
    }
    
    // MARK: - Portrait Rendering (Driver)
    
    private func flattenDriver(_ dc: DriverCard, frame: String?) -> UIImage? {
        guard let sourceImage = dc.image ?? dc.thumbnail else { return nil }
        
        // Step 1: Render the card in landscape (image + border)
        let landscapeW = portraitSize.height  // 1920
        let landscapeH = portraitSize.width   // 1080
        let landscapeRect = CGRect(x: 0, y: 0, width: landscapeW, height: landscapeH)
        
        let landscapeRenderer = UIGraphicsImageRenderer(size: CGSize(width: landscapeW, height: landscapeH))
        let landscapeImage = landscapeRenderer.image { ctx in
            let context = ctx.cgContext
            
            // Background gradient
            let colors = [
                UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1.0).cgColor,
                UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: landscapeRect.height), options: [])
            }
            
            // Source image (aspect fill)
            let imageRect = aspectFillRect(imageSize: sourceImage.size, targetRect: landscapeRect)
            sourceImage.draw(in: imageRect)
            
            // Border overlay
            let config = CardBorderConfig.forFrame(frame)
            if let borderName = config.borderImageName, let borderImage = UIImage(named: borderName) {
                borderImage.draw(in: landscapeRect)
            }
        }
        
        // Step 2: Rotate 90° clockwise to portrait
        guard let rotated = rotateImage(landscapeImage, degrees: 90) else { return nil }
        
        // Step 3: Draw driver text overlay in portrait orientation
        // Matches UnifiedCardDetailView's driver overlay positioning
        let size = rotated.size  // 1080 × 1920
        let cornerRadius = size.width * 0.05
        
        let finalRenderer = UIGraphicsImageRenderer(size: size)
        return finalRenderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let context = ctx.cgContext
            
            // Clip to rounded rect
            let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.addPath(clipPath.cgPath)
            context.clip()
            
            // Draw rotated card
            rotated.draw(in: rect)
            
            // Match fullscreen overlay: 6% from left, 3% from top of portrait card
            let config = CardBorderConfig.forFrame(frame)
            let textColor = UIColor(config.textColor)
            
            let insetLeft = size.width * 0.06
            let insetTop = size.height * 0.03
            
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.8)
            shadow.shadowBlurRadius = 4 * (size.width / 375)
            shadow.shadowOffset = CGSize(width: 0, height: 2 * (size.width / 375))
            
            let nameSize = size.height * 0.041
            let nickSize = size.height * 0.026
            
            let lightAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Futura-Light", size: nameSize) ?? UIFont.systemFont(ofSize: nameSize),
                .foregroundColor: textColor,
                .shadow: shadow
            ]
            let boldAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Futura-Bold", size: nameSize) ?? UIFont.boldSystemFont(ofSize: nameSize),
                .foregroundColor: textColor,
                .shadow: shadow
            ]
            let nickAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Futura-Bold", size: nickSize) ?? UIFont.boldSystemFont(ofSize: nickSize),
                .foregroundColor: textColor.withAlphaComponent(0.8),
                .shadow: shadow
            ]
            
            var yOffset = insetTop
            
            // First name
            let firstName = dc.firstName.uppercased() as NSString
            firstName.draw(at: CGPoint(x: insetLeft, y: yOffset), withAttributes: lightAttrs)
            yOffset += firstName.size(withAttributes: lightAttrs).height + 2
            
            // Nickname
            if !dc.nickname.isEmpty {
                let nickname = "\"\(dc.nickname.uppercased())\"" as NSString
                nickname.draw(at: CGPoint(x: insetLeft, y: yOffset), withAttributes: nickAttrs)
                yOffset += nickname.size(withAttributes: nickAttrs).height + 2
            }
            
            // Last name
            let lastName = dc.lastName.uppercased() as NSString
            lastName.draw(at: CGPoint(x: insetLeft, y: yOffset), withAttributes: boldAttrs)
        }
    }
    
    // MARK: - Upload
    
    private func uploadFlatImage(_ image: UIImage, uid: String, cardId: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw FlattenError.renderFailed
        }
        
        let path = "cards/\(uid)/\(cardId)_flat.jpg"
        let ref = storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        
        print("✅ Uploaded flat card image: \(path) (\(data.count / 1024)KB)")
        return downloadURL.absoluteString
    }
    
    // MARK: - Helpers
    
    private func aspectFillRect(imageSize: CGSize, targetRect: CGRect) -> CGRect {
        let widthRatio = targetRect.width / imageSize.width
        let heightRatio = targetRect.height / imageSize.height
        let scale = max(widthRatio, heightRatio)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: targetRect.midX - scaledSize.width / 2,
            y: targetRect.midY - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
    
    private func rotateImage(_ image: UIImage, degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        let newSize = CGSize(width: image.size.height, height: image.size.width)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.rotate(by: radians)
            context.translateBy(x: -image.size.width / 2, y: -image.size.height / 2)
            image.draw(at: .zero)
        }
    }
    
    enum FlattenError: Error, LocalizedError {
        case renderFailed
        case notAuthenticated
        case noFirebaseId
        
        var errorDescription: String? {
            switch self {
            case .renderFailed: return "Failed to render card image"
            case .notAuthenticated: return "Not authenticated"
            case .noFirebaseId: return "Card has no Firebase ID"
            }
        }
    }
}
