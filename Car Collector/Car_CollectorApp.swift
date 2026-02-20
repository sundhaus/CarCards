//
//  CarCardCollectorApp.swift
//  CarCardCollector
//
//  Updated with Firebase integration + anonymous auth onboarding
//  Created for iOS 17.0+, Xcode 16.0
//

import SwiftUI
import FirebaseCore

@main
struct CarCardCollectorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showOnboarding = false
    @State private var isReady = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    // Migrate card images from UserDefaults to files (one-time)
                    CardStorage.migrateIfNeeded()
                    await checkAuthState()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        OrientationManager.forcePortrait()
                    }
                }
        }
    }
    
    @ViewBuilder
    private var rootView: some View {
        if showOnboarding {
            OnboardingView(onComplete: {
                // Cache that onboarding is done and profile exists
                UserDefaults.standard.set(true, forKey: "onboardingComplete")
                UserDefaults.standard.set(true, forKey: "profileExists")
                withAnimation {
                    showOnboarding = false
                }
                startServices()
                withAnimation {
                    isReady = true
                }
            })
        } else if isReady {
            ContentView()
        } else {
            launchScreen
        }
    }
    
    private var launchScreen: some View {
        ZStack {
            Color(red: 0.310, green: 0.521, blue: 0.784)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280, height: 280)
                
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
        }
    }
    
    private func checkAuthState() async {
        // Poll for auth listener to fire (typically < 100ms, no fixed delay)
        var waitCount = 0
        while firebaseManager.isLoading && waitCount < 40 {
            try? await Task.sleep(nanoseconds: 25_000_000) // 25ms intervals
            waitCount += 1
        }
        
        // Safety: if still loading after 1s, force proceed
        if firebaseManager.isLoading {
            print("⚠️ Auth listener slow, checking cached state")
        }
        
        if firebaseManager.isAuthenticated,
           let _ = firebaseManager.currentUserId {
            // Returning user — use cached flag to skip profileExists() network call
            let hasProfile = UserDefaults.standard.bool(forKey: "profileExists")
            
            if hasProfile {
                // FAST PATH: no network call, show UI immediately
                startServices()
                withAnimation { isReady = true }
            } else {
                // First time or cache miss — one-time server check
                do {
                    let exists = try await UserService.shared.profileExists(uid: firebaseManager.currentUserId!)
                    if exists {
                        UserDefaults.standard.set(true, forKey: "profileExists")
                        startServices()
                        withAnimation { isReady = true }
                    } else {
                        withAnimation { showOnboarding = true }
                    }
                } catch {
                    print("❌ Auth check failed: \(error)")
                    // Optimistic: if onboarding was done before, trust the cache
                    let completedBefore = UserDefaults.standard.bool(forKey: "onboardingComplete")
                    if completedBefore {
                        UserDefaults.standard.set(true, forKey: "profileExists")
                        startServices()
                        withAnimation { isReady = true }
                    } else {
                        withAnimation { showOnboarding = true }
                    }
                }
            }
        } else {
            // Not authenticated
            let completedBefore = UserDefaults.standard.bool(forKey: "onboardingComplete")
            if !completedBefore {
                withAnimation { showOnboarding = true }
            } else {
                // Had account but signed out — try re-auth
                do {
                    try await firebaseManager.signInAnonymously()
                    startServices()
                    withAnimation { isReady = true }
                } catch {
                    withAnimation { showOnboarding = true }
                }
            }
        }
    }
    
    private func startServices() {
        guard let uid = firebaseManager.currentUserId else { return }
        
        // Start real-time listeners immediately — no artificial delay
        UserService.shared.loadProfile(uid: uid)
        CardService.shared.listenToMyCards(uid: uid)
        
        // Marketplace listeners — my listings (Transfer List) and my bids (Transfer Targets)
        MarketplaceService.shared.listenToMyListings(uid: uid)
        MarketplaceService.shared.listenToMyBids(uid: uid)
        
        isReady = true
        // LevelSystem syncs via UserService listener, no sleep needed
    }
}
