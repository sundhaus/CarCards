//
//  CardFlattener.swift
//  Car Collector
//
//  Renders the canonical "flat" card image by snapshotting the actual SwiftUI views.
//  Uses ImageRenderer (iOS 16+) so output is pixel-identical to fullscreen.
//
//  - Vehicle/Location: landscape 16:9 with text baked in
//  - Driver: portrait 9:16 — landscape card rotated + text overlay (matches fullscreen exactly)
//

import SwiftUI
import UIKit
import FirebaseStorage

// MARK: - Flattened Card Views (used only for rendering to image)

/// Portrait driver card — replicates the exact fullscreen composition
struct FlatDriverCardView: View {
    let card: AnyCard
    let driverCard: DriverCard
    let renderWidth: CGFloat
    
    var body: some View {
        let renderHeight = renderWidth * (16.0 / 9.0)
        // Landscape card dimensions (before rotation)
        let landscapeW = renderHeight
        let landscapeH = landscapeW / 16 * 9
        // After rotation: portrait dimensions
        let portraitW = landscapeH  // = renderWidth
        let portraitH = landscapeW  // = renderHeight
        
        ZStack {
            // Landscape card rotated to portrait
            AnyCardDetailsFrontView(card: card)
                .frame(width: landscapeW, height: landscapeH)
                .rotationEffect(.degrees(90))
            
            // Driver text overlay — IDENTICAL math to UnifiedCardDetailView
            let config = CardBorderConfig.forFrame(card.customFrame)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(driverCard.firstName.uppercased())
                    .font(.custom("Futura-Light", fixedSize: portraitH * 0.035))
                
                if !driverCard.nickname.isEmpty {
                    Text("\"\(driverCard.nickname.uppercased())\"")
                        .font(.custom("Futura-Bold", fixedSize: portraitH * 0.022))
                        .opacity(0.8)
                }
                
                Text(driverCard.lastName.uppercased())
                    .font(.custom("Futura-Bold", fixedSize: portraitH * 0.035))
            }
            .foregroundStyle(config.textColor)
            .shadow(color: .black, radius: 4, x: 0, y: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(width: portraitW, height: portraitH)
            .padding(.top, portraitH * 0.04)
            .padding(.leading, portraitW * 0.18)
        }
        .frame(width: renderWidth, height: renderHeight)
        .clipped()
    }
}

/// Landscape vehicle/location card
struct FlatLandscapeCardView: View {
    let card: AnyCard
    let renderWidth: CGFloat
    
    var body: some View {
        let renderHeight = renderWidth / (16.0 / 9.0)
        
        AnyCardDetailsFrontView(card: card)
            .frame(width: renderWidth, height: renderHeight)
    }
}

// MARK: - CardFlattener

@MainActor
class CardFlattener {
    static let shared = CardFlattener()
    
    private let storage = FirebaseManager.shared.storage
    
    private init() {}
    
    // MARK: - Public API
    
    /// Flatten a card to a UIImage by snapshotting the SwiftUI view
    func flatten(_ card: AnyCard) -> UIImage? {
        switch card {
        case .driver(let dc):
            return renderDriverCard(card: card, driverCard: dc)
        case .vehicle, .location:
            return renderLandscapeCard(card: card)
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
        
        let url = try await uploadFlatImage(flatImage, uid: uid, cardId: cardFirebaseId)
        
        try await FirebaseManager.shared.db.collection("cards").document(cardFirebaseId).updateData([
            "flatImageURL": url
        ])
        
        print("✅ Flattened card uploaded: \(card.displayTitle)")
        return url
    }
    
    /// Re-flatten after frame/border change
    func reflatten(_ card: AnyCard) async throws -> String {
        return try await flattenAndUpload(card)
    }
    
    // MARK: - Migration
    
    func migrateExistingCards(vehicles: [SavedCard], drivers: [DriverCard], locations: [LocationCard]) async {
        let db = FirebaseManager.shared.db
        print("🔄 Starting flatten migration...")
        var count = 0
        
        for card in vehicles {
            guard let fid = card.firebaseId else { continue }
            if let doc = try? await db.collection("cards").document(fid).getDocument(),
               doc.data()?["flatImageURL"] != nil { continue }
            do {
                _ = try await flattenAndUpload(AnyCard.vehicle(card))
                count += 1
            } catch { print("⚠️ Flatten vehicle failed: \(error)") }
        }
        
        for card in drivers {
            guard let fid = card.firebaseId else { continue }
            if let doc = try? await db.collection("cards").document(fid).getDocument(),
               doc.data()?["flatImageURL"] != nil { continue }
            do {
                _ = try await flattenAndUpload(AnyCard.driver(card))
                count += 1
            } catch { print("⚠️ Flatten driver failed: \(error)") }
        }
        
        for card in locations {
            guard let fid = card.firebaseId else { continue }
            if let doc = try? await db.collection("cards").document(fid).getDocument(),
               doc.data()?["flatImageURL"] != nil { continue }
            do {
                _ = try await flattenAndUpload(AnyCard.location(card))
                count += 1
            } catch { print("⚠️ Flatten location failed: \(error)") }
        }
        
        print("✅ Flatten migration complete: \(count) cards")
    }
    
    // MARK: - SwiftUI → UIImage
    
    private func renderDriverCard(card: AnyCard, driverCard: DriverCard) -> UIImage? {
        let view = FlatDriverCardView(card: card, driverCard: driverCard, renderWidth: 1080)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.uiImage
    }
    
    private func renderLandscapeCard(card: AnyCard) -> UIImage? {
        let view = FlatLandscapeCardView(card: card, renderWidth: 1920)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.uiImage
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
        
        print("✅ Uploaded flat image: \(path) (\(data.count / 1024)KB)")
        return downloadURL.absoluteString
    }
    
    enum FlattenError: Error, LocalizedError {
        case renderFailed, notAuthenticated, noFirebaseId
        
        var errorDescription: String? {
            switch self {
            case .renderFailed: return "Failed to render card image"
            case .notAuthenticated: return "Not authenticated"
            case .noFirebaseId: return "Card has no Firebase ID"
            }
        }
    }
}
