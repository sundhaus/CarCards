//
//  CoinShopService.swift
//  Car Collector
//
//  Manages the coin shop: rotating daily deals, cosmetic packs, card re-rolls,
//  and persistent inventory of purchased cosmetic items.
//
//  Daily deals rotate at midnight using a deterministic seed (same deals for
//  all users on a given day). Purchased cosmetics are stored in Firestore
//  under users/{uid}/meta/coinShop.
//
//  Cosmetic types:
//    • Card backgrounds   — alternative background styles behind the photo
//    • Profile frames     — decorative frames around profile picture
//    • Capture effects    — visual effects that play on card capture
//    • Card stickers      — overlay stickers/badges on card display
//    • Cosmetic packs     — random bundles with guaranteed rarity tier
//

import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Cosmetic Item Model

struct CosmeticItem: Identifiable, Codable, Hashable {
    let id: String              // e.g. "bg_carbon_fiber", "frame_gold_ring"
    let name: String
    let description: String
    let icon: String            // SF Symbol
    let type: CosmeticType
    let rarity: CosmeticRarity
    let price: Int              // Coin price
    
    enum CosmeticType: String, Codable, Hashable {
        case cardBackground  = "cardBackground"
        case profileFrame    = "profileFrame"
        case captureEffect   = "captureEffect"
        case cardSticker     = "cardSticker"
    }
    
    enum CosmeticRarity: String, Codable, Hashable {
        case common    = "common"
        case rare      = "rare"
        case epic      = "epic"
        case legendary = "legendary"
        
        var color: Color {
            switch self {
            case .common:    return .gray
            case .rare:      return .blue
            case .epic:      return .purple
            case .legendary: return .yellow
            }
        }
        
        var gradient: [Color] {
            switch self {
            case .common:    return [.gray, .gray.opacity(0.7)]
            case .rare:      return [.blue, .cyan]
            case .epic:      return [.purple, .pink]
            case .legendary: return [.yellow, .orange]
            }
        }
    }
}

// MARK: - Cosmetic Pack Model

struct CosmeticPack: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let price: Int
    let guaranteedRarity: CosmeticItem.CosmeticRarity  // Minimum rarity guaranteed
    let itemCount: Int
    let gradientColors: [Color]
}

// MARK: - Daily Deal Model

struct DailyDeal: Identifiable {
    let id: String
    let item: CosmeticItem
    let originalPrice: Int
    let salePrice: Int
    let expiresAt: Date
    
    var discountPercent: Int {
        guard originalPrice > 0 else { return 0 }
        return Int(round(Double(originalPrice - salePrice) / Double(originalPrice) * 100))
    }
}

// MARK: - Service

@MainActor
class CoinShopService: ObservableObject {
    static let shared = CoinShopService()
    
    @Published var dailyDeals: [DailyDeal] = []
    @Published var ownedCosmetics: Set<String> = []    // IDs of cosmetics the user owns
    @Published var isLoaded = false
    @Published var lastPackResults: [CosmeticItem]? = nil  // Results from last pack opening
    
    // Equipped cosmetics — one active per type
    @Published var equippedBackground: String? = nil
    @Published var equippedFrame: String? = nil
    @Published var equippedEffect: String? = nil
    @Published var equippedSticker: String? = nil
    
    private let db = FirebaseManager.shared.db
    private let calendar = Calendar.current
    
    private init() {
        // Load local cache of equipped items
        equippedBackground = UserDefaults.standard.string(forKey: "equipped_background")
        equippedFrame = UserDefaults.standard.string(forKey: "equipped_frame")
        equippedEffect = UserDefaults.standard.string(forKey: "equipped_effect")
        equippedSticker = UserDefaults.standard.string(forKey: "equipped_sticker")
    }
    
    // MARK: - Full Cosmetic Catalog
    
