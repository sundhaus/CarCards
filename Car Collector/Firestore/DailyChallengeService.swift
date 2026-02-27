//
//  DailyChallengeService.swift
//  Car Collector
//
//  Manages daily challenges, weekly featured challenges, and streak cosmetic
//  unlocks. Generates deterministic daily challenges from a seed (date-based)
//  so all users see the same challenges each day. Progress tracks in Firestore
//  under users/{uid}/meta/dailyChallenges.
//
//  Challenge types:
//    • Color challenges  — "Capture a red car today"
//    • Category challenges — "Capture an SUV today"
//    • H2H challenges — "Win 2 Head-to-Head battles"
//    • Social challenges — "Give 3 heats on friend cards"
//    • Weekly featured — "SUV Week: capture 3 SUVs for a special border"
//

import Foundation
import FirebaseFirestore

// MARK: - Challenge Types

enum ChallengeType: String, Codable {
    case captureColor    // Capture a specific color car
    case captureCategory // Capture a specific vehicle category
    case h2hWins         // Win N H2H battles
    case giveHeats       // Give N heats to friend cards
    case captureAny      // Capture N cards (any type)
    case weeklyFeatured  // Weekly themed challenge (longer duration)
}

// MARK: - Challenge Model

struct DailyChallenge: Identifiable, Codable {
    let id: String           // e.g. "daily_2026-02-26_0"
    let type: ChallengeType
    let title: String
    let description: String
    let icon: String         // SF Symbol name
    let target: Int
    let rewardCoins: Int
    let rewardXP: Int
    let rewardEvolutionPoints: Int
    let expiresAt: Date
    let param: String?       // e.g. "red", "SUV" — the matching value
    
    // User state (local only, not stored in definition)
    var progress: Int = 0
    var isClaimed: Bool = false
    
    var isComplete: Bool { progress >= target }
    var progressFraction: Double { target > 0 ? Double(min(progress, target)) / Double(target) : 0 }
    var isExpired: Bool { Date() > expiresAt }
    
    var gradientColors: [Color] {
        switch type {
        case .captureColor:    return [.orange, .pink]
        case .captureCategory: return [.cyan, .blue]
        case .h2hWins:         return [.orange, .red]
        case .giveHeats:       return [.red, .orange]
        case .captureAny:      return [.green, .cyan]
        case .weeklyFeatured:  return [.purple, .blue]
        }
    }
}

import SwiftUI

// MARK: - Weekly Featured Challenge

struct WeeklyFeaturedChallenge: Identifiable, Codable {
    let id: String           // e.g. "weekly_2026_W09"
    let title: String
    let description: String
    let icon: String
    let category: String     // VehicleCategory rawValue
    let target: Int
    let rewardCoins: Int
    let rewardXP: Int
    let rewardBorder: String? // Exclusive border name unlocked on completion
    let expiresAt: Date
    
    var progress: Int = 0
    var isClaimed: Bool = false
    
    var isComplete: Bool { progress >= target }
    var progressFraction: Double { target > 0 ? Double(min(progress, target)) / Double(target) : 0 }
    var isExpired: Bool { Date() > expiresAt }
}

// MARK: - Streak Cosmetic Milestone

struct StreakCosmeticReward {
    let streakDay: Int
    let name: String
    let description: String
    let icon: String
    let type: CosmeticType
    
    enum CosmeticType: String {
        case border = "border"
        case cardEffect = "cardEffect"
        case profileBadge = "profileBadge"
    }
}

// MARK: - Service

@MainActor
class DailyChallengeService: ObservableObject {
    static let shared = DailyChallengeService()
    
    @Published var dailyChallenges: [DailyChallenge] = []
    @Published var weeklyChallenge: WeeklyFeaturedChallenge?
    @Published var unlockedCosmetics: [String] = [] // IDs of unlocked streak cosmetics
    @Published var isLoaded = false
    
    private let db = FirebaseManager.shared.db
    private let calendar = Calendar.current
    
    private init() {}
    
    // MARK: - Streak Cosmetic Definitions
    
