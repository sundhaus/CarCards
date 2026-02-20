//
//  ExploreService.swift
//  CarCardCollector
//
//  Service for Explore page - shows top cards by heat for each category
//  Auto-updates when new cards are added
//

import SwiftUI
import FirebaseFirestore

class ExploreService: ObservableObject {
    @Published var cardsByCategory: [VehicleCategory: [FriendActivity]] = [:]
    @Published var featuredCards: [FriendActivity] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    // How many cards to show per category in explore preview
    private let cardsPerCategory = 10
    
    init() {
        // Auto-load on init
        fetchAllCategories()
    }
    
    // Fetch top cards for all categories
    func fetchAllCategories() {
        isLoading = true
        print("\n🔍 EXPLORE: Starting to fetch all categories")
        
        var tempCardsByCategory: [VehicleCategory: [FriendActivity]] = [:]
        let group = DispatchGroup()
        
        // Fetch featured cards
        group.enter()
        fetchFeaturedCards { cards in
            print("🌟 FEATURED: Got \(cards.count) cards")
            if cards.isEmpty {
                print("   ⚠️ Featured is empty!")
            } else {
                cards.prefix(3).forEach { card in
                    print("   - \(card.cardMake) \(card.cardModel) (heat: \(card.heatCount))")
                }
            }
            self.featuredCards = cards
            group.leave()
        }
        
        // Fetch for each category
        for category in VehicleCategory.allCases {
            group.enter()
            
            fetchCategoryCards(category: category, limit: cardsPerCategory) { cards in
                if !cards.isEmpty {
                    tempCardsByCategory[category] = cards
                    print("🎯 \(category.rawValue): Got \(cards.count) cards")
                    cards.prefix(2).forEach { card in
                        print("   - \(card.cardMake) \(card.cardModel)")
                    }
                } else {
                    print("❌ \(category.rawValue): EMPTY")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.cardsByCategory = tempCardsByCategory
            self.isLoading = false
            print("\n✅ EXPLORE: Finished loading")
            print("   📊 Featured: \(self.featuredCards.count) cards")
            print("   📊 Categories with cards: \(tempCardsByCategory.count)")
            print("   📊 Total cards: \(tempCardsByCategory.values.reduce(0) { $0 + $1.count })")
        }
    }
    
    // Fetch top cards for a specific category (ordered by heat)
    func fetchCategoryCards(category: VehicleCategory, limit: Int, completion: @escaping ([FriendActivity]) -> Void) {
        print("   🔎 Querying category: \(category.rawValue)")
        
        // Simple query - just filter by category, NO ordering in Firebase
        db.collection("friend_activities")
            .whereField("category", isEqualTo: category.rawValue)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("   ❌ Query error for \(category.rawValue): \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("   ❌ No snapshot for \(category.rawValue)")
                    completion([])
                    return
                }
                
                print("   📄 Got \(documents.count) documents for \(category.rawValue)")
                
                // Parse all activities
                let activities = documents.compactMap { FriendActivity(document: $0) }
                
                // Deduplicate by cardId — same card can appear in multiple friend feeds
                let deduped = Self.deduplicateByCardId(activities)
                print("   ✅ \(activities.count) activities → \(deduped.count) unique for \(category.rawValue)")
                
                // Sort by heat in memory and take top N
                let sorted = deduped.sorted { $0.heatCount > $1.heatCount }
                let topCards = Array(sorted.prefix(limit))
                
                print("   🔥 Returning top \(topCards.count) cards by heat")
                
                completion(topCards)
            }
    }
    
    // Fetch paginated cards for category detail view
    func fetchCategoryCardsPaginated(category: VehicleCategory, startAfter: DocumentSnapshot?, limit: Int, completion: @escaping ([FriendActivity], DocumentSnapshot?) -> Void) {
        var query = db.collection("friend_activities")
            .whereField("category", isEqualTo: category.rawValue)
            .limit(to: limit * 3)  // Fetch extra to account for dedup
        
        if let lastDoc = startAfter {
            query = query.start(afterDocument: lastDoc)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching paginated \(category.rawValue): \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion([], nil)
                return
            }
            
            let activities = documents.compactMap { FriendActivity(document: $0) }
            let deduped = Self.deduplicateByCardId(activities)
            let sorted = deduped.sorted { $0.heatCount > $1.heatCount }
            let topCards = Array(sorted.prefix(limit))
            let lastDocument = documents.last
            
            completion(topCards, lastDocument)
        }
    }
    
