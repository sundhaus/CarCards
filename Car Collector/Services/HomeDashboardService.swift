//
//  HomeDashboardService.swift
//  CarCardCollector
//
//  Aggregates dashboard data for the Home tab: crown card, weekly stats,
//  recent friend activity, and quest progress.
//

import Foundation
import FirebaseFirestore
import UIKit
import Combine

// MARK: - Quest Model

struct ActiveQuest: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let progress: Int        // Current progress (e.g. 2 of 5)
    let target: Int          // Target count
    let rewardCoins: Int
    let rewardXP: Int
    
    var isComplete: Bool { progress >= target }
    var progressFraction: Double { target > 0 ? Double(min(progress, target)) / Double(target) : 0 }
}

// MARK: - Weekly Stats

struct WeeklyStats {
    var cardsThisWeek: Int = 0
    var h2hWins: Int = 0
    var h2hTotal: Int = 0
    var heatsReceived: Int = 0
}

@MainActor
class HomeDashboardService: ObservableObject {
    static let shared = HomeDashboardService()
    
    // Crown card
    @Published var crownCard: CloudCard?
    @Published var crownCardImage: UIImage?
    @Published var isLoadingCrown = false
    
    // Weekly stats
    @Published var weeklyStats = WeeklyStats()
    
    // Active quests
    @Published var quests: [ActiveQuest] = []
    
    // Recent friend feed (last 3)
    @Published var recentFeed: [FriendActivity] = []
    @Published var isLoadingFeed = false
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var lastFetchTime: Date?
    
    private init() {
        // Listen for profile changes to refresh crown card
        UserService.shared.$currentProfile
            .compactMap { $0 }
            .removeDuplicates { $0.crownCardId == $1.crownCardId }
            .sink { [weak self] profile in
                Task { await self?.loadCrownCard(for: profile) }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Refresh All Dashboard Data
    
    func refreshAll() async {
        // Debounce: skip if refreshed in last 10 seconds
        if let last = lastFetchTime, Date().timeIntervalSince(last) < 10 { return }
        lastFetchTime = Date()
        
        async let crownTask: () = loadCrownCardIfNeeded()
        async let statsTask: () = loadWeeklyStats()
        async let questsTask: () = loadQuests()
        async let feedTask: () = loadRecentFeed()
        
        _ = await (crownTask, statsTask, questsTask, feedTask)
    }
    
    // MARK: - Crown Card
    
    private func loadCrownCardIfNeeded() async {
        guard let profile = UserService.shared.currentProfile else { return }
        await loadCrownCard(for: profile)
    }
    
    private func loadCrownCard(for profile: UserProfile) async {
        guard let crownId = profile.crownCardId, !crownId.isEmpty else {
            crownCard = nil
            crownCardImage = nil
            return
        }
        
        // Skip if already loaded for same card
        if crownCard?.id == crownId, crownCardImage != nil { return }
        
        isLoadingCrown = true
        defer { isLoadingCrown = false }
        
        do {
            let doc = try await db.collection("cards").document(crownId).getDocument()
            guard let card = CloudCard(document: doc) else {
                print("⭐ Dashboard: Crown card document not found")
                return
            }
            crownCard = card
            
            // Load image — prefer flat image
            let imageURL = card.flatImageURL ?? card.imageURL
            if !imageURL.isEmpty {
                crownCardImage = try? await CardService.shared.loadImage(from: imageURL)
            }
            
            print("⭐ Dashboard: Crown card loaded — \(card.make) \(card.model)")
        } catch {
            print("❌ Dashboard: Failed to load crown card: \(error)")
        }
    }
    
    // MARK: - Weekly Stats
    
    private func loadWeeklyStats() async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        // Start of current week (Sunday or Monday depending on locale)
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        var stats = WeeklyStats()
        
        do {
            // Cards captured this week
            let cardsSnapshot = try await db.collection("cards")
                .whereField("ownerId", isEqualTo: uid)
                .whereField("capturedDate", isGreaterThanOrEqualTo: Timestamp(date: weekStart))
                .getDocuments()
            stats.cardsThisWeek = cardsSnapshot.count
            
            // H2H races finished this week involving this user
            let racesSnapshot = try await db.collection("races")
                .whereField("status", isEqualTo: "finished")
                .whereField("finishedAt", isGreaterThanOrEqualTo: Timestamp(date: weekStart))
                .limit(to: 50)
                .getDocuments()
            
            for doc in racesSnapshot.documents {
                let data = doc.data()
                let challengerId = data["challengerId"] as? String ?? ""
                let defenderId = data["defenderId"] as? String ?? ""
                let winnerId = data["winnerId"] as? String ?? ""
                
                if challengerId == uid || defenderId == uid {
                    stats.h2hTotal += 1
                    if winnerId == uid {
                        stats.h2hWins += 1
                    }
                }
            }
            
            // Heats received this week on user's cards
            let heatSnapshot = try await db.collection("friend_activities")
                .whereField("userId", isEqualTo: uid)
                .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: weekStart))
                .getDocuments()
            
            for doc in heatSnapshot.documents {
                let heatCount = doc.data()["heatCount"] as? Int ?? 0
                stats.heatsReceived += heatCount
            }
        } catch {
            print("❌ Dashboard: Failed to load weekly stats: \(error)")
        }
        
