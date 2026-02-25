//
//  DailyLoginService.swift
//  Car Collector
//
//  Tracks daily login streaks and rewards.
//  Stores streak data in Firestore under users/{uid}/dailyLogin.
//  Call checkIn() once per app launch to award daily XP/coins.
//

import Foundation
import FirebaseFirestore

@MainActor
class DailyLoginService: ObservableObject {
    static let shared = DailyLoginService()
    
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var lastLoginDate: Date? = nil
    @Published var todayRewardClaimed: Bool = false
    @Published var isLoaded: Bool = false
    
    // Reward just claimed this session (for the popup)
    @Published var sessionReward: DailyReward? = nil
    
    private let db = FirebaseManager.shared.db
    private let calendar = Calendar.current
    
    private init() {}
    
    // MARK: - Data Model
    
    struct DailyReward {
        let baseXP: Int
        let baseCoins: Int
        let bonusXP: Int
        let bonusCoins: Int
        let streak: Int
        let isMilestone: Bool      // 3, 7, 30 day milestones
        let milestoneLabel: String? // e.g. "7-Day Streak!"
        
        var totalXP: Int { baseXP + bonusXP }
        var totalCoins: Int { baseCoins + bonusCoins }
    }
    
    // MARK: - Load from Firestore
    
    func load(uid: String) {
        let docRef = db.collection("users").document(uid).collection("meta").document("dailyLogin")
        
        docRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let data = snapshot?.data() {
                    self.currentStreak = data["currentStreak"] as? Int ?? 0
                    self.longestStreak = data["longestStreak"] as? Int ?? 0
                    
                    if let ts = data["lastLoginDate"] as? Timestamp {
                        self.lastLoginDate = ts.dateValue()
                    }
                    
                    // Check if today's reward was already claimed
                    if let last = self.lastLoginDate {
                        self.todayRewardClaimed = self.calendar.isDateInToday(last)
                    }
                } else {
                    // First time — no streak data yet
                    self.currentStreak = 0
                    self.longestStreak = 0
                    self.lastLoginDate = nil
                    self.todayRewardClaimed = false
                }
                
                self.isLoaded = true
            }
        }
    }
    
    // MARK: - Check In (call on app open)
    
    /// Returns the reward if one was granted, nil if already claimed today.
    @discardableResult
    func checkIn(uid: String) async -> DailyReward? {
        // Wait for load if needed
        if !isLoaded {
            load(uid: uid)
            // Brief wait for Firestore
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Already claimed today
        if todayRewardClaimed { return nil }
        
        let now = Date()
        var newStreak = 1
        
        if let lastLogin = lastLoginDate {
            if calendar.isDateInYesterday(lastLogin) {
                // Consecutive day — extend streak
                newStreak = currentStreak + 1
            } else if calendar.isDateInToday(lastLogin) {
                // Already logged in today
                todayRewardClaimed = true
                return nil
            }
            // else: gap > 1 day — streak resets to 1
        }
        
        // Calculate reward
        let reward = calculateReward(for: newStreak)
        
        // Update local state
        currentStreak = newStreak
        longestStreak = max(longestStreak, newStreak)
        lastLoginDate = now
        todayRewardClaimed = true
        sessionReward = reward
        
        // Award XP and coins
        UserService.shared.addCoins(reward.totalCoins)
        LevelSystem().addXP(reward.totalXP) // LevelSystem is initialized fresh but syncs via UserService
        
        // Persist to Firestore
        let docRef = db.collection("users").document(uid).collection("meta").document("dailyLogin")
        try? await docRef.setData([
            "currentStreak": newStreak,
            "longestStreak": max(longestStreak, newStreak),
            "lastLoginDate": Timestamp(date: now)
        ], merge: true)
        
        return reward
    }
    
    // MARK: - Reward Calculation
    
    func calculateReward(for streak: Int) -> DailyReward {
        let baseXP = RewardConfig.dailyLoginXP
        let baseCoins = RewardConfig.dailyLoginCoins
        
        var bonusXP = 0
        var bonusCoins = 0
        var isMilestone = false
        var milestoneLabel: String? = nil
        
        if streak >= 30 && streak % 30 == 0 {
            bonusXP = RewardConfig.streak30BonusXP
            bonusCoins = RewardConfig.streak30BonusCoins
            isMilestone = true
            milestoneLabel = "\(streak)-Day Streak!"
        } else if streak >= 7 && streak % 7 == 0 {
            bonusXP = RewardConfig.streak7BonusXP
            bonusCoins = RewardConfig.streak7BonusCoins
            isMilestone = true
            milestoneLabel = "\(streak)-Day Streak!"
        } else if streak == 3 {
            bonusXP = RewardConfig.streak3BonusXP
            bonusCoins = 0
            isMilestone = true
            milestoneLabel = "3-Day Streak!"
        }
        
        return DailyReward(
            baseXP: baseXP,
            baseCoins: baseCoins,
            bonusXP: bonusXP,
            bonusCoins: bonusCoins,
            streak: streak,
            isMilestone: isMilestone,
            milestoneLabel: milestoneLabel
        )
    }
    
    // MARK: - Preview Helpers
    
    /// What the next 7 days of rewards would look like from current streak
    func upcomingRewards() -> [DailyReward] {
        (1...7).map { offset in
            calculateReward(for: currentStreak + offset)
        }
    }
}
