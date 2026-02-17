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
    
    var body: some Scene {
        WindowGroup {
            rootView
                .task {
                    await checkAuthState()
                }
        }
    }
    
    @ViewBuilder
    private var rootView: some View {
        if firebaseManager.isLoading {
            launchScreen
        } else if showOnboarding {
            OnboardingView(onComplete: {
                withAnimation {
                    showOnboarding = false
                    startServices()
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
            // Exact blue background matching the logo (#4F84C7)
            Color(red: 0.310, green: 0.521, blue: 0.784)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App Logo
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280, height: 280)
                
                // Loading indicator
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
        // Wait for Firebase auth to resolve
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        if firebaseManager.isAuthenticated,
           let uid = firebaseManager.currentUserId {
            // Returning user Ã¢â‚¬â€ check if profile exists
            do {
                let exists = try await UserService.shared.profileExists(uid: uid)
                if exists {
                    startServices()
                    withAnimation { isReady = true }
                } else {
                    // Auth exists but no profile (edge case)
                    withAnimation { showOnboarding = true }
                }
            } catch {
                print("Ã¢ÂÅ’ Auth check failed: \(error)")
                withAnimation { showOnboarding = true }
            }
        } else {
            // First launch or signed out
            let completedBefore = UserDefaults.standard.bool(forKey: "onboardingComplete")
            if !completedBefore {
                withAnimation { showOnboarding = true }
            } else {
                // Had account but signed out Ã¢â‚¬â€ try re-auth
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
        
        // Start real-time listeners
        UserService.shared.loadProfile(uid: uid)
        CardService.shared.listenToMyCards(uid: uid)
        
        isReady = true
        
        // Load cloud data into LevelSystem after a brief delay for profile to load
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // LevelSystem will be initialized in ContentView, sync happens via UserService
        }
    }
}