    static let allCosmetics: [CosmeticItem] = [
        // Card Backgrounds
        CosmeticItem(id: "bg_carbon_fiber", name: "Carbon Fiber", description: "Sleek carbon weave texture", icon: "square.grid.3x3.fill", type: .cardBackground, rarity: .common, price: 200),
        CosmeticItem(id: "bg_brushed_metal", name: "Brushed Metal", description: "Industrial brushed aluminum look", icon: "rectangle.fill", type: .cardBackground, rarity: .common, price: 200),
        CosmeticItem(id: "bg_midnight_sky", name: "Midnight Sky", description: "Deep starfield background", icon: "moon.stars.fill", type: .cardBackground, rarity: .rare, price: 500),
        CosmeticItem(id: "bg_neon_grid", name: "Neon Grid", description: "Retro synthwave grid", icon: "grid", type: .cardBackground, rarity: .rare, price: 500),
        CosmeticItem(id: "bg_oil_slick", name: "Oil Slick", description: "Iridescent oil slick shimmer", icon: "drop.fill", type: .cardBackground, rarity: .epic, price: 1000),
        CosmeticItem(id: "bg_aurora", name: "Aurora Borealis", description: "Northern lights gradient", icon: "sparkles", type: .cardBackground, rarity: .epic, price: 1000),
        CosmeticItem(id: "bg_holographic", name: "Holographic", description: "Rainbow holographic foil", icon: "rectangle.portrait.on.rectangle.portrait.fill", type: .cardBackground, rarity: .legendary, price: 2500),
        
        // Profile Frames
        CosmeticItem(id: "frame_chrome_ring", name: "Chrome Ring", description: "Polished chrome profile frame", icon: "circle.dashed", type: .profileFrame, rarity: .common, price: 150),
        CosmeticItem(id: "frame_racing_stripe", name: "Racing Stripe", description: "Dual racing stripes frame", icon: "circle.lefthalf.striped.horizontal", type: .profileFrame, rarity: .rare, price: 400),
        CosmeticItem(id: "frame_flame_ring", name: "Flame Ring", description: "Animated flame border", icon: "flame.circle.fill", type: .profileFrame, rarity: .epic, price: 800),
        CosmeticItem(id: "frame_diamond_encrust", name: "Diamond Encrusted", description: "Sparkling diamond frame", icon: "diamond.circle.fill", type: .profileFrame, rarity: .legendary, price: 2000),
        
        // Capture Effects
        CosmeticItem(id: "fx_spark_burst", name: "Spark Burst", description: "Electric sparks on capture", icon: "bolt.fill", type: .captureEffect, rarity: .common, price: 250),
        CosmeticItem(id: "fx_smoke_trail", name: "Smoke Trail", description: "Tire smoke drifting effect", icon: "cloud.fill", type: .captureEffect, rarity: .rare, price: 600),
        CosmeticItem(id: "fx_nitro_flame", name: "Nitro Flame", description: "Nitrous boost flame burst", icon: "flame.fill", type: .captureEffect, rarity: .epic, price: 1200),
        CosmeticItem(id: "fx_lightning_strike", name: "Lightning Strike", description: "Thunder & lightning capture reveal", icon: "bolt.trianglebadge.exclamationmark.fill", type: .captureEffect, rarity: .legendary, price: 3000),
        
        // Card Stickers
        CosmeticItem(id: "sticker_speed_demon", name: "Speed Demon", description: "Flaming speed badge", icon: "hare.fill", type: .cardSticker, rarity: .common, price: 100),
        CosmeticItem(id: "sticker_garage_queen", name: "Garage Queen", description: "Crown badge for pristine rides", icon: "crown.fill", type: .cardSticker, rarity: .rare, price: 350),
        CosmeticItem(id: "sticker_unicorn", name: "Unicorn Find", description: "For ultra-rare captures", icon: "star.circle.fill", type: .cardSticker, rarity: .epic, price: 750),
        CosmeticItem(id: "sticker_goat", name: "G.O.A.T.", description: "Greatest of all time badge", icon: "trophy.fill", type: .cardSticker, rarity: .legendary, price: 1800),
    ]
    
    // MARK: - Cosmetic Packs
    
    static let cosmeticPacks: [CosmeticPack] = [
        CosmeticPack(
            id: "pack_starter",
            name: "Starter Pack",
            description: "3 random cosmetics • Common+ guaranteed",
            icon: "shippingbox.fill",
            price: 300,
            guaranteedRarity: .common,
            itemCount: 3,
            gradientColors: [.gray, .white.opacity(0.5)]
        ),
        CosmeticPack(
            id: "pack_premium",
            name: "Premium Pack",
            description: "3 random cosmetics • Rare+ guaranteed",
            icon: "shippingbox.and.arrow.backward.fill",
            price: 800,
            guaranteedRarity: .rare,
            itemCount: 3,
            gradientColors: [.blue, .cyan]
        ),
        CosmeticPack(
            id: "pack_elite",
            name: "Elite Pack",
            description: "3 random cosmetics • Epic+ guaranteed",
            icon: "gift.fill",
            price: 2000,
            guaranteedRarity: .epic,
            itemCount: 3,
            gradientColors: [.purple, .pink]
        ),
    ]
    
    // MARK: - Generate Daily Deals (deterministic from date)
    
