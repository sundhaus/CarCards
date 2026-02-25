//
//  GemStoreService.swift
//  Car Collector
//
//  StoreKit 2 integration for purchasing gem packs.
//  Gems are the premium currency used for instant rarity upgrades.
//

import Foundation
import StoreKit
import FirebaseFirestore

@MainActor
class GemStoreService: ObservableObject {
    static let shared = GemStoreService()
    
    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Set(RarityUpgradeConfig.gemProductIDs))
            
            // Sort by price ascending
            products = storeProducts.sorted { $0.price < $1.price }
            
            print("💎 Loaded \(products.count) gem products")
        } catch {
            print("❌ Failed to load gem products: \(error)")
        }
    }
    
    // MARK: - Purchase Gems
    
    func purchase(_ product: Product) async throws {
        isPurchasing = true
        purchaseError = nil
        
        defer { isPurchasing = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Award gems
            let gemAmount = RarityUpgradeConfig.gemAmounts[product.id] ?? 0
            if gemAmount > 0 {
                await awardGems(gemAmount)
            }
            
            // Finish the transaction
            await transaction.finish()
            
            print("✅ Purchased \(gemAmount) gems via \(product.id)")
            
        case .userCancelled:
            print("🚫 User cancelled gem purchase")
            
        case .pending:
            print("⏳ Gem purchase pending approval")
            
        @unknown default:
            print("❓ Unknown purchase result")
        }
    }
    
    // MARK: - Verify Transaction
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Listen for Transaction Updates
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerifiedOnBackground(result)
                    
                    let gemAmount = RarityUpgradeConfig.gemAmounts[transaction.productID] ?? 0
                    if gemAmount > 0 {
                        await self.awardGems(gemAmount)
                    }
                    
                    await transaction.finish()
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private nonisolated func checkVerifiedOnBackground<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Award Gems to User
    
    private func awardGems(_ amount: Int) async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        // Update Firestore
        do {
            try await FirebaseManager.shared.db.collection("users").document(uid).updateData([
                "gems": FieldValue.increment(Int64(amount))
            ])
        } catch {
            print("❌ Failed to award gems in Firestore: \(error)")
        }
        
        // Update local state
        UserService.shared.currentProfile?.gems += amount
        UserService.shared.currentProfile?.coins += 0  // Trigger @Published update
        
        print("💎 Awarded \(amount) gems to user \(uid)")
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            print("✅ Restored purchases")
        } catch {
            print("❌ Restore failed: \(error)")
        }
    }
}
