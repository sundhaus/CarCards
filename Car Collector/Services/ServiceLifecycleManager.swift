//
//  ServiceLifecycleManager.swift
//  Car Collector
//
//  Manages Firestore listener lifecycle based on app state.
//  Stops all non-essential listeners when app backgrounds,
//  restarts them when app returns to foreground.
//
//  This prevents orphaned threads from keeping network connections
//  alive, reduces CPU/memory usage while backgrounded, and
//  eliminates dead threads that accumulate from listeners that
//  fire callbacks into deallocated contexts.
//

import SwiftUI
import Combine

@MainActor
final class ServiceLifecycleManager: ObservableObject {
    static let shared = ServiceLifecycleManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var isListening = false
    
    private init() {
        // Listen for app lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.pauseAllServices()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.resumeAllServices()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Start (called once on login)
    
    func startAll() {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        guard !isListening else { return }
        isListening = true
        
        // These were previously fire-and-forget — now tracked
        // UserService and CardService are essential — always on
        UserService.shared.loadProfile(uid: uid)
        CardService.shared.listenToMyCards(uid: uid)
        HeadToHeadService.shared.startDuoInviteListener()
        
        // MarketplaceService listeners start lazily when marketplace tab is visited
        // (listenToMyListings/listenToMyBids called by MarketplaceLandingView.onAppear)
        
        print("🟢 ServiceLifecycleManager: All listeners started")
    }
    
    // MARK: - Pause (app backgrounded)
    
    private func pauseAllServices() {
        guard isListening else { return }
        
        CardService.shared.stopListening()
        UserService.shared.stopListening()
        FriendsService.shared.stopAllListeners()
        HeadToHeadService.shared.stopListening()
        HeadToHeadService.shared.stopDuoInviteListener()
        MarketplaceService.shared.stopAllListeners()
        HotCardsService.shared.pauseTimer()
        
        // Stop gyroscope if running
        CardMotionManager.shared.stopIfNeeded()
        
        print("⏸️ ServiceLifecycleManager: All listeners paused (app backgrounded)")
    }
    
    // MARK: - Resume (app foregrounded)
    
    private func resumeAllServices() {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        // Restart essential listeners — they're idempotent (remove old before adding new)
        UserService.shared.loadProfile(uid: uid)
        CardService.shared.listenToMyCards(uid: uid)
        HeadToHeadService.shared.startDuoInviteListener()
        HotCardsService.shared.resumeTimer()
        
        // MarketplaceService restarts lazily when marketplace tab is visited
        
        // FriendsService listeners will restart when user visits Friends tab
        
        isListening = true
        print("▶️ ServiceLifecycleManager: All listeners resumed (app foregrounded)")
    }
    
    // MARK: - Stop All (logout)
    
    func stopAll() {
        CardService.shared.stopListening()
        UserService.shared.stopListening()
        FriendsService.shared.stopAllListeners()
        HeadToHeadService.shared.stopListening()
        HeadToHeadService.shared.stopDuoInviteListener()
        MarketplaceService.shared.stopAllListeners()
        HotCardsService.shared.pauseTimer()
        HotCardsService.shared.reset()
        
        isListening = false
        print("🔴 ServiceLifecycleManager: All listeners stopped (logout)")
    }
}