    // Fetch featured cards — all cards that have EVER been in the hot carousel
    private func fetchFeaturedCards(completion: @escaping ([FriendActivity]) -> Void) {
        print("   🔎 Querying Featured (all-time from featured_cards)")
        
        // Try all-time featured from HotCardsService memory first
        let allFeatured = HotCardsService.shared.allFeaturedCards
        if !allFeatured.isEmpty {
            let deduped = Self.deduplicateByCardId(allFeatured)
            let sorted = deduped.sorted { $0.heatCount > $1.heatCount }
            let featured = Array(sorted.prefix(self.cardsPerCategory))
            print("   ⭐ All-time featured (memory): \(featured.count)")
            completion(featured)
            return
        }
        
        // Try featured_cards collection in Firestore
        db.collection("featured_cards")
            .order(by: "heatCount", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    let activities = documents.compactMap { doc -> FriendActivity? in
                        let data = doc.data()
                        return FriendActivity(
                            id: data["activityId"] as? String ?? doc.documentID,
                            userId: data["userId"] as? String ?? "",
                            username: data["username"] as? String ?? "",
                            cardId: data["cardId"] as? String ?? "",
                            cardMake: data["cardMake"] as? String ?? "",
                            cardModel: data["cardModel"] as? String ?? "",
                            cardYear: data["cardYear"] as? String ?? "",
                            imageURL: data["imageURL"] as? String ?? "",
                            heatCount: data["heatCount"] as? Int ?? 0,
                            heatedBy: data["heatedBy"] as? [String] ?? [],
                            customFrame: data["customFrame"] as? String,
                            timestamp: (data["addedToFeatured"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    }
                    let deduped = Self.deduplicateByCardId(activities)
                    let featured = Array(deduped.prefix(self.cardsPerCategory))
                    print("   ⭐ All-time featured (Firestore): \(featured.count)")
                    completion(featured)
                    return
                }
                
                // Fallback: featured_cards empty (first run) — use current hot cards
                let hotCards = HotCardsService.shared.hotCards
                if !hotCards.isEmpty {
                    let deduped = Self.deduplicateByCardId(hotCards)
                    let sorted = deduped.sorted { $0.heatCount > $1.heatCount }
                    let featured = Array(sorted.prefix(self.cardsPerCategory))
                    print("   🔥 Fallback to current hot cards: \(featured.count)")
                    
                    // Also seed the featured_cards collection
                    HotCardsService.shared.loadAllFeatured()
                    completion(featured)
                } else {
                    print("   ⚠️ No featured cards available yet")
                    completion([])
                }
            }
    }
    
    // Fetch paginated featured cards (only hot cards with heat > 0)
    func fetchFeaturedCardsPaginated(startAfter: DocumentSnapshot?, limit: Int, completion: @escaping ([FriendActivity], DocumentSnapshot?) -> Void) {
        var query = db.collection("friend_activities")
            .order(by: "heatCount", descending: true)
            .limit(to: limit * 3)
        
        if let lastDoc = startAfter {
            query = query.start(afterDocument: lastDoc)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching paginated featured: \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion([], nil)
                return
            }
            
            let activities = documents.compactMap { FriendActivity(document: $0) }.filter { $0.heatCount > 0 }
            let deduped = Self.deduplicateByCardId(activities)
            let sorted = deduped.sorted { $0.heatCount > $1.heatCount }
            let topCards = Array(sorted.prefix(limit))
            let lastDocument = documents.last
            
            completion(topCards, lastDocument)
        }
    }
    
    // MARK: - Deduplication
    
    /// Deduplicate activities by cardId, keeping the entry with the highest heat count
    static func deduplicateByCardId(_ activities: [FriendActivity]) -> [FriendActivity] {
        var bestByCardId: [String: FriendActivity] = [:]
        
        for activity in activities {
            let key = activity.cardId
            if let existing = bestByCardId[key] {
                if activity.heatCount > existing.heatCount {
                    bestByCardId[key] = activity
                }
            } else {
                bestByCardId[key] = activity
            }
        }
        
        return Array(bestByCardId.values)
    }
}