        weeklyStats = stats
    }
    
    // MARK: - Active Quests (locally computed from user state)
    
    private func loadQuests() async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        var questList: [ActiveQuest] = []
        
        // Quest 1: Capture cards this week
        let capturedThisWeek = weeklyStats.cardsThisWeek
        questList.append(ActiveQuest(
            id: "weekly_capture",
            title: "Weekly Collector",
            description: "Capture 5 cards this week",
            icon: "camera.fill",
            progress: min(capturedThisWeek, 5),
            target: 5,
            rewardCoins: 500,
            rewardXP: 100
        ))
        
        // Quest 2: Win H2H battles
        let h2hWins = weeklyStats.h2hWins
        questList.append(ActiveQuest(
            id: "weekly_h2h",
            title: "Race Champion",
            description: "Win 3 Head-to-Head battles",
            icon: "bolt.fill",
            progress: min(h2hWins, 3),
            target: 3,
            rewardCoins: 750,
            rewardXP: 150
        ))
        
        // Quest 3: Get heats on your cards
        let heatsReceived = weeklyStats.heatsReceived
        questList.append(ActiveQuest(
            id: "weekly_heat",
            title: "Hot Ride",
            description: "Earn 10 heats on your cards",
            icon: "flame.fill",
            progress: min(heatsReceived, 10),
            target: 10,
            rewardCoins: 300,
            rewardXP: 75
        ))
        
        quests = questList
    }
    
    // MARK: - Recent Friend Feed
    
    private func loadRecentFeed() async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        isLoadingFeed = true
        defer { isLoadingFeed = false }
        
        do {
            // Get users I follow
            let followsSnapshot = try await db.collection("follows")
                .whereField("followerId", isEqualTo: uid)
                .getDocuments()
            
            let followingIds = followsSnapshot.documents.compactMap {
                $0.data()["followingId"] as? String
            }
            
            guard !followingIds.isEmpty else {
                recentFeed = []
                return
            }
            
            // Fetch latest 3 activities from followed users
            // Firestore `in` query limited to 30 items
            let queryIds = Array(followingIds.prefix(30))
            let activitySnapshot = try await db.collection("friend_activities")
                .whereField("userId", in: queryIds)
                .order(by: "createdAt", descending: true)
                .limit(to: 3)
                .getDocuments()
            
            recentFeed = activitySnapshot.documents.compactMap { FriendActivity(document: $0) }
            
            print("📰 Dashboard: Loaded \(recentFeed.count) recent feed items")
        } catch {
            print("❌ Dashboard: Failed to load recent feed: \(error)")
        }
    }
    
    // MARK: - Force Refresh
    
    func forceRefresh() async {
        lastFetchTime = nil
        await refreshAll()
    }
}
