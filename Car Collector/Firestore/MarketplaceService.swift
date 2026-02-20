//
//  MarketplaceService.swift
//  CarCardCollector
//
//  Real-time marketplace — listings, bids, and trades via Firestore
//  Replaces local-only ListingStorage
//

import Foundation
import FirebaseFirestore

// Cloud listing model
struct CloudListing: Identifiable {
    var id: String
    var cardId: String
    var sellerId: String
    var sellerUsername: String
    var make: String
    var model: String
    var year: String
    var imageURL: String
    var minStartBid: Double
    var buyNowPrice: Double
    var currentBid: Double
    var currentBidderId: String?
    var currentBidderUsername: String?
    var duration: Int  // Hours
    var listingDate: Date
    var expirationDate: Date
    var status: ListingStatus
    var customFrame: String?  // Custom border: "None", "White", "Black"
    var category: String?  // VehicleCategory raw value for filtering
    
    enum ListingStatus: String, Codable {
        case active
        case sold
        case expired
        case cancelled
    }
    
    // From Firestore
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.cardId = data["cardId"] as? String ?? ""
        self.sellerId = data["sellerId"] as? String ?? ""
        self.sellerUsername = data["sellerUsername"] as? String ?? ""
        self.make = data["make"] as? String ?? ""
        self.model = data["model"] as? String ?? ""
        self.year = data["year"] as? String ?? ""
        self.imageURL = data["imageURL"] as? String ?? ""
        self.minStartBid = data["minStartBid"] as? Double ?? 0
        self.buyNowPrice = data["buyNowPrice"] as? Double ?? 0
        self.currentBid = data["currentBid"] as? Double ?? 0
        self.currentBidderId = data["currentBidderId"] as? String
        self.currentBidderUsername = data["currentBidderUsername"] as? String
        self.duration = data["duration"] as? Int ?? 24
        self.listingDate = (data["listingDate"] as? Timestamp)?.dateValue() ?? Date()
        self.expirationDate = (data["expirationDate"] as? Timestamp)?.dateValue() ?? Date()
        self.status = ListingStatus(rawValue: data["status"] as? String ?? "active") ?? .active
        self.customFrame = data["customFrame"] as? String
        self.category = data["category"] as? String
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "cardId": cardId,
            "sellerId": sellerId,
            "sellerUsername": sellerUsername,
            "make": make,
            "model": model,
            "year": year,
            "imageURL": imageURL,
            "minStartBid": minStartBid,
            "buyNowPrice": buyNowPrice,
            "currentBid": currentBid,
            "duration": duration,
            "listingDate": Timestamp(date: listingDate),
            "expirationDate": Timestamp(date: expirationDate),
            "status": status.rawValue
        ]
        
        if let bidderId = currentBidderId {
            dict["currentBidderId"] = bidderId
        }
        if let bidderName = currentBidderUsername {
            dict["currentBidderUsername"] = bidderName
        }
        if let frame = customFrame {
            dict["customFrame"] = frame
        }
        
        return dict
    }
    
    var isExpired: Bool {
        Date() > expirationDate
    }
    
    var timeRemaining: String {
        let interval = expirationDate.timeIntervalSince(Date())
        if interval <= 0 { return "Expired" }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

@MainActor
class MarketplaceService: ObservableObject {
    static let shared = MarketplaceService()
    
    @Published var activeListings: [CloudListing] = []
    @Published var myListings: [CloudListing] = []
    @Published var myBids: [CloudListing] = []
    @Published var isLoading = false
    
    private let db = FirebaseManager.shared.db
    private var activeListingsListener: ListenerRegistration?
    private var myListingsListener: ListenerRegistration?
    private var myBidsListener: ListenerRegistration?
    
    private var listingsCollection: CollectionReference {
        db.collection("listings")
    }
    
    private init() {}
    
    deinit {
        activeListingsListener?.remove()
        myListingsListener?.remove()
        myBidsListener?.remove()
    }
    
    // MARK: - Create Listing
    
    func createListing(
        card: CloudCard,
        minStartBid: Double,
        buyNowPrice: Double,
        duration: Int,
        category: String? = nil
    ) async throws -> CloudListing {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        let listingId = UUID().uuidString
        let listingDate = Date()
        let expirationDate = Calendar.current.date(byAdding: .hour, value: duration, to: listingDate) ?? listingDate
        
        var data: [String: Any] = [
            "cardId": card.id,
            "sellerId": uid,
            "sellerUsername": profile.username,
            "make": card.make,
            "model": card.model,
            "year": card.year,
            "imageURL": card.imageURL,
            "minStartBid": minStartBid,
            "buyNowPrice": buyNowPrice,
            "currentBid": 0.0,
            "duration": duration,
            "listingDate": Timestamp(date: listingDate),
            "expirationDate": Timestamp(date: expirationDate),
            "status": "active"
        ]
        
        // Add customFrame if present
        if let frame = card.customFrame {
            data["customFrame"] = frame
        }
        
        // Add category if present
        if let category = category {
            data["category"] = category
        }
        
        try await listingsCollection.document(listingId).setData(data)
        
        print("✅ Created listing: \(card.make) \(card.model)")
        
        // Return the listing
        let doc = try await listingsCollection.document(listingId).getDocument()
        guard let listing = CloudListing(document: doc) else {
            throw FirebaseError.documentNotFound
        }
        return listing
    }
    
    // MARK: - Place Bid
    
    func placeBid(listingId: String, amount: Double) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        // Use a transaction to prevent race conditions on bids
        let _ = try await db.runTransaction { transaction, errorPointer in
            let listingRef = self.listingsCollection.document(listingId)
            
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(listingRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            
            guard let data = document.data(),
                  let status = data["status"] as? String,
                  status == "active" else {
                errorPointer?.pointee = NSError(
                    domain: "MarketplaceService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Listing is no longer active"]
                )
                return nil
            }
            
            let currentBid = data["currentBid"] as? Double ?? 0
            let minStartBid = data["minStartBid"] as? Double ?? 0
            let sellerId = data["sellerId"] as? String ?? ""
            
            // Can't bid on your own listing
            guard sellerId != uid else {
                errorPointer?.pointee = NSError(
                    domain: "MarketplaceService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Can't bid on your own listing"]
                )
                return nil
            }
            
            // Bid must be higher than current and meet minimum
            let minimumBid = max(currentBid + 1, minStartBid)
            guard amount >= minimumBid else {
                errorPointer?.pointee = NSError(
                    domain: "MarketplaceService",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Bid must be at least \(Int(minimumBid)) coins"]
                )
                return nil
            }
            
            // Update the listing
            transaction.updateData([
                "currentBid": amount,
                "currentBidderId": uid,
                "currentBidderUsername": profile.username
            ], forDocument: listingRef)
            
            return nil
        }
        
        print("✅ Placed bid of \(Int(amount)) on \(listingId)")
    }
    
    // MARK: - Buy Now
    
    func buyNow(listingId: String) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        // Transaction: check listing is active, deduct coins, transfer card
        let _ = try await db.runTransaction { transaction, errorPointer in
            let listingRef = self.listingsCollection.document(listingId)
            
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(listingRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            
            guard let data = document.data(),
                  let status = data["status"] as? String,
                  status == "active" else {
                errorPointer?.pointee = NSError(
                    domain: "MarketplaceService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Listing is no longer active"]
                )
                return nil
            }
            
            let buyNowPrice = data["buyNowPrice"] as? Double ?? 0
            let sellerId = data["sellerId"] as? String ?? ""
            let cardId = data["cardId"] as? String ?? ""
            
            guard sellerId != uid else {
                errorPointer?.pointee = NSError(
                    domain: "MarketplaceService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Can't buy your own listing"]
                )
                return nil
            }
            
            // Check buyer has enough coins
            guard profile.coins >= Int(buyNowPrice) else {
                errorPointer?.pointee = NSError(
                    domain: "MarketplaceService",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Not enough coins"]
                )
                return nil
            }
            
            // 1. Mark listing as sold
            transaction.updateData([
                "status": "sold",
                "currentBid": buyNowPrice,
                "currentBidderId": uid,
                "currentBidderUsername": profile.username
            ], forDocument: listingRef)
            
            // 2. Transfer card ownership
            let cardRef = self.db.collection("cards").document(cardId)
            transaction.updateData(["ownerId": uid], forDocument: cardRef)
            
            // 3. Deduct coins from buyer
            let buyerRef = self.db.collection("users").document(uid)
            transaction.updateData([
                "coins": FieldValue.increment(Int64(-Int(buyNowPrice)))
            ], forDocument: buyerRef)
            
            // 4. Add coins to seller
            let sellerRef = self.db.collection("users").document(sellerId)
            transaction.updateData([
                "coins": FieldValue.increment(Int64(Int(buyNowPrice)))
            ], forDocument: sellerRef)
            
            return nil
        }
        
        print("✅ Buy now completed for listing \(listingId)")
    }
    
    // MARK: - Cancel Listing
    
    func cancelListing(listingId: String) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Verify ownership
        let doc = try await listingsCollection.document(listingId).getDocument()
        guard let data = doc.data(), data["sellerId"] as? String == uid else {
            throw FirebaseError.notAuthenticated
        }
        
        try await listingsCollection.document(listingId).updateData([
            "status": "cancelled"
        ])
        
        print("✅ Cancelled listing: \(listingId)")
    }
    
    // MARK: - Real-time Listeners
    
    /// Listen to all active marketplace listings
    func listenToActiveListings(filterMake: String? = nil, filterModel: String? = nil) {
        activeListingsListener?.remove()
        isLoading = true
        
        var query: Query = listingsCollection
            .whereField("status", isEqualTo: "active")
            .order(by: "listingDate", descending: true)
        
        if let make = filterMake, make != "Any" {
            query = query.whereField("make", isEqualTo: make)
        }
        
        activeListingsListener = query.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("❌ Active listings error: \(error)")
                Task { @MainActor in self?.isLoading = false }
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            Task { @MainActor in
                self?.activeListings = documents.compactMap { CloudListing(document: $0) }
                    .filter { !$0.isExpired }
                self?.isLoading = false
            }
        }
    }
    
    /// Listen to my active listings (Transfer List)
    func listenToMyListings(uid: String) {
        myListingsListener?.remove()
        
        myListingsListener = listingsCollection
            .whereField("sellerId", isEqualTo: uid)
            .order(by: "listingDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ My listings error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self?.myListings = documents.compactMap { CloudListing(document: $0) }
                }
            }
    }
    
    /// Listen to listings I'm bidding on (Transfer Targets)
    func listenToMyBids(uid: String) {
        myBidsListener?.remove()
        
        myBidsListener = listingsCollection
            .whereField("currentBidderId", isEqualTo: uid)
            .whereField("status", isEqualTo: "active")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ My bids error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self?.myBids = documents.compactMap { CloudListing(document: $0) }
                }
            }
    }
    
    // MARK: - Stop Listeners
    
    func stopAllListeners() {
        activeListingsListener?.remove()
        myListingsListener?.remove()
        myBidsListener?.remove()
    }
}
