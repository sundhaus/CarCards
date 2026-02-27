//
//  TutorialQuestService.swift
//  Car Collector
//
//  Tracks one-time tutorial quests for new users:
//    1. Capture 3 cars
//    2. Enter 1 battle
//    3. Follow a friend
//
//  Progress is stored locally in UserDefaults and synced to Firestore.
//  Once all quests are complete, the tutorial is marked as finished and
//  the banner disappears from HomeView permanently.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Tutorial Quest Model

struct TutorialQuest: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let target: Int
    let rewardCoins: Int
    let rewardXP: Int
    var progress: Int
    
    var isComplete: Bool { progress >= target }
    var progressFraction: Double { target > 0 ? Double(min(progress, target)) / Double(target) : 0 }
    
    /// The tab index to navigate to for this quest (nil = no specific tab)
    var destinationTab: Int? {
        switch id {
        case "tut_capture_3":  return 2   // Capture tab
        case "tut_battle_1":   return 1   // Home → H2H
        case "tut_follow_1":   return 1   // Home → Friends
        default: return nil
        }
    }
    
    /// Navigation action identifier (used by HomeView to open sub-views)
    var navigationAction: String? {
        switch id {
        case "tut_battle_1":   return "headToHead"
        case "tut_follow_1":   return "friends"
        default: return nil
        }
    }
}

// MARK: - Service

@MainActor
class TutorialQuestService: ObservableObject {
    static let shared = TutorialQuestService()
    
    // Keys
    private let kTutorialComplete = "tutorialQuestsComplete"
    private let kCaptureProgress  = "tutQuest_captures"
    private let kBattleProgress   = "tutQuest_battles"
    private let kFollowProgress   = "tutQuest_follows"
    private let kFirstCaptureComplete = "firstCaptureGuideComplete"
    
    @Published var quests: [TutorialQuest] = []
    @Published var isTutorialComplete: Bool = false
    @Published var isFirstCaptureComplete: Bool = false
    
    /// True if the user has never captured any card (brand-new user)
    var isNewUser: Bool {
        !isFirstCaptureComplete && !isTutorialComplete
    }
    
    /// True if the tutorial banner should show (first capture done, but tutorial not finished)
    var shouldShowTutorialBanner: Bool {
        isFirstCaptureComplete && !isTutorialComplete
    }
    
    private let db = Firestore.firestore()
    
    private init() {
        isTutorialComplete = UserDefaults.standard.bool(forKey: kTutorialComplete)
        isFirstCaptureComplete = UserDefaults.standard.bool(forKey: kFirstCaptureComplete)
        rebuildQuests()
    }
    
    // MARK: - Quest Definitions
    
    private func rebuildQuests() {
        let captures = UserDefaults.standard.integer(forKey: kCaptureProgress)
        let battles  = UserDefaults.standard.integer(forKey: kBattleProgress)
        let follows  = UserDefaults.standard.integer(forKey: kFollowProgress)
        
        quests = [
            TutorialQuest(
                id: "tut_capture_3",
                title: "Card Hunter",
                description: "Capture 3 cars",
                icon: "camera.fill",
                target: 3,
                rewardCoins: 250,
                rewardXP: 75,
                progress: captures
            ),
            TutorialQuest(
                id: "tut_battle_1",
                title: "First Battle",
                description: "Enter a Head-to-Head battle",
                icon: "bolt.fill",
                target: 1,
                rewardCoins: 200,
                rewardXP: 50,
                progress: battles
            ),
            TutorialQuest(
                id: "tut_follow_1",
                title: "Social Starter",
                description: "Follow a friend",
                icon: "person.badge.plus",
                target: 1,
                rewardCoins: 150,
                rewardXP: 50,
                progress: follows
            )
        ]
    }
    
    // MARK: - Progress Tracking
    
    func recordCapture() {
        guard !isTutorialComplete else { return }
        let current = UserDefaults.standard.integer(forKey: kCaptureProgress)
        UserDefaults.standard.set(current + 1, forKey: kCaptureProgress)
        rebuildQuests()
        checkCompletion()
    }
    
    func recordBattle() {
        guard !isTutorialComplete else { return }
        let current = UserDefaults.standard.integer(forKey: kBattleProgress)
        guard current < 1 else { return } // Only need 1
        UserDefaults.standard.set(current + 1, forKey: kBattleProgress)
        rebuildQuests()
        checkCompletion()
    }
    
    func recordFollow() {
        guard !isTutorialComplete else { return }
        let current = UserDefaults.standard.integer(forKey: kFollowProgress)
        guard current < 1 else { return } // Only need 1
        UserDefaults.standard.set(current + 1, forKey: kFollowProgress)
        rebuildQuests()
        checkCompletion()
    }
    
    /// Mark the guided first capture as complete
    func completeFirstCapture() {
        isFirstCaptureComplete = true
        UserDefaults.standard.set(true, forKey: kFirstCaptureComplete)
        // Also count this as the first tutorial capture
        recordCapture()
    }
    
    // MARK: - Completion Check
    
    private func checkCompletion() {
        let allDone = quests.allSatisfy { $0.isComplete }
        if allDone && !isTutorialComplete {
            isTutorialComplete = true
            UserDefaults.standard.set(true, forKey: kTutorialComplete)
            
            // Award bonus for completing all tutorial quests
            let totalCoins = quests.reduce(0) { $0 + $1.rewardCoins }
            let totalXP = quests.reduce(0) { $0 + $1.rewardXP }
            
            // Sync to Firestore
            Task {
                await syncCompletionToCloud(bonusCoins: totalCoins, bonusXP: totalXP)
            }
            
            print("🎓 Tutorial quests complete! Awarded \(totalCoins) coins + \(totalXP) XP")
        }
    }
    
    private func syncCompletionToCloud(bonusCoins: Int, bonusXP: Int) async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        do {
            try await db.collection("users").document(uid).updateData([
                "tutorialComplete": true,
                "tutorialCompletedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            print("⚠️ Tutorial sync failed: \(error)")
        }
    }
    
    // MARK: - Load from Cloud (for returning users on new device)
    
    func loadFromCloud() async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if let tutComplete = doc.data()?["tutorialComplete"] as? Bool, tutComplete {
                isTutorialComplete = true
                isFirstCaptureComplete = true
                UserDefaults.standard.set(true, forKey: kTutorialComplete)
                UserDefaults.standard.set(true, forKey: kFirstCaptureComplete)
            }
        } catch {
            print("⚠️ Tutorial cloud load failed: \(error)")
        }
    }
    
    /// Returns the count of completed quests
    var completedCount: Int {
        quests.filter { $0.isComplete }.count
    }
    
    /// Returns total quest count
    var totalCount: Int {
        quests.count
    }
}