    func generateDailyDeals(for date: Date = Date()) -> [DailyDeal] {
        let dayString = dayStringFrom(date)
        let seed = seedFromString(dayString)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        
        // Pick 4 items from the catalog as daily deals
        var available = Self.allCosmetics.filter { !ownedCosmetics.contains($0.id) }
        if available.count < 4 { available = Self.allCosmetics } // fallback if user owns most
        
        var deals: [DailyDeal] = []
        var usedIndices = Set<Int>()
        
        for i in 0..<4 {
            var idx = ((seed &* (i + 1)) &+ (seed >> (i + 2))) % available.count
            if idx < 0 { idx = abs(idx) % available.count }
            
            // Avoid duplicates
            var attempts = 0
            while usedIndices.contains(idx) && attempts < available.count {
                idx = (idx + 1) % available.count
                attempts += 1
            }
            usedIndices.insert(idx)
            
            let item = available[idx]
            let discountRange: ClosedRange<Int> = {
                switch i {
                case 0: return 30...50  // Best deal
                case 1: return 20...35
                default: return 10...25
                }
            }()
            
            let discountSeed = ((seed >> (i + 4)) &+ i) % (discountRange.upperBound - discountRange.lowerBound + 1) + discountRange.lowerBound
            let discount = max(discountRange.lowerBound, min(discountRange.upperBound, abs(discountSeed)))
            let salePrice = max(50, item.price - (item.price * discount / 100))
            
            deals.append(DailyDeal(
                id: "deal_\(dayString)_\(i)",
                item: item,
                originalPrice: item.price,
                salePrice: salePrice,
                expiresAt: endOfDay
            ))
        }
        
        return deals
    }
    
    // MARK: - Load & Sync from Firestore
    
    func load(uid: String) async {
        let docRef = db.collection("users").document(uid).collection("meta").document("coinShop")
        
        do {
            let snapshot = try await docRef.getDocument()
            if let data = snapshot.data() {
                ownedCosmetics = Set(data["ownedCosmetics"] as? [String] ?? [])
                equippedBackground = data["equippedBackground"] as? String
                equippedFrame = data["equippedFrame"] as? String
                equippedEffect = data["equippedEffect"] as? String
                equippedSticker = data["equippedSticker"] as? String
                saveEquippedLocally()
            }
        } catch {
            print("⚠️ CoinShopService: Failed to load: \(error)")
        }
        
        dailyDeals = generateDailyDeals()
        isLoaded = true
        print("✅ CoinShop loaded: \(ownedCosmetics.count) owned, \(dailyDeals.count) daily deals")
    }
    
    // MARK: - Purchase Cosmetic
    
    func purchaseItem(_ item: CosmeticItem, atPrice price: Int, uid: String) async -> Bool {
        guard !ownedCosmetics.contains(item.id) else {
            print("⚠️ Already owned: \(item.id)")
            return false
        }
        
        guard UserService.shared.spendCoins(price) else {
            print("⚠️ Not enough coins for \(item.name) (need \(price))")
            return false
        }
        
        ownedCosmetics.insert(item.id)
        await saveOwned(uid: uid)
        
        print("✅ Purchased \(item.name) for \(price) coins")
        return true
    }
    
    // MARK: - Purchase & Open Pack
    
    func openPack(_ pack: CosmeticPack, uid: String) async -> [CosmeticItem]? {
        guard UserService.shared.spendCoins(pack.price) else {
            print("⚠️ Not enough coins for \(pack.name) (need \(pack.price))")
            return nil
        }
        
        // Roll items from the catalog
        var results: [CosmeticItem] = []
        let unowned = Self.allCosmetics.filter { !ownedCosmetics.contains($0.id) }
        let pool = unowned.isEmpty ? Self.allCosmetics : unowned
        
        // Guaranteed item at pack's minimum rarity
        let qualifiedPool = pool.filter { rarityOrdinal($0.rarity) >= rarityOrdinal(pack.guaranteedRarity) }
        if let guaranteed = qualifiedPool.randomElement() {
            results.append(guaranteed)
            ownedCosmetics.insert(guaranteed.id)
        }
        
        // Fill remaining slots with weighted random
        for _ in 1..<pack.itemCount {
            if let item = weightedRandomItem(from: pool, excluding: Set(results.map(\.id))) {
                results.append(item)
                ownedCosmetics.insert(item.id)
            }
        }
        
        await saveOwned(uid: uid)
        lastPackResults = results
        
        print("📦 Opened \(pack.name): \(results.map(\.name))")
        return results
    }
    
    // MARK: - Card Re-Roll
    
    static let rerollPrice = 150  // Coins to re-roll a card's identification
    
    func canAffordReroll() -> Bool {
        UserService.shared.coins >= Self.rerollPrice
    }
    
    func spendRerollCoins() -> Bool {
        UserService.shared.spendCoins(Self.rerollPrice)
    }
    
    // MARK: - Helpers
    
    func isOwned(_ itemId: String) -> Bool {
        ownedCosmetics.contains(itemId)
    }
    
