//
//  LeaderboardService.swift
//  CarCardCollector
//
//  Service to fetch and calculate leaderboard rankings
//

import Foundation
import FirebaseFirestore

struct LeaderboardEntry: Identifiable {
    let id: String
    let username: String
    let value: Int
    let isCurrentUser: Bool
}

@MainActor
class LeaderboardService: ObservableObject {
    static let shared = LeaderboardService()
    
    @Published var cardsLeaderboard: [LeaderboardEntry] = []
    @Published var heatLeaderboard: [LeaderboardEntry] = []
    @Published var earningsLeaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    init() {}
    
    // Fetch all leaderboards
    func fetchLeaderboards() {
        Task {
            isLoading = true
            
            async let cards = fetchCardsLeaderboard()
            async let heat = fetchHeatLeaderboard()
            async let earnings = fetchEarningsLeaderboard()
            
            let results = await (cards, heat, earnings)
            
            cardsLeaderboard = results.0
            heatLeaderboard = results.1
            earningsLeaderboard = results.2
            
            isLoading = false
            
            print("📊 Leaderboards loaded: \(cardsLeaderboard.count) cards, \(heatLeaderboard.count) heat, \(earningsLeaderboard.count) earnings")
        }
    }
    
    // MARK: - Cards Collected Leaderboard
    
    private func fetchCardsLeaderboard() async -> [LeaderboardEntry] {
        do {
            let snapshot = try await db.collection("users")
                .order(by: "totalCardsCollected", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            guard let currentUserId = FirebaseManager.shared.currentUserId else {
                return []
            }
            
            let entries = snapshot.documents.map { doc -> LeaderboardEntry in
                let data = doc.data()
                let username = data["username"] as? String ?? "Unknown"
                let totalCards = data["totalCardsCollected"] as? Int ?? 0
                let isCurrentUser = doc.documentID == currentUserId
                
                return LeaderboardEntry(
                    id: doc.documentID,
                    username: username,
                    value: totalCards,
                    isCurrentUser: isCurrentUser
                )
            }
            
            return entries
        } catch {
            print("❌ Error fetching cards leaderboard: \(error)")
            return []
        }
    }
    
    // MARK: - Total Heat Leaderboard
    
    private func fetchHeatLeaderboard() async -> [LeaderboardEntry] {
        do {
            // Get all friend activities
            let snapshot = try await db.collection("friend_activities")
                .getDocuments()
            
            guard let currentUserId = FirebaseManager.shared.currentUserId else {
                return []
            }
            
            // Calculate total heat per user
            var userHeatMap: [String: Int] = [:]
            var usernames: [String: String] = [:]
            
            for doc in snapshot.documents {
                let data = doc.data()
                let userId = data["userId"] as? String ?? ""
                let username = data["username"] as? String ?? "Unknown"
                let heatCount = data["heatCount"] as? Int ?? 0
                
                userHeatMap[userId, default: 0] += heatCount
                usernames[userId] = username
            }
            
            // Convert to leaderboard entries
            let entries = userHeatMap.map { userId, totalHeat -> LeaderboardEntry in
                LeaderboardEntry(
                    id: userId,
                    username: usernames[userId] ?? "Unknown",
                    value: totalHeat,
                    isCurrentUser: userId == currentUserId
                )
            }
            .sorted { $0.value > $1.value }
            .prefix(50)
            
            return Array(entries)
        } catch {
            print("❌ Error fetching heat leaderboard: \(error)")
            return []
        }
    }
    
    // MARK: - Earnings Leaderboard
    
    private func fetchEarningsLeaderboard() async -> [LeaderboardEntry] {
        do {
            let snapshot = try await db.collection("users")
                .order(by: "coins", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            guard let currentUserId = FirebaseManager.shared.currentUserId else {
                return []
            }
            
            let entries = snapshot.documents.map { doc -> LeaderboardEntry in
                let data = doc.data()
                let username = data["username"] as? String ?? "Unknown"
                let coins = data["coins"] as? Int ?? 0
                let isCurrentUser = doc.documentID == currentUserId
                
                return LeaderboardEntry(
                    id: doc.documentID,
                    username: username,
                    value: coins,
                    isCurrentUser: isCurrentUser
                )
            }
            
            return entries
        } catch {
            print("❌ Error fetching earnings leaderboard: \(error)")
            return []
        }
    }
}
