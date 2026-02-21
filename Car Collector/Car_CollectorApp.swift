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
                completeOnboarding()
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
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        UserDefaults.standard.set(true, forKey: "profileExists")
        startServices()
        showOnboarding = false
        isReady = true
    }
    
    private func checkAuthState() async {
        let startTime = Date()
        print("🕐 checkAuthState started")
        
        // Poll for auth listener to fire (typically < 100ms)
        var waitCount = 0
        while firebaseManager.isLoading && waitCount < 20 {
            try? await Task.sleep(nanoseconds: 25_000_000) // 25ms intervals
            waitCount += 1
        }
        
        print("🕐 Auth listener resolved in \(Int(Date().timeIntervalSince(startTime) * 1000))ms (waited \(waitCount) cycles)")
        
        if firebaseManager.isAuthenticated,
           let _ = firebaseManager.currentUserId {
            // Returning user — use cached flag to skip profileExists() network call
            let hasProfile = UserDefaults.standard.bool(forKey: "profileExists")
            
            if hasProfile {
                // FAST PATH: no network call, show UI immediately
                print("🕐 Fast path: cached profile exists")
                startServices()
                isReady = true
                print("🕐 Ready in \(Int(Date().timeIntervalSince(startTime) * 1000))ms")
            } else {
                // First time or cache miss — one-time server check
                print("🕐 Slow path: checking Firestore for profile...")
                do {
                    let exists = try await UserService.shared.profileExists(uid: firebaseManager.currentUserId!)
                    print("🕐 profileExists returned in \(Int(Date().timeIntervalSince(startTime) * 1000))ms")
                    if exists {
                        UserDefaults.standard.set(true, forKey: "profileExists")
                        startServices()
                        isReady = true
                    } else {
                        showOnboarding = true
                    }
                } catch {
                    print("❌ Auth check failed in \(Int(Date().timeIntervalSince(startTime) * 1000))ms: \(error)")
                    let completedBefore = UserDefaults.standard.bool(forKey: "onboardingComplete")
                    if completedBefore {
                        UserDefaults.standard.set(true, forKey: "profileExists")
                        startServices()
                        isReady = true
                    } else {
                        showOnboarding = true
                    }
                }
            }
        } else {
            print("🕐 Not authenticated after \(Int(Date().timeIntervalSince(startTime) * 1000))ms")
            let completedBefore = UserDefaults.standard.bool(forKey: "onboardingComplete")
            if !completedBefore {
                showOnboarding = true
            } else {
                do {
                    try await firebaseManager.signInAnonymously()
                    print("🕐 Re-auth done in \(Int(Date().timeIntervalSince(startTime) * 1000))ms")
                    startServices()
                    isReady = true
                } catch {
                    showOnboarding = true
                }
            }
        }
        print("🕐 checkAuthState complete in \(Int(Date().timeIntervalSince(startTime) * 1000))ms")
    }
    
    private func startServices() {
        let start = Date()
        guard let uid = firebaseManager.currentUserId else { return }
        
        UserService.shared.loadProfile(uid: uid)
        print("🕐 loadProfile started: \(Int(Date().timeIntervalSince(start) * 1000))ms")
        
        CardService.shared.listenToMyCards(uid: uid)
        print("🕐 listenToMyCards started: \(Int(Date().timeIntervalSince(start) * 1000))ms")
        
        MarketplaceService.shared.listenToMyListings(uid: uid)
        MarketplaceService.shared.listenToMyBids(uid: uid)
        print("🕐 marketplace listeners started: \(Int(Date().timeIntervalSince(start) * 1000))ms")
    }
}
