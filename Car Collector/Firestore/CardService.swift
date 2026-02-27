//
//  CardService.swift
//  CarCardCollector
//
//  Cloud storage for car cards – Firestore metadata + Firebase Storage for images
//  CloudCard struct is now in separate CloudCard.swift file
//

import Foundation
import Combine
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
    
    // Image cache to avoid re-downloading (limited to ~40MB)
    private var imageCache = NSCache<NSString, UIImage>()
    
    private var cardsCollection: CollectionReference {
        db.collection("cards")
    }
    
    private init() {
        imageCache.countLimit = 50
        imageCache.totalCostLimit = 40 * 1024 * 1024  // 40MB max
        
        // Clear caches on memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.imageCache.removeAllObjects()
            CardImageStore.shared.clearCache()
            URLCache.shared.removeAllCachedResponses()
            print("⚠️ Memory warning: cleared all image caches")
        }
    }
    
    /// Estimated memory cost of a UIImage for NSCache
    private func imageCost(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 500_000 }
        return cg.bytesPerRow * cg.height
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
        previousOwners: Int = 0,
        customFrame: String? = nil,
        rarity: CardRarity? = nil
    ) async throws -> CloudCard {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Generate card ID
        let cardId = UUID().uuidString
        
        // 1. Upload image to Storage
        let imageURL = try await uploadCardImage(image, uid: uid, cardId: cardId)
        
        // 2. Save metadata to Firestore (with new fields)
        // If no custom frame specified, use rarity border as default
        let effectiveFrame = customFrame ?? rarity?.borderAssetName
        
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
            previousOwners: previousOwners,
            customFrame: effectiveFrame,
            rarity: rarity?.rawValue
        )
        
        try await cardsCollection.document(cardId).setData(card.dictionary)
        
        // 3. Increment user's card count
        try await UserService.shared.incrementCardCount(uid: uid)
        
        // 4. Cache the image locally
        imageCache.setObject(image, forKey: imageURL as NSString, cost: imageCost(image))
        
        // 5. Post activity to friend feed
        do {
            print("📣 Posting card activity to friends feed")
            print("   CardId: \(cardId)")
            print("   CustomFrame: \(customFrame ?? "none")")
            
            try await FriendsService.shared.postCardActivity(
                cardId: cardId,
                make: make,
                model: model,
                year: year,
                imageURL: imageURL,
                customFrame: effectiveFrame,
                rarity: rarity
            )
            print("✅ Posted activity to friends feed with cardId: \(cardId)")
        } catch {
            print("⚠️ Failed to post friend activity (non-critical): \(error)")
        }
        
        print("✅ Saved card: \(make) \(model) - Captured by: \(capturedBy ?? "unknown"), Location: \(capturedLocation ?? "unknown")")
        
        // Note: Flatten + upload happens later in fetchSpecsForNewCard() once rarity is known,
        // ensuring the flat image always has the correct rarity border.
        
        return card
    }
    
    // MARK: - Quiet Sync (for starring — no activity post, no card count increment)
    
    func syncCardQuietly(image: UIImage, savedCard: SavedCard) async throws -> CloudCard {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        let cardId = UUID().uuidString
        let imageURL = try await uploadCardImage(image, uid: uid, cardId: cardId)
        
        let card = CloudCard(
            id: cardId,
            ownerId: uid,
            make: savedCard.make,
            model: savedCard.model,
            color: savedCard.color,
            year: savedCard.year,
            imageURL: imageURL,
            capturedBy: savedCard.capturedBy,
            capturedLocation: savedCard.capturedLocation,
            previousOwners: savedCard.previousOwners,
            customFrame: savedCard.customFrame
        )
        
        try await cardsCollection.document(cardId).setData(card.dictionary)
        print("⭐ Quiet sync complete: \(savedCard.make) \(savedCard.model)")
        return card
    }
    
    // MARK: - Update Custom Frame
    
    func updateCustomFrame(cardId: String, customFrame: String?) async throws {
        try await cardsCollection.document(cardId).updateData([
            "customFrame": customFrame ?? FieldValue.delete()
        ])
        print("✅ Updated custom frame for card: \(cardId)")
        
        // Also update the frame in friend activities
        do {
            try await FriendsService.shared.updateActivityCustomFrame(
                cardId: cardId,
                customFrame: customFrame
            )
            print("✅ Updated custom frame in friend activity")
        } catch {
            print("⚠️ Failed to update friend activity frame (non-critical): \(error)")
        }
        
        // Clear old cached renders
        CardRenderer.shared.clearCache()
    }
    
    /// Update a single field on a card document and its corresponding activity
    func updateField(cardId: String, field: String, value: Any) async throws {
        let firestoreValue: Any = (value is NSNull || value as? String == nil) ? FieldValue.delete() : value
        try await cardsCollection.document(cardId).updateData([
            field: firestoreValue
        ])
        
        // Also update the field in friend activities
        do {
            try await FriendsService.shared.updateActivityField(
                cardId: cardId,
                field: field,
                value: value
            )
        } catch {
            print("⚠️ Failed to update friend activity field \(field) (non-critical): \(error)")
        }
    }
    
    /// Re-flatten a card after frame/border change. Call this with the updated AnyCard.
    func reflattenCard(_ card: AnyCard) async {
        do {
            let flatURL = try await CardFlattener.shared.reflatten(card)
            print("✅ Re-flattened card after frame change: \(flatURL.prefix(60))...")
        } catch {
            print("⚠️ Re-flatten failed (non-critical): \(error)")
        }
    }
    
    // MARK: - Re-upload Card Image (after customization like background removal)
    
    func updateCardImage(cardId: String, image: UIImage) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Re-upload image (overwrites existing file at same path)
        let newImageURL = try await uploadCardImage(image, uid: uid, cardId: cardId)
        
        // Update imageURL in cards collection
        try await cardsCollection.document(cardId).updateData([
            "imageURL": newImageURL
        ])
        print("✅ Updated card image URL: \(cardId)")
        
        // Update imageURL in friend activities
        do {
            try await FriendsService.shared.updateActivityImageURL(
                cardId: cardId,
                imageURL: newImageURL
            )
            print("✅ Updated image URL in friend activity")
        } catch {
            print("⚠️ Failed to update friend activity image (non-critical): \(error)")
        }
        
        // Update local cache
        imageCache.setObject(image, forKey: newImageURL as NSString, cost: imageCost(image))
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
            .getDocuments()
        
        return snapshot.documents.compactMap { CloudCard(document: $0) }
            .sorted { $0.createdAt > $1.createdAt }
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
        imageCache.setObject(image, forKey: urlString as NSString, cost: imageCost(image))
        
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
        
        _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
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
    
    // MARK: - Sync Driver Card to Firebase
    
    func syncDriverCard(image: UIImage, driverCard: DriverCard) async throws -> CloudCard {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        let cardId = UUID().uuidString
        let imageURL = try await uploadCardImage(image, uid: uid, cardId: cardId)
        
        let card = CloudCard(
            id: cardId,
            ownerId: uid,
            cardType: "driver",
            make: driverCard.firstName,
            model: driverCard.lastName,
            color: "Driver",
            year: driverCard.nickname.isEmpty ? "Driver" : driverCard.nickname,
            imageURL: imageURL,
            capturedBy: driverCard.capturedBy,
            capturedLocation: driverCard.capturedLocation,
            previousOwners: 0,
            customFrame: driverCard.customFrame,
            firstName: driverCard.firstName,
            lastName: driverCard.lastName,
            nickname: driverCard.nickname
        )
        
        try await cardsCollection.document(cardId).setData(card.dictionary)
        print("⭐ Driver card synced: \(driverCard.firstName) \(driverCard.lastName)")
        return card
    }
    
    // MARK: - Sync Location Card to Firebase
    
    func syncLocationCard(image: UIImage, locationCard: LocationCard) async throws -> CloudCard {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        let cardId = UUID().uuidString
        let imageURL = try await uploadCardImage(image, uid: uid, cardId: cardId)
        
        let card = CloudCard(
            id: cardId,
            ownerId: uid,
            cardType: "location",
            make: locationCard.locationName,
            model: "",
            color: "Location",
            year: "Location",
            imageURL: imageURL,
            capturedBy: locationCard.capturedBy,
            capturedLocation: locationCard.capturedLocation,
            previousOwners: 0,
            customFrame: locationCard.customFrame,
            locationName: locationCard.locationName
        )
        
        try await cardsCollection.document(cardId).setData(card.dictionary)
        print("⭐ Location card synced: \(locationCard.locationName)")
        return card
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        cardsListener?.remove()
        cardsListener = nil
    }
    
    // MARK: - Migrate Local Cards to Cloud (UPDATED with metadata)
    
    // MARK: - Sync Modified Card Images to Firebase
    
    /// Re-uploads card images that were modified locally (e.g. background removal)
    /// but never synced to Firebase. Call on app startup.
    func syncModifiedImages(localCards: [SavedCard]) async {
        guard FirebaseManager.shared.currentUserId != nil else { return }
        
        var synced = 0
        for card in localCards {
            // Card has background removed (original image exists) and has a firebaseId
            guard card.hasOriginalImage,
                  let firebaseId = card.firebaseId,
                  let image = card.image else { continue }
            
            do {
                try await updateCardImage(cardId: firebaseId, image: image)
                synced += 1
                print("🔄 Synced modified image for \(card.make) \(card.model)")
            } catch {
                print("⚠️ Failed to sync image for \(card.make) \(card.model): \(error)")
            }
        }
        
        if synced > 0 {
            print("✅ Synced \(synced) modified card images to Firebase")
        }
    }
    
    // MARK: - Migrate Local Cards
    
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
                previousOwners: localCard.previousOwners,
                rarity: localCard.specs?.rarity
            )
        }
        
        print("✅ Migrated \(localCards.count) local cards to cloud with metadata")
    }
    
    // MARK: - Save Driver Card
    
    func saveDriverCard(
        image: UIImage,
        firstName: String,
        lastName: String,
        nickname: String = "",
        vehicleName: String = "",
        isDriverPlusVehicle: Bool = false,
        capturedBy: String? = nil,
        capturedLocation: String? = nil
    ) async throws -> String {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Generate card ID
        let cardId = UUID().uuidString
        
        // 1. Upload image to Storage
        let imageURL = try await uploadCardImage(image, uid: uid, cardId: cardId)
        
        // 2. Save metadata to Firestore
        let data: [String: Any] = [
            "id": cardId,
            "type": "driver",
            "ownerId": uid,
            "firstName": firstName,
            "lastName": lastName,
            "nickname": nickname,
            "vehicleName": vehicleName,
            "isDriverPlusVehicle": isDriverPlusVehicle,
            "imageURL": imageURL,
            "capturedBy": capturedBy ?? "",
            "capturedLocation": capturedLocation ?? "",
            "capturedDate": Timestamp(date: Date()),
            "likes": 0,
            "likedBy": []
        ]
        
        try await cardsCollection.document(cardId).setData(data)
        
        // 3. Increment user's card count
        try await UserService.shared.incrementCardCount(uid: uid)
        
        // 4. Post activity to friend feed
        do {
            try await FriendsService.shared.postCardActivity(
                cardId: cardId,
                make: firstName,
                model: lastName,
                year: nickname,
                imageURL: imageURL,
                cardType: "driver"
            )
            print("✅ Posted driver activity to friends feed")
        } catch {
            print("⚠️ Failed to post driver friend activity (non-critical): \(error)")
        }
        
        print("✅ Driver card saved: \(firstName) \(lastName)")
        
        // 5. Flatten card image
        Task {
            do {
                let dc = DriverCard(
                    id: UUID(uuidString: cardId) ?? UUID(),
                    image: image,
                    firstName: firstName, lastName: lastName,
                    nickname: nickname, vehicleName: vehicleName,
                    isDriverPlusVehicle: isDriverPlusVehicle,
                    capturedBy: capturedBy, capturedLocation: capturedLocation,
                    firebaseId: cardId
                )
                let anyCard = AnyCard.driver(dc)
                let flatURL = try await CardFlattener.shared.flattenAndUpload(anyCard)
                print("✅ Driver flat image uploaded: \(flatURL.prefix(60))...")
                
                // Also update the activity feed entry with the flat image
                try? await FriendsService.shared.updateActivityFlatImageURL(cardId: cardId, flatImageURL: flatURL)
            } catch {
                print("⚠️ Driver flatten failed (non-critical): \(error)")
            }
        }
        
        return cardId
    }
    
    // MARK: - Save Location Card
    
    func saveLocationCard(
        image: UIImage,
        locationName: String,
        capturedBy: String? = nil,
        capturedLocation: String? = nil
    ) async throws -> String {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Generate card ID
        let cardId = UUID().uuidString
        
        // 1. Upload image to Storage
        let imageURL = try await uploadCardImage(image, uid: uid, cardId: cardId)
        
        // 2. Save metadata to Firestore
        let data: [String: Any] = [
            "id": cardId,
            "type": "location",
            "ownerId": uid,
            "locationName": locationName,
            "imageURL": imageURL,
            "capturedBy": capturedBy ?? "",
            "capturedLocation": capturedLocation ?? "",
            "capturedDate": Timestamp(date: Date()),
            "likes": 0,
            "likedBy": []
        ]
        
        try await cardsCollection.document(cardId).setData(data)
        
        // 3. Increment user's card count
        try await UserService.shared.incrementCardCount(uid: uid)
        
        // 4. Post activity to friend feed
        do {
            try await FriendsService.shared.postCardActivity(
                cardId: cardId,
                make: locationName,
                model: "",
                year: "",
                imageURL: imageURL,
                cardType: "location"
            )
            print("✅ Posted location activity to friends feed")
        } catch {
            print("⚠️ Failed to post location friend activity (non-critical): \(error)")
        }
        
        print("✅ Location card saved: \(locationName)")
        
        // 5. Flatten card image
        Task {
            do {
                let lc = LocationCard(
                    id: UUID(uuidString: cardId) ?? UUID(),
                    image: image,
                    locationName: locationName,
                    capturedBy: capturedBy, capturedLocation: capturedLocation,
                    firebaseId: cardId
                )
                let anyCard = AnyCard.location(lc)
                let flatURL = try await CardFlattener.shared.flattenAndUpload(anyCard)
                print("✅ Location flat image uploaded: \(flatURL.prefix(60))...")
                
                // Also update the activity feed entry with the flat image
                try? await FriendsService.shared.updateActivityFlatImageURL(cardId: cardId, flatImageURL: flatURL)
            } catch {
                print("⚠️ Location flatten failed (non-critical): \(error)")
            }
        }
        
        return cardId
    }
}
