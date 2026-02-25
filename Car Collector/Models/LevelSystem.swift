//
//  LevelSystem.swift
//  CarCardCollector
//
//  User leveling and XP system – syncs to Firestore
//

import Foundation
import UIKit
import Combine

@MainActor
class LevelSystem: ObservableObject {
    @Published var level: Int
    @Published var currentXP: Int
    @Published var xpForNextLevel: Int
    @Published var totalXP: Int
    @Published var coins: Int
    @Published var gems: Int
    
    private let baseXP = 100
    private var cancellables = Set<AnyCancellable>()
    private var isSyncing = false  // Guard against sync loops
    
    init() {
        // Load from UserDefaults as local cache
        let savedLevel = UserDefaults.standard.integer(forKey: "userLevel")
        let savedXP = UserDefaults.standard.integer(forKey: "currentXP")
        let savedTotalXP = UserDefaults.standard.integer(forKey: "totalXP")
        let savedCoins = UserDefaults.standard.integer(forKey: "userCoins")
        let savedGems = UserDefaults.standard.integer(forKey: "userGems")
        
        self.level = savedLevel == 0 ? 1 : savedLevel
        self.currentXP = savedXP
        self.totalXP = savedTotalXP
        self.coins = savedCoins
        self.gems = savedGems
        self.xpForNextLevel = 0
        self.xpForNextLevel = LevelSystem.calculateXPForLevel(self.level + 1)
        
        // Observe UserService profile changes
        setupCloudSync()
    }
    
    private func setupCloudSync() {
        // Watch for profile updates from Firebase
        UserService.shared.$currentProfile
            .compactMap { $0 }
            .sink { [weak self] profile in
                self?.syncFromProfile(profile)
            }
            .store(in: &cancellables)
    }
    
    private func syncFromProfile(_ profile: UserProfile) {
        // Skip if we're currently pushing to cloud (prevents ping-pong loop)
        guard !isSyncing else { return }
        
        // Only update if cloud values are different
        var changed = false
        var needsLevelCheck = false
        
        if profile.level != level {
            level = profile.level
            xpForNextLevel = LevelSystem.calculateXPForLevel(level + 1)
            changed = true
        }
        
        if profile.currentXP != currentXP {
            currentXP = profile.currentXP
            needsLevelCheck = true
            changed = true
        }
        
        // totalXP should only increase, never decrease (prevents sync issues)
        if profile.totalXP > totalXP {
            totalXP = profile.totalXP
            changed = true
        }
        
        if profile.coins != coins {
            coins = profile.coins
            changed = true
        }
        
        if profile.gems != gems {
            gems = profile.gems
            changed = true
        }
        
        guard changed else { return }
        
        save() // Update local cache
        print("✅ Synced from cloud: Level \(level), XP \(currentXP)/\(xpForNextLevel), Total XP \(totalXP), Coins \(coins), Gems \(gems)")
        
        // Check for level-ups after sync (manual XP changes in Firestore)
        if needsLevelCheck {
            let previousLevel = level
            while currentXP >= xpForNextLevel && xpForNextLevel > 0 {
                levelUp()
            }
            // Only sync back if a level-up actually occurred
            if level > previousLevel {
                syncToCloud()
            }
        }
    }
    
    static func calculateXPForLevel(_ level: Int) -> Int {
        if level <= 1 { return 0 }
        
        // Steam-like tiered linear growth:
        // Every 10 levels, the XP requirement per level increases by 100
        // Tier 0 (levels 1-9):   100 XP each
        // Tier 1 (levels 10-19): 200 XP each
        // Tier 2 (levels 20-29): 300 XP each
        // ...
        // Level 109→110: 1,200 XP
        let tier = (level - 1) / 10  // 0-based tier
        return (tier + 1) * 100
    }
    
    func addXP(_ amount: Int) {
        currentXP += amount
        totalXP += amount
        
        while currentXP >= xpForNextLevel {
            levelUp()
        }
        
        save()
        syncToCloud()
    }
    
    private func levelUp() {
        currentXP -= xpForNextLevel
        level += 1
        xpForNextLevel = LevelSystem.calculateXPForLevel(level + 1)
        
        // Award coins for leveling up
        let bonus = RewardConfig.levelUpCoins(for: level)
        coins += bonus
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        print("🎉 Level up! Now level \(level) — awarded \(bonus) coins")
    }
    
    var progress: Double {
        guard xpForNextLevel > 0 else { return 0 }
        return Double(currentXP) / Double(xpForNextLevel)
    }
    
    func addCoins(_ amount: Int) {
        coins += amount
        save()
        syncToCloud()
    }
    
    func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        save()
        syncToCloud()
        return true
    }
    
    private func save() {
        UserDefaults.standard.set(level, forKey: "userLevel")
        UserDefaults.standard.set(currentXP, forKey: "currentXP")
        UserDefaults.standard.set(totalXP, forKey: "totalXP")
        UserDefaults.standard.set(coins, forKey: "userCoins")
        UserDefaults.standard.set(gems, forKey: "userGems")
    }
    
    // Sync current progress to Firestore
    private func syncToCloud() {
        isSyncing = true
        Task {
            guard let uid = FirebaseManager.shared.currentUserId else {
                isSyncing = false
                return
            }
            
            do {
                try await UserService.shared.syncProgress(
                    uid: uid,
                    level: level,
                    currentXP: currentXP,
                    totalXP: totalXP,
                    coins: coins,
                    gems: gems
                )
            } catch {
                print("⚠️ Cloud sync failed (will retry): \(error)")
            }
            
            // Brief delay before re-enabling cloud listener acceptance
            // This allows Firestore's listener to deliver our own write-back
            // before we start processing incoming changes again
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            isSyncing = false
        }
    }
    
    // Manual load from cloud (kept for compatibility)
    func loadFromCloud() {
        guard let profile = UserService.shared.currentProfile else { return }
        syncFromProfile(profile)
    }
    
    func reset() {
        level = 1
        currentXP = 0
        totalXP = 0
        coins = 0
        gems = 0
        xpForNextLevel = baseXP
        save()
        syncToCloud()
    }
}
