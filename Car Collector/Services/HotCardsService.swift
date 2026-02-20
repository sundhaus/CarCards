//
//  HotCardsService.swift
//  CarCardCollector
//
//  Service to fetch cards with the most heat (likes) globally
//  - Carousel shows top 10 most liked cards, refreshes every 12 hours
//  - Once a card appears in the carousel, it's added to the "featured" collection permanently
//  - The Explore featured page shows ALL cards that have ever been in the carousel
//

import SwiftUI
import FirebaseFirestore

class HotCardsService: ObservableObject {
    static let shared = HotCardsService()
    
    @Published var hotCards: [FriendActivity] = []  // Current carousel (max 10)
    @Published var allFeaturedCards: [FriendActivity] = []  // All-time featured
    @Published var isLoading = false
    @Published var timeUntilNextRefresh: String = ""
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var countdownTimer: Timer?
    
    private let lastRefreshKey = "hotCardsLastRefresh"
    private let refreshInterval: TimeInterval = 12 * 60 * 60  // 12 hours
    private let carouselLimit = 10
    
    private var timerStarted = false
    
    init() {}
    
    // MARK: - Timer
    
    private func nextRefreshTime() -> Date {
        guard let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date else {
            return Date()  // Never refreshed, refresh now
        }
        return lastRefresh.addingTimeInterval(refreshInterval)
    }
    
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
    
    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
        countdownTimer?.fire()
    }
    
    private func shouldRefresh() -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date else {
            return true
        }
        return Date() >= lastRefresh.addingTimeInterval(refreshInterval)
    }
    
    // MARK: - Public API
    
    func fetchHotCardsIfNeeded() {
        if !timerStarted {
            timerStarted = true
            startCountdownTimer()
        }
        
        if hotCards.isEmpty || shouldRefresh() {
            print("🔄 Refreshing hot cards carousel")
            fetchHotCards()
        } else {
            print("⏱️ Carousel still fresh — next refresh at \(nextRefreshTime())")
        }
        
        // Always load the all-time featured list
        if allFeaturedCards.isEmpty {
            loadAllFeatured()
        }
    }
    
    func forceRefresh() {
        print("🔄 Force refreshing hot cards")
        fetchHotCards()
    }
    
    // MARK: - Fetch Carousel (top 10 by heat)
    
    private func fetchHotCards() {
        isLoading = true
        UserDefaults.standard.set(Date(), forKey: lastRefreshKey)
        
        listener?.remove()
        
        print("🔍 Fetching top \(carouselLimit) cards by heat...")
        
        db.collection("friend_activities")
            .whereField("heatCount", isGreaterThan: 0)
            .order(by: "heatCount", descending: true)
            .limit(to: carouselLimit)
            .getDocuments { [weak self] snapshot, error in
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
                    guard let activity = FriendActivity(document: doc) else { return nil }
                    return activity.heatCount > 0 ? activity : nil
                }
                
                self.isLoading = false
                print("🔥 Carousel: \(self.hotCards.count) cards")
                
                // Persist these cards to the featured collection
                self.persistToFeatured(self.hotCards)
            }
    }
    
    // MARK: - Featured Persistence
    
    /// Add current carousel cards to the all-time featured collection
    private func persistToFeatured(_ cards: [FriendActivity]) {
        let batch = db.batch()
        
        for card in cards {
            // Use activityId as doc ID so duplicates just overwrite
            let docRef = db.collection("featured_cards").document(card.id)
            batch.setData([
                "activityId": card.id,
                "cardId": card.cardId,
                "userId": card.userId,
                "username": card.username,
                "cardMake": card.cardMake,
                "cardModel": card.cardModel,
                "cardYear": card.cardYear,
                "imageURL": card.imageURL,
                "heatCount": card.heatCount,
                "heatedBy": card.heatedBy,
                "customFrame": card.customFrame ?? "",
                "addedToFeatured": FieldValue.serverTimestamp()
            ], forDocument: docRef, merge: true)
        }
        
        batch.commit { error in
            if let error = error {
                print("❌ Failed to persist featured cards: \(error)")
            } else {
                print("⭐ Persisted \(cards.count) cards to featured collection")
                // Reload the full featured list
                self.loadAllFeatured()
            }
        }
    }
    
    /// Load ALL cards that have ever been featured
    func loadAllFeatured() {
        db.collection("featured_cards")
            .order(by: "heatCount", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Failed to load all featured: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.allFeaturedCards = documents.compactMap { doc -> FriendActivity? in
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
                
                print("⭐ All-time featured: \(self.allFeaturedCards.count) cards")
            }
    }
    
    deinit {
        listener?.remove()
        countdownTimer?.invalidate()
    }
}
