//
//  CardService.swift
//  CarCardCollector
//
//  Cloud storage for car cards â€” Firestore metadata + Firebase Storage for images
//  Replaces local-only CardStorage.swift
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

// Cloud card model (replaces local SavedCard for Firestore)
struct CloudCard: Identifiable, Codable {
    var id: String  // Firestore document ID
    var ownerId: String
    var make: String
    var model: String
    var color: String
    var year: String
    var imageURL: String
    var createdAt: Date
    
    // From Firestore document
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.ownerId = data["ownerId"] as? String ?? ""
        self.make = data["make"] as? String ?? ""
        self.model = data["model"] as? String ?? ""
        self.color = data["color"] as? String ?? ""
        self.year = data["year"] as? String ?? ""
        self.imageURL = data["imageURL"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    // New card
    init(id: String, ownerId: String, make: String, model: String, color: String, year: String, imageURL: String) {
        self.id = id
        self.ownerId = ownerId
        self.make = make
        self.model = model
        self.color = color
        self.year = year
        self.imageURL = imageURL
        self.createdAt = Date()
    }
    
    var dictionary: [String: Any] {
        return [
            "ownerId": ownerId,
            "make": make,
            "model": model,
            "color": color,
            "year": year,
            "imageURL": imageURL,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

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
        
        print("âœ… Uploaded card image: \(path)")
        return downloadURL.absoluteString
    }
    
    // MARK: - Save New Card (image â†’ Storage, metadata â†’ Firestore)
    
    func saveCard(image: UIImage, make: String, model: String, color: String, year: String) async throws -> CloudCard {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Generate card ID
        let cardId = UUID().uuidString
        
        // 1. Upload image to Storage
        let imageURL = try await uploadCardImage(image, uid: uid, cardId: cardId)
        
        // 2. Save metadata to Firestore
        let card = CloudCard(
            id: cardId,
            ownerId: uid,
            make: make,
            model: model,
            color: color,
            year: year,
            imageURL: imageURL
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
        
        print("✅ Saved card: \(make) \(model)")
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
                    print("âŒ Cards listener error: \(error)")
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
            print("âš ï¸ Image delete failed (may not exist): \(error)")
        }
        
        // Delete Firestore document
        try await cardsCollection.document(cardId).delete()
        
        print("âœ… Deleted card: \(cardId)")
    }
    
    // MARK: - Transfer Card Ownership (for marketplace trades)
    
    func transferCard(cardId: String, toUserId: String) async throws {
        try await cardsCollection.document(cardId).updateData([
            "ownerId": toUserId
        ])
        
        print("âœ… Transferred card \(cardId) to \(toUserId)")
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        cardsListener?.remove()
    }
    
    // MARK: - Migrate Local Cards to Cloud
    // Call once to move existing UserDefaults cards to Firestore
    
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
                year: localCard.year
            )
        }
        
        print("âœ… Migrated \(localCards.count) local cards to cloud")
    }
}
