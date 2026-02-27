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
        
        // Essential listeners — always on while authenticated
        UserService.shared.loadProfile(uid: uid)
        CardService.shared.listenToMyCards(uid: uid)
        HeadToHeadService.shared.startDuoInviteListener()
        
        // Marketplace personal listeners (my listings & bids) start at login
        // Active listings listener starts lazily when marketplace tab is visited
        MarketplaceService.shared.listenToMyListings(uid: uid)
        MarketplaceService.shared.listenToMyBids(uid: uid)
        
        print("🟢 ServiceLifecycleManager: All listeners started")
    }
    
    // MARK: - Pause (app backgrounded)
    
    private func pauseAllServices() {
        guard isListening else { return }
        
        CardService.shared.stopListening()
        UserService.shared.stopListening()
        FriendsService.shared.stopAllListeners()
        HeadToHeadService.shared.stopListening()
        MarketplaceService.shared.stopAllListeners()
        CommentService.shared.removeAllListeners()
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
        MarketplaceService.shared.listenToMyListings(uid: uid)
        MarketplaceService.shared.listenToMyBids(uid: uid)
        HotCardsService.shared.resumeTimer()
        
        // Active marketplace listings and FriendsService restart lazily from their tabs
        
        isListening = true
        print("▶️ ServiceLifecycleManager: Essential listeners resumed (app foregrounded)")
    }
    
    // MARK: - Stop All (logout)
    
    func stopAll() {
        CardService.shared.stopListening()
        UserService.shared.stopListening()
        FriendsService.shared.stopAllListeners()
        HeadToHeadService.shared.stopListening()
        MarketplaceService.shared.stopAllListeners()
        CommentService.shared.removeAllListeners()
        HotCardsService.shared.pauseTimer()
        HotCardsService.shared.reset()
        
        isListening = false
        print("🔴 ServiceLifecycleManager: All listeners stopped (logout)")
    }
}
