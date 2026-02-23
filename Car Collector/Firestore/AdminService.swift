//
//  AdminService.swift
//  CarCardCollector
//
//  Admin tools for managing users and cards
//  Only accessible to admin accounts
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

@MainActor
class AdminService: ObservableObject {
    static let shared = AdminService()
    
    // Hardcoded admin UIDs — add your Firebase UID here
    static let adminUIDs: Set<String> = [
        "Ydnk69jI6kba4JiUYWEYBX8xDPU2"  // Fuego
    ]
    
    private let db = FirebaseManager.shared.db
    private let storage = FirebaseManager.shared.storage
    
    var isAdmin: Bool {
        guard let uid = FirebaseManager.shared.currentUserId else { return false }
        return AdminService.adminUIDs.contains(uid)
    }
    
    // MARK: - Remove Card (Full Cleanup)
    
    /// Removes a card and cleans up all references across the app
    func removeCard(cardId: String, ownerId: String) async throws {
        guard isAdmin else { throw AdminError.notAdmin }
        
        print("🔧 ADMIN: Removing card \(cardId) owned by \(ownerId)")
        
        // 1. Delete card image from Firebase Storage
        await deleteCardImage(cardId: cardId, ownerId: ownerId)
        
        // 2. Delete any marketplace listings for this card
        await deleteListings(for: cardId)
        
        // 3. Delete friend activity posts for this card
        await deleteActivities(for: cardId)
        
        // 4. Cancel any active H2H races involving this card
        await cancelRaces(for: cardId)
        
        // 5. If this was the user's crown card, clear it
        await clearCrownIfNeeded(cardId: cardId, ownerId: ownerId)
        
        // 6. Delete the card document itself
        try await db.collection("cards").document(cardId).delete()
        
        // 7. Decrement the owner's totalCardsCollected
        try await db.collection("users").document(ownerId).updateData([
            "totalCardsCollected": FieldValue.increment(Int64(-1))
        ])
        
        print("✅ ADMIN: Card \(cardId) fully removed")
    }
    
    // MARK: - Cleanup Helpers
    
    private func deleteCardImage(cardId: String, ownerId: String) async {
        let imagePath = "cards/\(ownerId)/\(cardId).jpg"
        let ref = storage.reference().child(imagePath)
        do {
            try await ref.delete()
            print("  ✅ Deleted image: \(imagePath)")
        } catch {
            print("  ⚠️ Image delete failed (may not exist): \(error.localizedDescription)")
        }
    }
    
    private func deleteListings(for cardId: String) async {
        do {
            let snap = try await db.collection("listings")
                .whereField("cardId", isEqualTo: cardId)
                .getDocuments()
            
            for doc in snap.documents {
                try await doc.reference.delete()
            }
            
            if !snap.documents.isEmpty {
                print("  ✅ Deleted \(snap.documents.count) marketplace listing(s)")
            }
        } catch {
            print("  ⚠️ Listing cleanup failed: \(error.localizedDescription)")
        }
    }
    
    private func deleteActivities(for cardId: String) async {
        do {
            let snap = try await db.collection("friend_activities")
                .whereField("cardId", isEqualTo: cardId)
                .getDocuments()
            
            for doc in snap.documents {
                // Also delete comments on this activity
                let comments = try await doc.reference.collection("comments").getDocuments()
                for comment in comments.documents {
                    try await comment.reference.delete()
                }
                try await doc.reference.delete()
            }
            
            if !snap.documents.isEmpty {
                print("  ✅ Deleted \(snap.documents.count) activity post(s) + comments")
            }
        } catch {
            print("  ⚠️ Activity cleanup failed: \(error.localizedDescription)")
        }
    }
    
    private func cancelRaces(for cardId: String) async {
        do {
            // Check as challenger
            let challengerSnap = try await db.collection("races")
                .whereField("challengerCardId", isEqualTo: cardId)
                .whereField("status", in: ["open", "active"])
                .getDocuments()
            
            // Check as defender
            let defenderSnap = try await db.collection("races")
                .whereField("defenderCardId", isEqualTo: cardId)
                .whereField("status", isEqualTo: "active")
                .getDocuments()
            
            for doc in challengerSnap.documents + defenderSnap.documents {
                try await doc.reference.updateData([
                    "status": "cancelled"
                ])
            }
            
            let total = challengerSnap.documents.count + defenderSnap.documents.count
            if total > 0 {
                print("  ✅ Cancelled \(total) H2H race(s)")
            }
        } catch {
            print("  ⚠️ Race cleanup failed: \(error.localizedDescription)")
        }
    }
    
    private func clearCrownIfNeeded(cardId: String, ownerId: String) async {
        do {
            let userDoc = try await db.collection("users").document(ownerId).getDocument()
            if let crownId = userDoc.data()?["crownCardId"] as? String, crownId == cardId {
                try await db.collection("users").document(ownerId).updateData([
                    "crownCardId": FieldValue.delete()
                ])
                print("  ✅ Cleared crown card")
            }
        } catch {
            print("  ⚠️ Crown check failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Search Users (for admin panel)
    
    func searchUsers(query: String) async throws -> [(id: String, username: String, totalCards: Int)] {
        guard isAdmin else { throw AdminError.notAdmin }
        
        let snap = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query)
            .whereField("username", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()
        
        return snap.documents.compactMap { doc in
            let data = doc.data()
            guard let username = data["username"] as? String else { return nil }
            let totalCards = data["totalCardsCollected"] as? Int ?? 0
            return (id: doc.documentID, username: username, totalCards: totalCards)
        }
    }
    
    // MARK: - Fetch User Cards (for admin panel)
    
    func fetchUserCards(userId: String) async throws -> [CloudCard] {
        guard isAdmin else { throw AdminError.notAdmin }
        
        let snap = try await db.collection("cards")
            .whereField("ownerId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snap.documents.compactMap { CloudCard(document: $0) }
    }
}

// MARK: - Errors

enum AdminError: LocalizedError {
    case notAdmin
    
    var errorDescription: String? {
        switch self {
        case .notAdmin: return "Admin access required."
        }
    }
}
