//
//  HomeView.swift
//  CarCardCollector
//
//  Home page with container grid layout
//

import SwiftUI

struct HomeView: View {
    var isLandscape: Bool = false
    @Binding var showProfile: Bool
    var levelSystem: LevelSystem
    var totalCards: Int
    @State private var showTransferList = false
    @State private var showFriends = false
    @State private var showLeaderboard = false
    @State private var showExplore = false
    @State private var showHeadToHead = false
    @ObservedObject private var friendsService = FriendsService.shared
    @ObservedObject private var h2hService = HeadToHeadService.shared
    @ObservedObject private var navigationController = NavigationController.shared
    
    var body: some View {
        NavigationStack(path: $navigationController.homeNavigationPath) {
            VStack(spacing: DeviceScale.h(16)) {
                Spacer()
                
                // Top row - Leaderboard and Friends
                HStack(spacing: DeviceScale.w(16)) {
                    // Leaderboard
                    HomeContainer(
                        title: "LEADERBOARD",
                        icon: "chart.bar.fill",
                        gradient: [Color(red: 1.0, green: 0.8, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)],
                        action: { showLeaderboard = true }
                    )
                    
                    // Friends
                    HomeContainer(
                        title: "FRIENDS",
                        icon: "person.2.fill",
                        gradient: friendsService.newFollowersCount > 0 ? [Color.green, Color.teal] : [Color.blue, Color.cyan],
                        action: { showFriends = true }
                    )
                }
                .padding(.horizontal)
                
                // Featured Collections with title/timer header
                FeaturedCollectionsContainer(action: { showExplore = true })
                    .padding(.horizontal)
                
                // Bottom row - Sets and Transfer List
                HStack(spacing: DeviceScale.w(16)) {
                    // Head to Head
                    ZStack(alignment: .topTrailing) {
                        HomeContainer(
                            title: "HEAD TO HEAD",
                            icon: "flag.checkered",
                            gradient: [Color.red, Color.orange],
                            action: { showHeadToHead = true }
                        )
                        
                        // Pending challenges badge
                        if !h2hService.myPendingChallenges.isEmpty {
                            Text("\(h2hService.myPendingChallenges.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: -8, y: 8)
                        }
                    }
                    
                    // Transfer List
                    HomeContainer(
                        title: "TRANSFER LIST",
                        icon: "doc.text.fill",
                        gradient: [Color.orange, Color.red],
                        action: { showTransferList = true }
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background {
                AppBackground(animateShapes: true)
            }
            .navigationDestination(isPresented: $showTransferList) {
                TransferListView(isLandscape: isLandscape)
            }
            .navigationDestination(isPresented: $showFriends) {
                FriendsView(isLandscape: isLandscape)
            }
            .navigationDestination(isPresented: $showExplore) {
                ExploreView(isLandscape: isLandscape)
            }
            .navigationDestination(isPresented: $showHeadToHead) {
                HeadToHeadView(isLandscape: isLandscape)
            }
            .fullScreenCover(isPresented: $showLeaderboard) {
                LeaderboardView(isLandscape: isLandscape)
            }
            .onChange(of: navigationController.homeNavigationPath) { oldValue, newValue in
                if newValue.isEmpty {
                    showTransferList = false
                    showFriends = false
                    showLeaderboard = false
                    showExplore = false
                    showHeadToHead = false
                }
            }
            .onChange(of: showFriends) { _, isFriendsOpen in
                // Preserve Home tab while in friends feed (profiles are deep)
                if isFriendsOpen {
                    navigationController.preserveTab(1)
                } else {
                    navigationController.unpreserveTab(1)
                }
            }
            .onChange(of: navigationController.popToRootTrigger) { oldValue, newValue in
                // Only reset if Home tab is not preserved
                guard !navigationController.preservedTabs.contains(1) else { return }
                showTransferList = false
                showFriends = false
                showLeaderboard = false
                showExplore = false
                showHeadToHead = false
                navigationController.unpreserveTab(1)
                print("🏠 HomeView: Reset all navigation booleans from trigger")
            }
        }
    }
}

#Preview {
    HomeView(
        showProfile: .constant(false),
        levelSystem: LevelSystem(),
        totalCards: 10
    )
}
