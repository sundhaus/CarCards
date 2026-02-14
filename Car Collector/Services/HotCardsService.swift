//
//  HotCardsService.swift
//  CarCardCollector
//
//  Service to fetch cards with the most heat globally
//  Refreshes every 24 hours automatically
//

import SwiftUI
import FirebaseFirestore

class HotCardsService: ObservableObject {
    @Published var hotCards: [FriendActivity] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // UserDefaults key for last refresh timestamp
    private let lastRefreshKey = "hotCardsLastRefresh"
    
    // 24 hours in seconds
    private let refreshInterval: TimeInterval = 24 * 60 * 60
    
    // Check if cards need refresh and fetch if needed
    func fetchHotCardsIfNeeded(limit: Int = 10) {
        // Always refresh if we have no cards OR if 24 hours passed
        if hotCards.isEmpty || shouldRefresh() {
            if hotCards.isEmpty {
                print("🔄 No hot cards loaded - fetching fresh data")
            } else {
                print("🔄 24 hours passed - refreshing hot cards")
            }
            fetchHotCards(limit: limit, updateTimestamp: true)
        } else {
            let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date ?? Date()
            let timeUntilRefresh = refreshInterval - Date().timeIntervalSince(lastRefresh)
            let hoursUntilRefresh = Int(timeUntilRefresh / 3600)
            print("⏱️ Hot cards still fresh - next refresh in ~\(hoursUntilRefresh) hours")
        }
    }
    
    // Force refresh (call this to reset the 24-hour timer)
    func forceRefresh(limit: Int = 10) {
        print("🔄 Force refreshing hot cards")
        fetchHotCards(limit: limit, updateTimestamp: true)
    }
    
    // Reset the refresh timer (will trigger refresh on next fetchHotCardsIfNeeded call)
    func resetRefreshTimer() {
        UserDefaults.standard.removeObject(forKey: lastRefreshKey)
        print("🔄 Reset hot cards refresh timer")
    }
    
    // Check if 24 hours have passed since last refresh
    private func shouldRefresh() -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date else {
            // Never refreshed before
            return true
        }
        
        let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
        return timeSinceRefresh >= refreshInterval
    }
    
    // Fetch top cards with most heat from all users
    private func fetchHotCards(limit: Int = 10, updateTimestamp: Bool = true) {
        isLoading = true
        
        // Update timestamp if requested
        if updateTimestamp {
            UserDefaults.standard.set(Date(), forKey: lastRefreshKey)
            print("✅ Updated hot cards refresh timestamp")
        }
        
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
