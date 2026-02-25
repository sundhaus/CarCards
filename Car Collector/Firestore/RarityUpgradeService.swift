//
//  RarityUpgradeService.swift
//  Car Collector
//
//  Manages the rarity upgrade system — unlock gates, evolution point tracking,
//  and executing upgrades via free (evolution) or paid (gems) paths.
//

import Foundation
import FirebaseFirestore

@MainActor
class RarityUpgradeService: ObservableObject {
    static let shared = RarityUpgradeService()
    
    private let db = FirebaseManager.shared.db
    
    private init() {}
    
    // MARK: - Unlock Gate Validation
    
    /// Check whether the user meets all requirements to upgrade TO a target rarity
    func checkUnlockGate(
        targetRarity: CardRarity,
        userLevel: Int,
        totalCardsOwned: Int,
        battleWins: Int
    ) -> UnlockGateResult {
        let reqLevel = RarityUpgradeConfig.requiredLevel(for: targetRarity)
        let reqCards = RarityUpgradeConfig.requiredCardsOwned(for: targetRarity)
        let reqWins  = RarityUpgradeConfig.requiredBattleWins(for: targetRarity)
        
        let levelMet = userLevel >= reqLevel
        let cardsMet = totalCardsOwned >= reqCards
        let winsMet  = battleWins >= reqWins
        
        return UnlockGateResult(
            isUnlocked: levelMet && cardsMet && winsMet,
            levelMet: levelMet,
            requiredLevel: reqLevel,
            cardsMet: cardsMet,
            requiredCards: reqCards,
            winsMet: winsMet,
            requiredWins: reqWins
        )
    }
    
    // MARK: - Fetch Evolution Points for a Card
    
    /// Get evolution points for a specific card from Firestore
    func fetchEvolutionPoints(cardId: String) async throws -> Int {
        let doc = try await db.collection("cards").document(cardId).getDocument()
        return doc.data()?["evolutionPoints"] as? Int ?? 0
    }
    
    // MARK: - Fetch User Battle Wins
    
    /// Get total battle wins from user's race history
    func fetchUserBattleWins(uid: String) async throws -> Int {
        // Query finished races where this user was the winner
        let snapshot = try await db.collection("head_to_head")
            .whereField("winnerId", isEqualTo: uid)
            .whereField("status", isEqualTo: "finished")
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    // MARK: - Award Evolution Points After Battle
    
    /// Called after a race finishes to award evolution points to participating cards
    func awardEvolutionPoints(
        cardId: String,
        points: Int
    ) async throws {
        try await db.collection("cards").document(cardId).updateData([
            "evolutionPoints": FieldValue.increment(Int64(points)),
            "lastBattleUsed": Timestamp(date: Date())
        ])
        
        print("⬆️ Awarded \(points) evolution points to card \(cardId)")
    }
    
    // MARK: - Upgrade Via Free Path (Evolution Points)
    
    /// Upgrade a card's rarity using accumulated evolution points
    func upgradeWithEvolutionPoints(cardId: String, currentRarity: CardRarity) async throws -> CardRarity {
        guard let nextRarity = RarityUpgradeConfig.nextRarity(from: currentRarity) else {
            throw RarityUpgradeError.alreadyMaxRarity
        }
        
        let requiredPoints = RarityUpgradeConfig.evolutionPointsRequired(from: currentRarity)
        let currentPoints = try await fetchEvolutionPoints(cardId: cardId)
        
        guard currentPoints >= requiredPoints else {
            throw RarityUpgradeError.insufficientEvolutionPoints(
                current: currentPoints,
                required: requiredPoints
            )
        }
        
        // Deduct evolution points and upgrade rarity
        try await db.collection("cards").document(cardId).updateData([
            "rarity": nextRarity.rawValue,
            "evolutionPoints": FieldValue.increment(Int64(-requiredPoints)),
            "lastUpgradedAt": Timestamp(date: Date()),
            "upgradeMethod": "evolution"
        ])
        
        print("🌟 Card \(cardId) upgraded from \(currentRarity.rawValue) → \(nextRarity.rawValue) via evolution!")
        return nextRarity
    }
    
    // MARK: - Upgrade Via Gems (Premium Path)
    
    /// Upgrade a card's rarity by spending gems
    func upgradeWithGems(cardId: String, currentRarity: CardRarity) async throws -> CardRarity {
        guard let nextRarity = RarityUpgradeConfig.nextRarity(from: currentRarity) else {
            throw RarityUpgradeError.alreadyMaxRarity
        }
        
        let gemCost = RarityUpgradeConfig.gemCost(from: currentRarity)
        
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw RarityUpgradeError.notAuthenticated
        }
        
        // Check gem balance
        let userDoc = try await db.collection("users").document(uid).getDocument()
        let currentGems = userDoc.data()?["gems"] as? Int ?? 0
        
        guard currentGems >= gemCost else {
            throw RarityUpgradeError.insufficientGems(
                current: currentGems,
                required: gemCost
            )
        }
        
        // Batch: deduct gems + upgrade rarity (atomic)
        let batch = db.batch()
        
        let userRef = db.collection("users").document(uid)
        batch.updateData([
            "gems": FieldValue.increment(Int64(-gemCost))
        ], forDocument: userRef)
        
        let cardRef = db.collection("cards").document(cardId)
        batch.updateData([
            "rarity": nextRarity.rawValue,
            "lastUpgradedAt": Timestamp(date: Date()),
            "upgradeMethod": "gems"
        ], forDocument: cardRef)
        
        try await batch.commit()
        
        // Update local state
        UserService.shared.currentProfile?.gems = currentGems - gemCost
        
        print("💎 Card \(cardId) upgraded from \(currentRarity.rawValue) → \(nextRarity.rawValue) via gems (\(gemCost) spent)!")
        return nextRarity
    }
}

// MARK: - Unlock Gate Result

struct UnlockGateResult {
    let isUnlocked: Bool
    let levelMet: Bool
    let requiredLevel: Int
    let cardsMet: Bool
    let requiredCards: Int
    let winsMet: Bool
    let requiredWins: Int
}

// MARK: - Errors

enum RarityUpgradeError: LocalizedError {
    case alreadyMaxRarity
    case insufficientEvolutionPoints(current: Int, required: Int)
    case insufficientGems(current: Int, required: Int)
    case notAuthenticated
    case unlockGateNotMet
    
    var errorDescription: String? {
        switch self {
        case .alreadyMaxRarity:
            return "This card is already at Legendary rarity"
        case .insufficientEvolutionPoints(let current, let required):
            return "Need \(required) evolution points (have \(current))"
        case .insufficientGems(let current, let required):
            return "Need \(required) gems (have \(current))"
        case .notAuthenticated:
            return "Not signed in"
        case .unlockGateNotMet:
            return "Unlock requirements not met"
        }
    }
}
