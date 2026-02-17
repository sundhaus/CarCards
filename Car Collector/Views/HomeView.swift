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
            ScrollView {
                VStack(spacing: 16) {
                    // Simplified Level header (no redundant info)
                    homeHeader
                    
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
                    .padding(.bottom, isLandscape ? 20 : 100)
                }
                .padding(.top, isLandscape ? 20 : 0)
            }
            .background(Color.appBackgroundSolid.ignoresSafeArea())
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
            .toolbar(.hidden, for: .tabBar)
        }
    }
    
    private var homeHeader: some View {
        HStack(spacing: 16) {
            // Profile button
            Button(action: { showProfile = true }) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            
            // Level and XP progress
            VStack(alignment: .leading, spacing: 4) {
                Text("LEVEL \(levelSystem.level)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                
                HStack(spacing: 4) {
                    Text("\(levelSystem.currentXP)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("/ \(levelSystem.xpForNextLevel) XP")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Coins
            HStack(spacing: 8) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.yellow)
                
                Text("\(levelSystem.coins)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, isLandscape ? 8 : 16)
    }
}

#Preview {
    HomeView(
        showProfile: .constant(false),
        levelSystem: LevelSystem(),
        totalCards: 10
    )
}
