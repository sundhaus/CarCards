//
//  HotCardsService.swift
//  CarCardCollector
//
//  Service to fetch cards with the most heat (likes) globally
//  - Shows top 20 most liked cards from ALL users
//  - Updates in real-time as likes change (snapshot listener)
//  - Full refresh twice daily at 12:00 PM and 12:00 AM EST
//  - Cards can move in/out of top 20 as other cards get more likes
//

import SwiftUI
import FirebaseFirestore

class HotCardsService: ObservableObject {
    @Published var hotCards: [FriendActivity] = []
    @Published var isLoading = false
    @Published var timeUntilNextRefresh: String = ""
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var countdownTimer: Timer?
    
    // UserDefaults key for last refresh timestamp
    private let lastRefreshKey = "hotCardsLastRefresh"
    
    init() {
        startCountdownTimer()
    }
    
    // Calculate next refresh time (noon or midnight EST)
    private func nextRefreshTime() -> Date {
        let calendar = Calendar.current
        var estTimeZone = TimeZone(identifier: "America/New_York")!
        
        // Get current time in EST
        var components = calendar.dateComponents(in: estTimeZone, from: Date())
        
        // Determine if we should refresh at next noon or midnight
        let currentHour = components.hour ?? 0
        
        if currentHour < 12 {
            // Before noon - next refresh is noon today
            components.hour = 12
            components.minute = 0
            components.second = 0
        } else {
            // After noon - next refresh is midnight tonight
            components.hour = 0
            components.minute = 0
            components.second = 0
            // Add one day
            if let date = calendar.date(from: components) {
                return calendar.date(byAdding: .day, value: 1, to: date) ?? Date()
            }
        }
        
        return calendar.date(from: components) ?? Date()
    }
    
    // Format countdown string
    private func formatCountdown(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
    
    // Start countdown timer (updates every second)
    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let nextRefresh = self.nextRefreshTime()
            let timeRemaining = nextRefresh.timeIntervalSince(Date())
            
            if timeRemaining <= 0 {
                // Time for refresh!
                self.timeUntilNextRefresh = "Refreshing..."
                self.forceRefresh()
            } else {
                self.timeUntilNextRefresh = self.formatCountdown(seconds: timeRemaining)
            }
        }
        
        // Trigger immediate update
        countdownTimer?.fire()
    }
    
    // Check if we should refresh based on noon/midnight EST schedule
    private func shouldRefresh() -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date else {
            return true // Never refreshed
        }
        
        let nextRefresh = nextRefreshTime()
        
        // If last refresh was before the most recent noon/midnight, we should refresh
        return lastRefresh < nextRefresh
    }
    
    // Check if cards need refresh and fetch if needed
    func fetchHotCardsIfNeeded(limit: Int = 20) {
        // Always refresh if we have no cards OR if it's time for scheduled refresh
        if hotCards.isEmpty || shouldRefresh() {
            if hotCards.isEmpty {
                print("🔄 No hot cards loaded - fetching fresh data")
            } else {
                print("🔄 Scheduled refresh time - refreshing hot cards")
            }
            fetchHotCards(limit: limit, updateTimestamp: true)
        } else {
            print("⏱️ Hot cards still fresh - next refresh at \(nextRefreshTime())")
        }
    }
    
    // Force refresh (call this to trigger immediate refresh)
    func forceRefresh(limit: Int = 20) {
        print("🔄 Force refreshing hot cards")
        fetchHotCards(limit: limit, updateTimestamp: true)
    }
    
    // Reset the refresh timer (will trigger refresh on next fetchHotCardsIfNeeded call)
    func resetRefreshTimer() {
        UserDefaults.standard.removeObject(forKey: lastRefreshKey)
        print("🔄 Reset hot cards refresh timer")
    }
    
    // Fetch top cards with most heat from all users
    private func fetchHotCards(limit: Int = 20, updateTimestamp: Bool = true) {
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
    
    // Clean up listener and timer
    deinit {
        listener?.remove()
        countdownTimer?.invalidate()
    }
}
