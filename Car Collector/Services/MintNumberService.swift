//
//  MintNumberService.swift
//  Car Collector
//
//  Manages global sequential mint numbers for Legendary cards.
//  Uses a Firestore transaction to atomically increment a counter,
//  ensuring every Legendary card gets a unique, sequential number.
//

import Foundation
import FirebaseFirestore

@MainActor
class MintNumberService {
    static let shared = MintNumberService()
    
    private let db = FirebaseManager.shared.db
    private let counterDocRef: DocumentReference
    
    private init() {
        counterDocRef = db.collection("counters").document("legendaryMints")
    }
    
    /// Atomically claim the next Legendary mint number.
    /// Returns the assigned number (starting from 1).
    func claimNextMintNumber() async throws -> Int {
        let mintNumber = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(self.counterDocRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            
            let currentCount = snapshot.data()?["count"] as? Int ?? 0
            let nextNumber = currentCount + 1
            
            transaction.setData(["count": nextNumber], forDocument: self.counterDocRef)
            
            return nextNumber
        }
        
        guard let number = mintNumber as? Int else {
            throw NSError(domain: "MintNumberService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to claim mint number"])
        }
        
        print("🏆 Claimed Legendary mint #\(number)")
        return number
    }
    
    /// Stamp a mint number onto a card in Firestore and locally.
    /// Call this when a card is determined to be Legendary.
    func stampMintNumber(cardId: String) async throws -> Int {
        let mintNumber = try await claimNextMintNumber()
        
        // Write to Firestore card doc
        try await db.collection("cards").document(cardId).updateData([
            "mintNumber": mintNumber
        ])
        
        print("🏆 Stamped mint #\(mintNumber) on card \(cardId)")
        return mintNumber
    }
}
