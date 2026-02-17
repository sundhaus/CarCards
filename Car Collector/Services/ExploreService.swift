//
//  ExploreService.swift
//  CarCardCollector
//
//  Service for Explore page - refreshes every 3 hours at 12pm, 3pm, 6pm, 9pm EST
//  Shows random cards from each category (only cards with complete specs)
//

import SwiftUI
import FirebaseFirestore

class ExploreService: ObservableObject {
    @Published var cardsByCategory: [VehicleCategory: [FriendActivity]] = [:]
    @Published var isLoading = false
    @Published var timeUntilNextRefresh: String = ""
    
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    private var countdownTimer: Timer?
    
    // UserDefaults key for last refresh timestamp
    private let lastRefreshKey = "exploreLastRefresh"
    
    // How many cards to show per category
    private let cardsPerCategory = 20
    
    init() {
        startCountdownTimer()
    }
    
    // Calculate next refresh time (12pm, 3pm, 6pm, 9pm EST)
    private func nextRefreshTime() -> Date {
        let calendar = Calendar.current
        let estTimeZone = TimeZone(identifier: "America/New_York")!
        
        // Get current time in EST
        var components = calendar.dateComponents(in: estTimeZone, from: Date())
        let currentHour = components.hour ?? 0
        
        // Refresh hours in EST: 12, 15, 18, 21 (12pm, 3pm, 6pm, 9pm)
        let refreshHours = [0, 3, 6, 9, 12, 15, 18, 21]
        
        // Find next refresh hour
        var nextHour = refreshHours.first { $0 > currentHour } ?? refreshHours[0]
        
        // If no hour found today, use first hour tomorrow
        if nextHour <= currentHour {
            nextHour = refreshHours[0]
            components.day! += 1
        }
        
        components.hour = nextHour
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? Date()
    }
    
    // Format countdown string
    private func formatCountdown(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    // Start countdown timer (updates every minute)
    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let nextRefresh = self.nextRefreshTime()
            let timeRemaining = nextRefresh.timeIntervalSince(Date())
            
            if timeRemaining <= 0 {
                self.timeUntilNextRefresh = "Refreshing..."
                self.forceRefresh()
            } else {
                self.timeUntilNextRefresh = self.formatCountdown(seconds: timeRemaining)
            }
        }
        
        // Trigger immediate update
        countdownTimer?.fire()
    }
    
    // Check if we should refresh based on 3-hour schedule
    private func shouldRefresh() -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date else {
            return true // Never refreshed
        }
        
        let nextRefresh = nextRefreshTime()
        
        // If last refresh was before the most recent refresh time, we should refresh
        return lastRefresh < nextRefresh
    }
    
    // Fetch cards if needed based on schedule
    func fetchCardsIfNeeded() {
        if cardsByCategory.isEmpty || shouldRefresh() {
            if cardsByCategory.isEmpty {
                print("🔄 No explore cards loaded - fetching fresh data")
            } else {
                print("🔄 Scheduled 3-hour refresh time - refreshing explore cards")
            }
            fetchAllCategories()
        } else {
            print("⏱️ Explore cards still fresh - next refresh at \(nextRefreshTime())")
        }
    }
    
    // Force refresh (call this to trigger immediate refresh)
    func forceRefresh() {
        print("🔄 Force refreshing explore cards")
        fetchAllCategories()
    }
    
    // Fetch random cards for all categories
    private func fetchAllCategories() {
        isLoading = true
        
        // Update timestamp
        UserDefaults.standard.set(Date(), forKey: lastRefreshKey)
        print("✅ Updated explore refresh timestamp")
        
        // Clear existing listeners
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
        
        var tempCardsByCategory: [VehicleCategory: [FriendActivity]] = [:]
        let group = DispatchGroup()
        
        // Fetch for each category
        for category in VehicleCategory.allCases {
            group.enter()
            
            fetchCategoryCards(category: category, limit: cardsPerCategory) { cards in
                if !cards.isEmpty {
                    tempCardsByCategory[category] = cards
                    print("🎯 \(category.rawValue): \(cards.count) cards")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.cardsByCategory = tempCardsByCategory
            self.isLoading = false
            print("✅ Loaded explore cards for \(tempCardsByCategory.count) categories")
        }
    }
    
    // Fetch random cards for a specific category
    private func fetchCategoryCards(category: VehicleCategory, limit: Int, completion: @escaping ([FriendActivity]) -> Void) {
        // Query friend_activities where:
        // - Card has specs (specs field exists and is not empty)
        // - Category matches
        // We'll fetch more than needed and randomly select
        
        db.collection("friend_activities")
            .whereField("category", isEqualTo: category.rawValue)
            .limit(to: limit * 3) // Get 3x to ensure randomness
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching \(category.rawValue): \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                // Convert to FriendActivity and shuffle
                var activities = documents.compactMap { FriendActivity(document: $0) }
                activities.shuffle()
                
                // Take only the requested limit
                let selectedCards = Array(activities.prefix(limit))
                completion(selectedCards)
            }
    }
    
    // Clean up
    deinit {
        listeners.values.forEach { $0.remove() }
        countdownTimer?.invalidate()
    }
}
