//
//  HotCardsService.swift
//  CarCardCollector
//
//  Service to fetch cards with the most heat (likes) globally
//  - Shows top 20 most liked cards from ALL users
//  - Updates in real-time as likes change (snapshot listener)
//  - Full refresh every 24 hours to reset timestamp
//  - Cards can move in/out of top 20 as other cards get more likes
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
    
    // 5 minutes in seconds (instead of 24 hours - likes change frequently)
    private let refreshInterval: TimeInterval = 5 * 60
    
    // Check if cards need refresh and fetch if needed
    func fetchHotCardsIfNeeded(limit: Int = 10) {
        // Always refresh if we have no cards OR if 5 minutes passed
        if hotCards.isEmpty || shouldRefresh() {
            if hotCards.isEmpty {
                print("🔄 No hot cards loaded - fetching fresh data")
            } else {
                print("🔄 5 minutes passed - refreshing hot cards")
            }
            fetchHotCards(limit: limit, updateTimestamp: true)
        } else {
            let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date ?? Date()
            let timeUntilRefresh = refreshInterval - Date().timeIntervalSince(lastRefresh)
            let minutesUntilRefresh = Int(timeUntilRefresh / 60)
            print("⏱️ Hot cards still fresh - next refresh in ~\(minutesUntilRefresh) minutes")
        }
    }
    
    // Force refresh (call this to reset the 5-minute timer)
    func forceRefresh(limit: Int = 10) {
        print("🔄 Force refreshing hot cards")
        fetchHotCards(limit: limit, updateTimestamp: true)
    }
    
    // Reset the refresh timer (will trigger refresh on next fetchHotCardsIfNeeded call)
    func resetRefreshTimer() {
        UserDefaults.standard.removeObject(forKey: lastRefreshKey)
        print("🔄 Reset hot cards refresh timer")
    }
    
    // Check if 5 minutes have passed since last refresh
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
        
        print("🔍 Fetching top \(limit) cards globally by heat count (likes > 0)...")
        
        // Query ALL activities from ALL users ordered by heat count (likes)
        // Filter for heatCount > 0 to exclude cards with no heat
        listener = db.collection("friend_activities")
            .whereField("heatCount", isGreaterThan: 0)
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
                
                // Filter out any cards with 0 heat (double-check on client side)
                self.hotCards = documents.compactMap { doc -> FriendActivity? in
                    guard let activity = FriendActivity(document: doc) else { return nil }
                    // Only include cards with heat > 0
                    return activity.heatCount > 0 ? activity : nil
                }
                
                self.isLoading = false
                print("🔥 Loaded \(self.hotCards.count) hot cards globally (filtered for heat > 0)")
                if let topCard = self.hotCards.first {
                    print("🔥 Top card: \(topCard.cardMake) \(topCard.cardModel) with \(topCard.heatCount) likes")
                }
                
                // Real-time updates enabled - cards will update as likes change
                if !updateTimestamp {
                    print("📡 Real-time updates active - cards will refresh as likes change")
                }
            }
    }
    
    // Clean up listener
    deinit {
        listener?.remove()
    }
}