    static let streakCosmetics: [StreakCosmeticReward] = [
        StreakCosmeticReward(
            streakDay: 7,
            name: "Streak Flame Border",
            description: "Exclusive fiery border for 7-day streakers",
            icon: "flame.fill",
            type: .border
        ),
        StreakCosmeticReward(
            streakDay: 14,
            name: "Hot Streak Badge",
            description: "Profile badge showing your dedication",
            icon: "rosette",
            type: .profileBadge
        ),
        StreakCosmeticReward(
            streakDay: 30,
            name: "Inferno Effect",
            description: "Animated fire card effect for true collectors",
            icon: "sparkles",
            type: .cardEffect
        ),
        StreakCosmeticReward(
            streakDay: 60,
            name: "Diamond Streak Border",
            description: "Diamond-encrusted border for elite streakers",
            icon: "diamond.fill",
            type: .border
        ),
        StreakCosmeticReward(
            streakDay: 100,
            name: "Century Legend Effect",
            description: "Legendary animated effect for 100-day warriors",
            icon: "crown.fill",
            type: .cardEffect
        )
    ]
    
    // MARK: - Color Palette for Challenges
    
    private static let challengeColors = [
        "red", "blue", "black", "white", "silver", "green", "yellow", "orange"
    ]
    
    // MARK: - Category Pools for Challenges
    
    private static let challengeCategories = [
        "SUV", "Sports Car", "Sedan", "Truck", "Luxury", "Electric",
        "Classic", "Convertible", "Coupe", "Muscle"
    ]
    
    // MARK: - Generate Daily Challenges (deterministic from date)
    
    func generateDailyChallenges(for date: Date = Date()) -> [DailyChallenge] {
        let dayString = Self.dayString(from: date)
        let seed = Self.seedFromString(dayString)
        
        // End of day for expiry
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        
        var challenges: [DailyChallenge] = []
        
        // Challenge 1: Always a color capture challenge
        let colorIndex = seed % Self.challengeColors.count
        let color = Self.challengeColors[colorIndex]
        challenges.append(DailyChallenge(
            id: "daily_\(dayString)_color",
            type: .captureColor,
            title: "Capture a \(color.capitalized) Car",
            description: "Find and photograph a \(color) vehicle today",
            icon: "camera.fill",
            target: 1,
            rewardCoins: RewardConfig.dailyChallengeCoins,
            rewardXP: RewardConfig.dailyChallengeXP,
            rewardEvolutionPoints: RewardConfig.dailyChallengeEvoPoints,
            expiresAt: endOfDay,
            param: color
        ))
        
        // Challenge 2: H2H or social (alternates by day)
        if seed % 2 == 0 {
            let h2hTarget = (seed % 2) + 2 // 2 or 3
            challenges.append(DailyChallenge(
                id: "daily_\(dayString)_h2h",
                type: .h2hWins,
                title: "Win \(h2hTarget) Battles",
                description: "Dominate \(h2hTarget) Head-to-Head matchups",
                icon: "bolt.fill",
                target: h2hTarget,
                rewardCoins: RewardConfig.dailyChallengeH2HCoins,
                rewardXP: RewardConfig.dailyChallengeH2HXP,
                rewardEvolutionPoints: RewardConfig.dailyChallengeH2HEvoPoints,
                expiresAt: endOfDay,
                param: nil
            ))
        } else {
            let heatTarget = (seed % 3) + 3 // 3, 4, or 5
            challenges.append(DailyChallenge(
                id: "daily_\(dayString)_social",
                type: .giveHeats,
                title: "Give \(heatTarget) Heats",
                description: "Support \(heatTarget) friend cards with heats",
                icon: "flame.fill",
                target: heatTarget,
                rewardCoins: RewardConfig.dailyChallengeSocialCoins,
                rewardXP: RewardConfig.dailyChallengeSocialXP,
                rewardEvolutionPoints: 0,
                expiresAt: endOfDay,
                param: nil
            ))
        }
        
        // Challenge 3: Category capture
        let catIndex = (seed / 7) % Self.challengeCategories.count
        let category = Self.challengeCategories[catIndex]
        challenges.append(DailyChallenge(
            id: "daily_\(dayString)_category",
            type: .captureCategory,
            title: "Capture a \(category)",
            description: "Snap a \(category) to complete this challenge",
            icon: "car.fill",
            target: 1,
            rewardCoins: RewardConfig.dailyChallengeCoins,
            rewardXP: RewardConfig.dailyChallengeXP,
            rewardEvolutionPoints: RewardConfig.dailyChallengeEvoPoints,
            expiresAt: endOfDay,
            param: category
        ))
        
        return challenges
    }
    
    // MARK: - Generate Weekly Featured Challenge
    
