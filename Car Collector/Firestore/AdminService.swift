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
    
    // MARK: - SYSTEM WIDE RESET (One-Time Nuclear Wipe)
    
    /// Wipes ALL game data across the entire app. Keeps user accounts (auth + username).
    /// Resets: cards, activities, listings, races, leaderboards, follows, coins, levels, XP.
    func systemWideReset() async throws {
        guard isAdmin else { throw AdminError.notAdmin }
        
        print("💣 ADMIN: Starting SYSTEM-WIDE RESET...")
        print("   This will wipe ALL cards, activities, listings, races, and progress.")
        
        var totalDeleted = 0
        
        // 1. Delete ALL cards + their Storage images
        totalDeleted += await deleteEntireCollection("cards")
        
        // 2. Delete ALL friend activities + their comment subcollections
        totalDeleted += await deleteActivitiesWithComments()
        
        // 3. Delete ALL marketplace listings
        totalDeleted += await deleteEntireCollection("listings")
        
        // 4. Delete ALL races (H2H)
        totalDeleted += await deleteEntireCollection("races")
        
        // 5. Delete ALL race votes
        totalDeleted += await deleteEntireCollection("raceVotes")
        
        // 6. Delete ALL duo invites
        totalDeleted += await deleteEntireCollection("duoInvites")
        
        // 7. Delete ALL vote streaks
        totalDeleted += await deleteEntireCollection("voteStreaks")
        
        // 8. Delete ALL card cooldowns
        totalDeleted += await deleteEntireCollection("cardCooldowns")
        
        // 9. Delete ALL featured cards
        totalDeleted += await deleteEntireCollection("featured_cards")
        
        // 10. Delete ALL follows (social connections)
        totalDeleted += await deleteEntireCollection("follows")
        
        // 11. Delete ALL cached vehicle specs
        totalDeleted += await deleteEntireCollection("vehicleSpecs")
        
        // 12. Reset ALL user profiles (keep account, wipe progress)
        let usersReset = await resetAllUserProfiles()
        
        // 13. Delete ALL card images from Firebase Storage
        await deleteAllStorageImages()
        
        // 14. Clear local device data
        await MainActor.run {
            clearAllLocalData()
        }
        
        print("💣 SYSTEM-WIDE RESET COMPLETE")
        print("   Documents deleted: \(totalDeleted)")
        print("   User profiles reset: \(usersReset)")
        print("   Local storage cleared")
        print("   ✅ App is now brand new. Only accounts remain.")
    }
    
    // MARK: - Reset Helpers
    
    /// Deletes all documents in a collection (batched to avoid Firestore limits)
    private func deleteEntireCollection(_ collectionName: String) async -> Int {
        var totalDeleted = 0
        
        do {
            var hasMore = true
            while hasMore {
                let snapshot = try await db.collection(collectionName)
                    .limit(to: 400)
                    .getDocuments()
                
                if snapshot.documents.isEmpty {
                    hasMore = false
                    break
                }
                
                let batch = db.batch()
                for doc in snapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
                
                totalDeleted += snapshot.documents.count
                print("   🗑️ Deleted \(totalDeleted) from \(collectionName)...")
                
                if snapshot.documents.count < 400 {
                    hasMore = false
                }
            }
            
            print("   ✅ \(collectionName): \(totalDeleted) documents deleted")
        } catch {
            print("   ⚠️ \(collectionName) wipe failed: \(error.localizedDescription)")
        }
        
        return totalDeleted
    }
    
    /// Activities have comment subcollections that must be deleted first
    private func deleteActivitiesWithComments() async -> Int {
        var totalDeleted = 0
        
        do {
            var hasMore = true
            while hasMore {
                let snapshot = try await db.collection("friend_activities")
                    .limit(to: 200)
                    .getDocuments()
                
                if snapshot.documents.isEmpty {
                    hasMore = false
                    break
                }
                
                for doc in snapshot.documents {
                    // Delete comment subcollection first
                    let comments = try await doc.reference.collection("comments").getDocuments()
                    if !comments.documents.isEmpty {
                        let commentBatch = db.batch()
                        for comment in comments.documents {
                            commentBatch.deleteDocument(comment.reference)
                        }
                        try await commentBatch.commit()
                    }
                    
                    // Delete the activity itself
                    try await doc.reference.delete()
                    totalDeleted += 1
                }
                
                print("   🗑️ Deleted \(totalDeleted) activities (with comments)...")
                
                if snapshot.documents.count < 200 {
                    hasMore = false
                }
            }
            
            print("   ✅ friend_activities: \(totalDeleted) documents deleted")
        } catch {
            print("   ⚠️ Activities wipe failed: \(error.localizedDescription)")
        }
        
        return totalDeleted
    }
    
    /// Reset all user profiles: zero out level, XP, coins, cards count, clear crown card
    private func resetAllUserProfiles() async -> Int {
        var count = 0
        
        do {
            var hasMore = true
            while hasMore {
                let snapshot = try await db.collection("users")
                    .limit(to: 400)
                    .getDocuments()
                
                if snapshot.documents.isEmpty {
                    hasMore = false
                    break
                }
                
                let batch = db.batch()
                for doc in snapshot.documents {
                    batch.updateData([
                        "level": 1,
                        "currentXP": 0,
                        "totalXP": 0,
                        "coins": 0,
                        "totalCardsCollected": 0,
                        "crownCardId": FieldValue.delete()
                    ], forDocument: doc.reference)
                    count += 1
                }
                try await batch.commit()
                
                print("   🔄 Reset \(count) user profiles...")
                
                if snapshot.documents.count < 400 {
                    hasMore = false
                }
            }
            
            print("   ✅ users: \(count) profiles reset to fresh state")
        } catch {
            print("   ⚠️ User profile reset failed: \(error.localizedDescription)")
        }
        
        return count
    }
    
    /// Delete all card images from Firebase Storage (cards/ folder)
    private func deleteAllStorageImages() async {
        do {
            let ref = storage.reference().child("cards")
            let result = try await ref.listAll()
            
            // Delete files in root of cards/
            for item in result.items {
                try? await item.delete()
            }
            
            // Delete files in each user subfolder (cards/{uid}/)
            for prefix in result.prefixes {
                let subResult = try await prefix.listAll()
                for item in subResult.items {
                    try? await item.delete()
                }
            }
            
            print("   ✅ Firebase Storage: card images deleted")
        } catch {
            print("   ⚠️ Storage wipe failed (non-critical): \(error.localizedDescription)")
        }
    }
    
    /// Clear all local device data — UserDefaults, file-based images, caches
    private func clearAllLocalData() {
        // UserDefaults keys
        let keys = [
            "savedCards", "currentXP", "totalXP", "userLevel", "userCoins",
            "hasCompletedFlattenMigration_v3", "hasCompletedImageSync_v1",
            "lastViewedFollowersAt", "profileExists"
            // NOTE: keep "onboardingComplete" so user doesn't see onboarding again
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear file-based card images
        let fileManager = FileManager.default
        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let cardImagesDir = docs.appendingPathComponent("CardImages")
            try? fileManager.removeItem(at: cardImagesDir)
            
            // Also remove CSV export
            try? fileManager.removeItem(at: docs.appendingPathComponent("my_car_collection.csv"))
        }
        
        // Clear in-memory caches
        CardImageStore.shared.clearCache()
        
        print("   ✅ Local data cleared (UserDefaults + CardImages + caches)")
    }
    
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
