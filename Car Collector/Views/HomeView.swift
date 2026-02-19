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
    @ObservedObject private var friendsService = FriendsService.shared
    @ObservedObject private var navigationController = NavigationController.shared
    
    var body: some View {
        NavigationStack(path: $navigationController.homeNavigationPath) {
            VStack(spacing: 16) {
                Spacer()
                
                // Top row - Leaderboard and Friends
                HStack(spacing: 16) {
                    // Leaderboard
                    HomeContainer(
                        title: "Leaderboard",
                        icon: "chart.bar.fill",
                        gradient: [Color(red: 1.0, green: 0.8, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)],
                        action: { showLeaderboard = true }
                    )
                    
                    // Friends
                    HomeContainer(
                        title: "Friends",
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
                HStack(spacing: 16) {
                    // Sets (Coming Soon)
                    HomeContainer(
                        title: "Sets",
                        icon: "square.stack.3d.up.fill",
                        gradient: [Color.purple, Color.pink],
                        action: {},
                        disabled: true
                    )
                    .opacity(0.6)
                    
                    // Transfer List
                    HomeContainer(
                        title: "Transfer List",
                        icon: "doc.text.fill",
                        gradient: [Color.orange, Color.red],
                        action: { showTransferList = true }
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background {
                AppBackground(showFloatingShapes: true)
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
            .fullScreenCover(isPresented: $showLeaderboard) {
                LeaderboardView(isLandscape: isLandscape)
            }
            .onChange(of: navigationController.homeNavigationPath) { oldValue, newValue in
                if newValue.isEmpty {
                    showTransferList = false
                    showFriends = false
                    showLeaderboard = false
                    showExplore = false
                }
            }
            .onChange(of: navigationController.popToRootTrigger) { oldValue, newValue in
                showTransferList = false
                showFriends = false
                showLeaderboard = false
                showExplore = false
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
