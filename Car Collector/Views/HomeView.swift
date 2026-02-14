//
//  HomeView.swift
//  CarCardCollector
//
//  Home page view with new follower notification on Friends container
//

import SwiftUI

struct HomeView: View {
    var isLandscape: Bool = false
    @Binding var showProfile: Bool
    var levelSystem: LevelSystem
    var totalCards: Int
    @State private var showTransferList = false
    @State private var showFriends = false
    @ObservedObject private var friendsService = FriendsService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark blue background
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Top row - Daily Challenge and Friends
                        HStack(spacing: 16) {
                            // Daily Challenge
                            VStack(spacing: 12) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white)
                                
                                Text("Daily Challenge")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Text("Coming Soon")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.25, blue: 0.35), Color(red: 0.15, green: 0.2, blue: 0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            
                            // Friends - with new follower notification
                            Button(action: { showFriends = true }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.blue)
                                    
                                    Text("Friends")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    // New follower notification
                                    if friendsService.newFollowersCount > 0 {
                                        Text("+\(friendsService.newFollowersCount) New Follower\(friendsService.newFollowersCount == 1 ? "" : "s")")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.green)
                                    } else {
                                        Text("See Activity")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.25, blue: 0.35), Color(red: 0.15, green: 0.2, blue: 0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        
                        // Featured Collections - Hot Cards Carousel
                        HotCardsCarousel()
                            .padding(.horizontal)
                        
                        // Bottom row - Sets and Transfer List
                        HStack(spacing: 16) {
                            // Sets
                            VStack(spacing: 12) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white)
                                
                                Text("Sets")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                Text("Coming Soon")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.25, blue: 0.35), Color(red: 0.15, green: 0.2, blue: 0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            
                            // Transfer List - clickable with stats bar
                            Button(action: { showTransferList = true }) {
                                VStack(spacing: 0) {
                                    // Main content area - only top corners rounded
                                    VStack(spacing: 12) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 50))
                                            .foregroundStyle(.white)
                                        
                                        VStack(spacing: 2) {
                                            Text("0")
                                                .font(.system(size: 36, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text("Items")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 150)
                                    .background(
                                        UnevenRoundedRectangle(
                                            topLeadingRadius: 16,
                                            bottomLeadingRadius: 0,
                                            bottomTrailingRadius: 0,
                                            topTrailingRadius: 16
                                        )
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 0.2, green: 0.25, blue: 0.35), Color(red: 0.15, green: 0.2, blue: 0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    )
                                    
                                    // Stats bar - only bottom corners rounded
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Selling")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.6))
                                            Text("0")
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("Sold")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.6))
                                            Text("0")
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        UnevenRoundedRectangle(
                                            topLeadingRadius: 0,
                                            bottomLeadingRadius: 16,
                                            bottomTrailingRadius: 16,
                                            topTrailingRadius: 0
                                        )
                                        .fill(Color(red: 0.15, green: 0.2, blue: 0.3))
                                    )
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, isLandscape ? 20 : 100)
                }
                .ignoresSafeArea(edges: .bottom)
                .padding(.trailing, isLandscape ? 100 : 0)
                
                // Bottom blur gradient behind hub (portrait mode)
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.7), .black, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    .allowsHitTesting(false)
                    .transaction { transaction in
                        transaction.animation = nil // Appear instantly, no fade animation
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationDestination(isPresented: $showTransferList) {
                TransferListView(isLandscape: isLandscape)
            }
            .navigationDestination(isPresented: $showFriends) {
                FriendsView(isLandscape: isLandscape)
            }
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                OrientationManager.lockOrientation(.portrait)
            }
            .onDisappear {
                OrientationManager.unlockOrientation()
            }
        }
    }
}

#Preview {
    HomeView(showProfile: .constant(false), levelSystem: LevelSystem(), totalCards: 0)
}
