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
        
        // First, check if ANY documents exist with this category (debug) - force server read
        db.collection("friend_activities")
            .whereField("category", isEqualTo: category.rawValue)
            .limit(to: 3)
            .getDocuments(source: .server) { snapshot, error in
                if let documents = snapshot?.documents, !documents.isEmpty {
                    print("   🔍 DEBUG: Found \(documents.count) docs with category '\(category.rawValue)' (no heatCount filter)")
                    documents.forEach { doc in
                        let data = doc.data()
                        print("      - \(data["cardMake"] ?? "") \(data["cardModel"] ?? "") (heat: \(data["heatCount"] ?? 0))")
                    }
                } else {
                    print("   ⚠️ DEBUG: NO documents found with category '\(category.rawValue)' at all!")
                }
            }
        
        // Now do the actual query with heatCount ordering - force server read
        db.collection("friend_activities")
            .whereField("category", isEqualTo: category.rawValue)
            .order(by: "heatCount", descending: true)
            .limit(to: limit)
            .getDocuments(source: .server) { snapshot, error in
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
                
                print("   📄 Got \(documents.count) documents for \(category.rawValue) (from SERVER)")
                
                let activities = documents.compactMap { FriendActivity(document: $0) }
                print("   ✅ Parsed \(activities.count) activities for \(category.rawValue)")
                
                completion(activities)
            }
    }
    
    // Fetch paginated cards for category detail view
    func fetchCategoryCardsPaginated(category: VehicleCategory, startAfter: DocumentSnapshot?, limit: Int, completion: @escaping ([FriendActivity], DocumentSnapshot?) -> Void) {
        var query = db.collection("friend_activities")
            .whereField("category", isEqualTo: category.rawValue)
            .order(by: "heatCount", descending: true)
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
        print("   🔎 Querying Featured (top 10 by heat)")
        
        db.collection("friend_activities")
            .order(by: "heatCount", descending: true)
            .limit(to: cardsPerCategory)
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
                
                print("   📄 Got \(documents.count) documents for Featured")
                
                let activities = documents.compactMap { doc -> FriendActivity? in
                    let activity = FriendActivity(document: doc)
                    if let act = activity {
                        print("      - \(act.cardMake) \(act.cardModel) (heat: \(act.heatCount))")
                    }
                    return activity
                }
                print("   ✅ Parsed \(activities.count) featured activities")
                
                completion(activities)
            }
    }
    
    // Fetch paginated featured cards
    func fetchFeaturedCardsPaginated(startAfter: DocumentSnapshot?, limit: Int, completion: @escaping ([FriendActivity], DocumentSnapshot?) -> Void) {
        var query = db.collection("friend_activities")
            .order(by: "heatCount", descending: true)
            .limit(to: limit)
        
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
            
            let activities = documents.compactMap { FriendActivity(document: $0) }
            let lastDocument = documents.last
            
            completion(activities, lastDocument)
        }
    }
}
