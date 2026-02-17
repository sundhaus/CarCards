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
                print("   ✅ Parsed \(activities.count) activities for \(category.rawValue)")
                
                // Sort by heat in memory and take top N
                let sorted = activities.sorted { $0.heatCount > $1.heatCount }
                let topCards = Array(sorted.prefix(limit))
                
                print("   🔥 Returning top \(topCards.count) cards by heat")
                
                completion(topCards)
            }
    }
    
    // Fetch paginated cards for category detail view
    func fetchCategoryCardsPaginated(category: VehicleCategory, startAfter: DocumentSnapshot?, limit: Int, completion: @escaping ([FriendActivity], DocumentSnapshot?) -> Void) {
        var query = db.collection("friend_activities")
            .whereField("category", isEqualTo: category.rawValue)
            .limit(to: limit)
        
        // If we have a starting point, start after it
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
            let lastDocument = documents.last
            
            completion(activities, lastDocument)
        }
    }
    
    // Fetch featured cards (top cards by heat, any category)
    private func fetchFeaturedCards(completion: @escaping ([FriendActivity]) -> Void) {
        print("   🔎 Querying Featured (all cards, will sort by heat)")
        
        // Get ALL cards, sort by heat in memory
        db.collection("friend_activities")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("   ❌ Featured query error: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("   ❌ No snapshot for Featured")
                    completion([])
                    return
                }
                
                print("   📄 Got \(documents.count) total documents")
                
                // Parse all
                let activities = documents.compactMap { FriendActivity(document: $0) }
                
                // Sort by heat and take top N
                let sorted = activities.sorted { $0.heatCount > $1.heatCount }
                let featured = Array(sorted.prefix(self.cardsPerCategory))
                
                print("   ✅ Returning top \(featured.count) by heat")
                featured.prefix(3).forEach { card in
                    print("      - \(card.cardMake) \(card.cardModel) (heat: \(card.heatCount))")
                }
                
                completion(featured)
            }
    }
    
    // Fetch paginated featured cards
    func fetchFeaturedCardsPaginated(startAfter: DocumentSnapshot?, limit: Int, completion: @escaping ([FriendActivity], DocumentSnapshot?) -> Void) {
        var query = db.collection("friend_activities")
            .limit(to: limit * 2) // Get more to sort in memory
        
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
            
            // Parse and sort by heat
            let activities = documents.compactMap { FriendActivity(document: $0) }
            let sorted = activities.sorted { $0.heatCount > $1.heatCount }
            let topCards = Array(sorted.prefix(limit))
            
            let lastDocument = documents.last
            
            completion(topCards, lastDocument)
        }
    }
}
