//
//  HotCardsService.swift
//  CarCardCollector
//
//  Service to fetch cards with the most heat globally
//

import SwiftUI
import FirebaseFirestore

class HotCardsService: ObservableObject {
    @Published var hotCards: [FriendActivity] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // Fetch top cards with most heat from all users
    func fetchHotCards(limit: Int = 10) {
        isLoading = true
        
        // Remove existing listener
        listener?.remove()
        
        // Query all activities ordered by heat count
        listener = db.collection("friend_activities")
            .order(by: "heatCount", descending: true)
            .limit(to: limit)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching hot cards: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }
                
                self.hotCards = documents.compactMap { doc -> FriendActivity? in
                    return FriendActivity(document: doc)
                }
                
                self.isLoading = false
                print("🔥 Loaded \(self.hotCards.count) hot cards")
            }
    }
    
    // Clean up listener
    deinit {
        listener?.remove()
    }
}
