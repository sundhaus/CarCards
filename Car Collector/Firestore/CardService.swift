//
//  CardService.swift
//  CarCardCollector
//
//  Cloud storage for car cards – Firestore metadata + Firebase Storage for images
//  CloudCard struct is now in separate CloudCard.swift file
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

@MainActor
class CardService: ObservableObject {
    static let shared = CardService()
    
    @Published var myCards: [CloudCard] = []
    @Published var isLoading = false
    
    private let db = FirebaseManager.shared.db
    private let storage = FirebaseManager.shared.storage
    private var cardsListener: ListenerRegistration?
    
    // Image cache to avoid re-downloading
    private var imageCache = NSCache<NSString, UIImage>()
    
    private var cardsCollection: CollectionReference {
        db.collection("cards")
    }
    
    private init() {
        imageCache.countLimit = 100
    }
    
    deinit {
        cardsListener?.remove()
    }
    
    // MARK: - Upload Card Image to Firebase Storage
    
    private func uploadCardImage(_ image: UIImage, uid: String, cardId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw FirebaseError.uploadFailed
        }
        
        let path = "cards/\(uid)/\(cardId).jpg"
        let ref = storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        
        print("✅ Uploaded card image: \(path)")
        return downloadURL.absoluteString
    }
    
    // MARK: - Save New Card (UPDATED with metadata parameters)
    
    func saveCard(
        image: UIImage,
        make: String,
        model: String,
        color: String,
        year: String,
        capturedBy: String? = nil,
        capturedLocation: String? = nil,
        previousOwners: Int = 0
    ) async throws -> CloudCard {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Generate card ID
        let cardId = UUID().uuidString
        
        // 1. Upload image to Storage
        let imageURL = try await uploadCardImage(image, uid: uid, cardId: cardId)
        
        // 2. Save metadata to Firestore (with new fields)
        let card = CloudCard(
            id: cardId,
            ownerId: uid,
            make: make,
            model: model,
            color: color,
            year: year,
            imageURL: imageURL,
            capturedBy: capturedBy,
            capturedLocation: capturedLocation,
            previousOwners: previousOwners
        )
        
        try await cardsCollection.document(cardId).setData(card.dictionary)
        
        // 3. Increment user's card count
        try await UserService.shared.incrementCardCount(uid: uid)
        
        // 4. Cache the image locally
        imageCache.setObject(image, forKey: imageURL as NSString)
        
        // 5. Post activity to friend feed
        do {
            try await FriendsService.shared.postCardActivity(
                cardId: cardId,
                make: make,
                model: model,
                year: year,
                imageURL: imageURL
            )
        } catch {
            print("⚠️ Failed to post friend activity (non-critical): \(error)")
        }
        
        print("✅ Saved card: \(make) \(model) - Captured by: \(capturedBy ?? "unknown"), Location: \(capturedLocation ?? "unknown")")
        return card
    }
    
    // MARK: - Listen to My Cards (real-time)
    
    func listenToMyCards(uid: String) {
        cardsListener?.remove()
        
        isLoading = true
        
        cardsListener = cardsCollection
            .whereField("ownerId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Cards listener error: \(error)")
                    Task { @MainActor in self?.isLoading = false }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self?.myCards = documents.compactMap { CloudCard(document: $0) }
                    self?.isLoading = false
                }
            }
    }
    
    // MARK: - Fetch Another User's Cards
    
    func fetchUserCards(uid: String) async throws -> [CloudCard] {
        let snapshot = try await cardsCollection
            .whereField("ownerId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { CloudCard(document: $0) }
    }
    
    // MARK: - Download Card Image (with caching)
    
    func loadImage(from urlString: String) async throws -> UIImage {
        // Check cache first
        if let cached = imageCache.object(forKey: urlString as NSString) {
            return cached
        }
        
        // Download from URL
        guard let url = URL(string: urlString) else {
            throw FirebaseError.uploadFailed
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw FirebaseError.uploadFailed
        }
        
        // Cache it
        imageCache.setObject(image, forKey: urlString as NSString)
        
        return image
    }
    
    // MARK: - Delete Card
    
    func deleteCard(_ cardId: String) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Delete image from Storage
        let imagePath = "cards/\(uid)/\(cardId).jpg"
        let ref = storage.reference().child(imagePath)
        
        do {
            try await ref.delete()
        } catch {
            print("⚠️ Image delete failed (may not exist): \(error)")
        }
        
        // Delete Firestore document
        try await cardsCollection.document(cardId).delete()
        
        print("✅ Deleted card: \(cardId)")
    }
    
    // MARK: - Transfer Card Ownership (UPDATED to increment previousOwners)
    
    func transferCard(cardId: String, toUserId: String) async throws {
        let cardRef = cardsCollection.document(cardId)
        
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let cardDocument: DocumentSnapshot
            do {
                try cardDocument = transaction.getDocument(cardRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            let oldOwners = cardDocument.data()?["previousOwners"] as? Int ?? 0
            
            // Update ownership and increment previous owners
            transaction.updateData([
                "ownerId": toUserId,
                "previousOwners": oldOwners + 1
            ], forDocument: cardRef)
            
            return nil
        })
        
        print("✅ Transferred card \(cardId) to \(toUserId)")
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        cardsListener?.remove()
    }
    
    // MARK: - Migrate Local Cards to Cloud (UPDATED with metadata)
    
    func migrateLocalCards(localCards: [SavedCard]) async throws {
        guard FirebaseManager.shared.currentUserId != nil else {
            throw FirebaseError.notAuthenticated
        }
        
        for localCard in localCards {
            guard let image = localCard.image else { continue }
            
            let _ = try await saveCard(
                image: image,
                make: localCard.make,
                model: localCard.model,
                color: localCard.color,
                year: localCard.year,
                capturedBy: localCard.capturedBy,
                capturedLocation: localCard.capturedLocation,
                previousOwners: localCard.previousOwners
            )
        }
        
        print("✅ Migrated \(localCards.count) local cards to cloud with metadata")
    }
}
