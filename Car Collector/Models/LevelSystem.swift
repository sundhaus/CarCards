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
    
    private let baseXP = 100
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load from UserDefaults as local cache
        let savedLevel = UserDefaults.standard.integer(forKey: "userLevel")
        let savedXP = UserDefaults.standard.integer(forKey: "currentXP")
        let savedTotalXP = UserDefaults.standard.integer(forKey: "totalXP")
        let savedCoins = UserDefaults.standard.integer(forKey: "userCoins")
        
        self.level = savedLevel == 0 ? 1 : savedLevel
        self.currentXP = savedXP
        self.totalXP = savedTotalXP
        self.coins = savedCoins
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
        // Only update if cloud values are different (avoid loops)
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
        
        if changed {
            save() // Update local cache
            print("✅ Synced from cloud: Level \(level), XP \(currentXP)/\(xpForNextLevel), Total XP \(totalXP), Coins \(coins)")
        }
        
        // Check for level-ups after sync (manual XP changes in Firestore)
        if needsLevelCheck {
            while currentXP >= xpForNextLevel && xpForNextLevel > 0 {
                levelUp()
            }
            if needsLevelCheck && changed {
                syncToCloud() // Sync back the level-up
            }
        }
    }
    
    static func calculateXPForLevel(_ level: Int) -> Int {
        if level <= 1 { return 0 }
        if level == 2 { return 1000 } // Level 1→2 needs 1000 XP
        
        // For level 3+, calculate based on previous levels
        var xpNeeded = 1000 // XP needed for level 2
        
        // Calculate XP requirements for each level
        for targetLevel in 3...level {
            let tier = (targetLevel - 2) / 5
            let constantBonus = 1000 + (tier * 500)
            xpNeeded = Int(Double(xpNeeded) * 1.2) + constantBonus
        }
        
        return xpNeeded
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
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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
    }
    
    // Sync current progress to Firestore
    private func syncToCloud() {
        Task {
            guard let uid = FirebaseManager.shared.currentUserId else { return }
            
            do {
                try await UserService.shared.syncProgress(
                    uid: uid,
                    level: level,
                    currentXP: currentXP,
                    totalXP: totalXP,
                    coins: coins
                )
            } catch {
                print("⚠️ Cloud sync failed (will retry): \(error)")
            }
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
        xpForNextLevel = baseXP
        save()
        syncToCloud()
    }
}