    func itemsOfType(_ type: CosmeticItem.CosmeticType) -> [CosmeticItem] {
        Self.allCosmetics.filter { $0.type == type }
    }
    
    func ownedItemsOfType(_ type: CosmeticItem.CosmeticType) -> [CosmeticItem] {
        Self.allCosmetics.filter { $0.type == type && ownedCosmetics.contains($0.id) }
    }
    
    private func saveOwned(uid: String) async {
        let docRef = db.collection("users").document(uid).collection("meta").document("coinShop")
        var data: [String: Any] = [
            "ownedCosmetics": Array(ownedCosmetics),
            "lastUpdated": Timestamp(date: Date())
        ]
        // Persist equipped state
        if let bg = equippedBackground { data["equippedBackground"] = bg }
        if let fr = equippedFrame { data["equippedFrame"] = fr }
        if let fx = equippedEffect { data["equippedEffect"] = fx }
        if let st = equippedSticker { data["equippedSticker"] = st }
        try? await docRef.setData(data, merge: true)
    }
    
    private func saveEquipped(uid: String) async {
        let docRef = db.collection("users").document(uid).collection("meta").document("coinShop")
        var data: [String: Any] = ["lastUpdated": Timestamp(date: Date())]
        data["equippedBackground"] = equippedBackground as Any
        data["equippedFrame"] = equippedFrame as Any
        data["equippedEffect"] = equippedEffect as Any
        data["equippedSticker"] = equippedSticker as Any
        try? await docRef.setData(data, merge: true)
        saveEquippedLocally()
    }
    
    private func saveEquippedLocally() {
        UserDefaults.standard.set(equippedBackground, forKey: "equipped_background")
        UserDefaults.standard.set(equippedFrame, forKey: "equipped_frame")
        UserDefaults.standard.set(equippedEffect, forKey: "equipped_effect")
        UserDefaults.standard.set(equippedSticker, forKey: "equipped_sticker")
    }
    
    // MARK: - Equip / Unequip
    
    func equipItem(_ item: CosmeticItem) {
        guard ownedCosmetics.contains(item.id) else { return }
        
        switch item.type {
        case .cardBackground: equippedBackground = item.id
        case .profileFrame:   equippedFrame = item.id
        case .captureEffect:  equippedEffect = item.id
        case .cardSticker:    equippedSticker = item.id
        }
        
        saveEquippedLocally()
        if let uid = FirebaseManager.shared.currentUserId {
            Task { await saveEquipped(uid: uid) }
        }
        print("✨ Equipped \(item.name)")
    }
    
    func unequipType(_ type: CosmeticItem.CosmeticType) {
        switch type {
        case .cardBackground: equippedBackground = nil
        case .profileFrame:   equippedFrame = nil
        case .captureEffect:  equippedEffect = nil
        case .cardSticker:    equippedSticker = nil
        }
        
        saveEquippedLocally()
        if let uid = FirebaseManager.shared.currentUserId {
            Task { await saveEquipped(uid: uid) }
        }
    }
    
    func isEquipped(_ itemId: String) -> Bool {
        equippedBackground == itemId ||
        equippedFrame == itemId ||
        equippedEffect == itemId ||
        equippedSticker == itemId
    }
    
    /// Get the CosmeticItem for an equipped type, if any
    func equippedItem(for type: CosmeticItem.CosmeticType) -> CosmeticItem? {
        let id: String?
        switch type {
        case .cardBackground: id = equippedBackground
        case .profileFrame:   id = equippedFrame
        case .captureEffect:  id = equippedEffect
        case .cardSticker:    id = equippedSticker
        }
        guard let itemId = id else { return nil }
        return Self.allCosmetics.first { $0.id == itemId }
    }
    
    private func rarityOrdinal(_ rarity: CosmeticItem.CosmeticRarity) -> Int {
        switch rarity {
        case .common: return 0
        case .rare: return 1
        case .epic: return 2
        case .legendary: return 3
        }
    }
    
    private func weightedRandomItem(from pool: [CosmeticItem], excluding: Set<String>) -> CosmeticItem? {
        let filtered = pool.filter { !excluding.contains($0.id) }
        guard !filtered.isEmpty else { return pool.randomElement() }
        
        // Weight: common=40, rare=30, epic=20, legendary=10
        let weighted = filtered.flatMap { item -> [CosmeticItem] in
            let count: Int = {
                switch item.rarity {
                case .common: return 4
                case .rare: return 3
                case .epic: return 2
                case .legendary: return 1
                }
            }()
            return Array(repeating: item, count: count)
        }
        
        return weighted.randomElement()
    }
    
    private func dayStringFrom(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func seedFromString(_ s: String) -> Int {
        var hash = 5381
        for char in s.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(char)
        }
        return abs(hash)
    }
}