    func generateWeeklyChallenge(for date: Date = Date()) -> WeeklyFeaturedChallenge {
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.year, from: date)
        let weekId = "weekly_\(year)_W\(String(format: "%02d", weekOfYear))"
        let seed = Self.seedFromString(weekId)
        
        // End of week (next Sunday midnight)
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.end ?? date
        
        let catIndex = seed % Self.challengeCategories.count
        let category = Self.challengeCategories[catIndex]
        let categoryEnum = VehicleCategory.allCases.first { $0.rawValue == category }
        let emoji = categoryEnum?.emoji ?? "🚗"
        
        return WeeklyFeaturedChallenge(
            id: weekId,
            title: "\(emoji) \(category) Week",
            description: "Capture \(3) \(category)s this week for an exclusive border",
            icon: "star.circle.fill",
            category: category,
            target: 3,
            rewardCoins: RewardConfig.weeklyChallengeCoins,
            rewardXP: RewardConfig.weeklyChallengeXP,
            rewardBorder: "Border_Weekly_\(category.replacingOccurrences(of: " ", with: "_"))",
            expiresAt: endOfWeek
        )
    }
    
    // MARK: - Load & Sync from Firestore
    
    func load(uid: String) async {
        // Generate today's challenges
        var challenges = generateDailyChallenges()
        var weekly = generateWeeklyChallenge()
        
        // Load progress from Firestore
        let docRef = db.collection("users").document(uid).collection("meta").document("dailyChallenges")
        
        do {
            let snapshot = try await docRef.getDocument()
            if let data = snapshot.data() {
                // Load daily challenge progress
                if let dailyProgress = data["dailyProgress"] as? [String: [String: Any]] {
                    for i in challenges.indices {
                        if let entry = dailyProgress[challenges[i].id] {
                            challenges[i].progress = entry["progress"] as? Int ?? 0
                            challenges[i].isClaimed = entry["claimed"] as? Bool ?? false
                        }
                    }
                }
                
                // Load weekly challenge progress
                if let weeklyData = data["weeklyProgress"] as? [String: Any],
                   let weeklyId = weeklyData["id"] as? String,
                   weeklyId == weekly.id {
                    weekly.progress = weeklyData["progress"] as? Int ?? 0
                    weekly.isClaimed = weeklyData["claimed"] as? Bool ?? false
                }
                
                // Load unlocked cosmetics
                unlockedCosmetics = data["unlockedCosmetics"] as? [String] ?? []
            }
        } catch {
            print("⚠️ DailyChallengeService: Failed to load progress: \(error)")
        }
        
        dailyChallenges = challenges
        weeklyChallenge = weekly
        isLoaded = true
        
        print("✅ DailyChallenges loaded: \(challenges.count) daily, weekly=\(weekly.title)")
    }
    
    // MARK: - Track Progress
    
    /// Call when a card is captured. Checks color/category matches.
    func onCardCaptured(color: String?, category: String?, uid: String) {
        var changed = false
        
        for i in dailyChallenges.indices {
            let c = dailyChallenges[i]
            guard !c.isComplete && !c.isClaimed else { continue }
            
            switch c.type {
            case .captureColor:
                if let color = color?.lowercased(), let param = c.param?.lowercased(), color.contains(param) {
                    dailyChallenges[i].progress += 1
                    changed = true
                }
            case .captureCategory:
                if let category = category, let param = c.param, category == param {
                    dailyChallenges[i].progress += 1
                    changed = true
                }
            case .captureAny:
                dailyChallenges[i].progress += 1
                changed = true
            default:
                break
            }
        }
        
        // Weekly challenge: category match
        if let weekly = weeklyChallenge, !weekly.isComplete && !weekly.isClaimed {
            if let category = category, category == weekly.category {
                weeklyChallenge?.progress += 1
                changed = true
            }
        }
        
        if changed {
            Task { await saveProgress(uid: uid) }
        }
    }
    
    /// Call when an H2H battle is won.
    func onH2HWin(uid: String) {
        var changed = false
        
        for i in dailyChallenges.indices {
            if dailyChallenges[i].type == .h2hWins && !dailyChallenges[i].isComplete && !dailyChallenges[i].isClaimed {
                dailyChallenges[i].progress += 1
                changed = true
            }
        }
        
        if changed {
            Task { await saveProgress(uid: uid) }
        }
    }
    
    /// Call when a heat is given to a friend's card.
    func onHeatGiven(uid: String) {
        var changed = false
        
        for i in dailyChallenges.indices {
            if dailyChallenges[i].type == .giveHeats && !dailyChallenges[i].isComplete && !dailyChallenges[i].isClaimed {
                dailyChallenges[i].progress += 1
                changed = true
            }
        }
        
        if changed {
            Task { await saveProgress(uid: uid) }
        }
    }
    
    // MARK: - Claim Reward
    
    func claimReward(challengeId: String, uid: String) async -> Bool {
        // Find in daily challenges
        if let index = dailyChallenges.firstIndex(where: { $0.id == challengeId }) {
            guard dailyChallenges[index].isComplete && !dailyChallenges[index].isClaimed else { return false }
            
            let challenge = dailyChallenges[index]
            dailyChallenges[index].isClaimed = true
            
            // Award rewards
            UserService.shared.addCoins(challenge.rewardCoins)
            if challenge.rewardXP > 0 {
                // XP is handled through LevelSystem synced via UserService
                UserService.shared.addXP(challenge.rewardXP)
            }
            
            await saveProgress(uid: uid)
            print("✅ Claimed daily challenge: \(challenge.title) → +\(challenge.rewardCoins) coins, +\(challenge.rewardXP) XP")
            return true
        }
        
        // Check weekly
        if let weekly = weeklyChallenge, weekly.id == challengeId {
            guard weekly.isComplete && !weekly.isClaimed else { return false }
            
            weeklyChallenge?.isClaimed = true
            
            UserService.shared.addCoins(weekly.rewardCoins)
            UserService.shared.addXP(weekly.rewardXP)
            
            // Unlock border if present
            if let border = weekly.rewardBorder {
                unlockedCosmetics.append(border)
            }
            
            await saveProgress(uid: uid)
            print("✅ Claimed weekly challenge: \(weekly.title) → +\(weekly.rewardCoins) coins, +\(weekly.rewardXP) XP, border=\(weekly.rewardBorder ?? "none")")
            return true
        }
        
        return false
    }
    
    // MARK: - Check Streak Cosmetic Unlocks
    
    /// Call after daily login streak updates. Returns newly unlocked cosmetics.
    func checkStreakUnlocks(currentStreak: Int, uid: String) async -> [StreakCosmeticReward] {
        var newUnlocks: [StreakCosmeticReward] = []
        
        for cosmetic in Self.streakCosmetics {
            let cosmeticId = "streak_\(cosmetic.streakDay)_\(cosmetic.type.rawValue)"
            if currentStreak >= cosmetic.streakDay && !unlockedCosmetics.contains(cosmeticId) {
                unlockedCosmetics.append(cosmeticId)
                newUnlocks.append(cosmetic)
            }
        }
        
        if !newUnlocks.isEmpty {
            await saveProgress(uid: uid)
            print("🎉 Unlocked streak cosmetics: \(newUnlocks.map { $0.name })")
        }
        
        return newUnlocks
    }
    
    /// Next cosmetic milestone the user hasn't reached yet
    func nextStreakMilestone(currentStreak: Int) -> StreakCosmeticReward? {
        Self.streakCosmetics.first { $0.streakDay > currentStreak }
    }
    
    // MARK: - Persistence
    
    private func saveProgress(uid: String) async {
        var dailyProgress: [String: [String: Any]] = [:]
        for challenge in dailyChallenges {
            dailyProgress[challenge.id] = [
                "progress": challenge.progress,
                "claimed": challenge.isClaimed
            ]
        }
        
        var data: [String: Any] = [
            "dailyProgress": dailyProgress,
            "unlockedCosmetics": unlockedCosmetics,
            "lastUpdated": Timestamp(date: Date())
        ]
        
        if let weekly = weeklyChallenge {
            data["weeklyProgress"] = [
                "id": weekly.id,
                "progress": weekly.progress,
                "claimed": weekly.isClaimed
            ]
        }
        
        let docRef = db.collection("users").document(uid).collection("meta").document("dailyChallenges")
        try? await docRef.setData(data, merge: true)
    }
    
    // MARK: - Deterministic Seed Helpers
    
    private static func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private static func seedFromString(_ s: String) -> Int {
        // Simple hash for deterministic challenge generation
        var hash = 5381
        for char in s.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(char)
        }
        return abs(hash)
    }
}
