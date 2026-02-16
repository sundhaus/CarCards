//
//  LeaderboardView.swift
//  CarCardCollector
//
//  Leaderboard with three tabs: Cards Collected, Total Heat, Earnings
//

import SwiftUI

struct LeaderboardView: View {
    var isLandscape: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @ObservedObject private var leaderboardService = LeaderboardService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gray backdrop that extends entire page
                Color(.systemGray6)
                    .ignoresSafeArea(edges: .all)
                
                VStack(spacing: 0) {
                    // File folder-style tabs
                    ZStack(alignment: .bottom) {
                        Color.clear
                            .frame(height: 60)
                        
                        HStack(spacing: 0) {
                            // Cards Collected Tab
                            Button(action: {
                                selectedTab = 0
                            }) {
                                Text("Cards")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(selectedTab == 0 ? .primary : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        GeometryReader { geo in
                                            VStack(spacing: 0) {
                                                if selectedTab == 0 {
                                                    UnevenRoundedRectangle(
                                                        topLeadingRadius: 12,
                                                        topTrailingRadius: 12
                                                    )
                                                    .fill(.white)
                                                } else {
                                                    UnevenRoundedRectangle(
                                                        topLeadingRadius: 12,
                                                        topTrailingRadius: 12
                                                    )
                                                    .fill(Color(.systemGray5))
                                                }
                                            }
                                        }
                                    )
                            }
                            .overlay(alignment: .trailing) {
                                if selectedTab != 0 {
                                    Rectangle()
                                        .fill(Color(.systemGray4))
                                        .frame(width: 1)
                                        .padding(.vertical, 8)
                                }
                            }
                            
                            // Total Heat Tab
                            Button(action: {
                                selectedTab = 1
                            }) {
                                Text("Heat")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(selectedTab == 1 ? .primary : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        GeometryReader { geo in
                                            VStack(spacing: 0) {
                                                if selectedTab == 1 {
                                                    UnevenRoundedRectangle(
                                                        topLeadingRadius: 12,
                                                        topTrailingRadius: 12
                                                    )
                                                    .fill(.white)
                                                } else {
                                                    UnevenRoundedRectangle(
                                                        topLeadingRadius: 12,
                                                        topTrailingRadius: 12
                                                    )
                                                    .fill(Color(.systemGray5))
                                                }
                                            }
                                        }
                                    )
                            }
                            .overlay(alignment: .trailing) {
                                if selectedTab != 1 {
                                    Rectangle()
                                        .fill(Color(.systemGray4))
                                        .frame(width: 1)
                                        .padding(.vertical, 8)
                                }
                            }
                            
                            // Earnings Tab
                            Button(action: {
                                selectedTab = 2
                            }) {
                                Text("Earnings")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(selectedTab == 2 ? .primary : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        GeometryReader { geo in
                                            VStack(spacing: 0) {
                                                if selectedTab == 2 {
                                                    UnevenRoundedRectangle(
                                                        topLeadingRadius: 12,
                                                        topTrailingRadius: 12
                                                    )
                                                    .fill(.white)
                                                } else {
                                                    UnevenRoundedRectangle(
                                                        topLeadingRadius: 12,
                                                        topTrailingRadius: 12
                                                    )
                                                    .fill(Color(.systemGray5))
                                                }
                                            }
                                        }
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Content area - white background extending to bottom
                    ZStack(alignment: .top) {
                        Color.white
                            .ignoresSafeArea(edges: .bottom)
                        
                        VStack(spacing: 0) {
                            Spacer()
                                .frame(height: 16)
                            
                            // Tab Content
                            if selectedTab == 0 {
                                CardsLeaderboard(entries: leaderboardService.cardsLeaderboard)
                            } else if selectedTab == 1 {
                                HeatLeaderboard(entries: leaderboardService.heatLeaderboard)
                            } else {
                                EarningsLeaderboard(entries: leaderboardService.earningsLeaderboard)
                            }
                        }
                        .ignoresSafeArea(edges: .bottom)
                        .padding(.bottom, isLandscape ? 0 : 100)
                        .padding(.trailing, isLandscape ? 100 : 0)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            leaderboardService.fetchLeaderboards()
        }
    }
}

// MARK: - Cards Leaderboard

struct CardsLeaderboard: View {
    let entries: [LeaderboardEntry]
    @State private var selectedUserId: String?
    @State private var selectedUsername: String?
    @State private var showProfile = false
    
    var body: some View {
        ScrollView {
            if entries.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No data available")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(minHeight: 300)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        Button(action: {
                            // Don't navigate if it's the current user
                            guard !entry.isCurrentUser else { return }
                            selectedUserId = entry.id
                            selectedUsername = entry.username
                            showProfile = true
                        }) {
                            LeaderboardRow(
                                rank: index + 1,
                                username: entry.username,
                                value: "\(entry.value)",
                                suffix: entry.value == 1 ? "card" : "cards",
                                isCurrentUser: entry.isCurrentUser
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let userId = selectedUserId, let username = selectedUsername {
                UserProfileView(userId: userId, username: username)
            }
        }
    }
}

// MARK: - Heat Leaderboard

struct HeatLeaderboard: View {
    let entries: [LeaderboardEntry]
    @State private var selectedUserId: String?
    @State private var selectedUsername: String?
    @State private var showProfile = false
    
    var body: some View {
        ScrollView {
            if entries.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "flame")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No data available")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(minHeight: 300)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        Button(action: {
                            // Don't navigate if it's the current user
                            guard !entry.isCurrentUser else { return }
                            selectedUserId = entry.id
                            selectedUsername = entry.username
                            showProfile = true
                        }) {
                            LeaderboardRow(
                                rank: index + 1,
                                username: entry.username,
                                value: "\(entry.value)",
                                suffix: "🔥",
                                isCurrentUser: entry.isCurrentUser
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let userId = selectedUserId, let username = selectedUsername {
                UserProfileView(userId: userId, username: username)
            }
        }
    }
}

// MARK: - Earnings Leaderboard

struct EarningsLeaderboard: View {
    let entries: [LeaderboardEntry]
    @State private var selectedUserId: String?
    @State private var selectedUsername: String?
    @State private var showProfile = false
    
    var body: some View {
        ScrollView {
            if entries.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No data available")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(minHeight: 300)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        Button(action: {
                            // Don't navigate if it's the current user
                            guard !entry.isCurrentUser else { return }
                            selectedUserId = entry.id
                            selectedUsername = entry.username
                            showProfile = true
                        }) {
                            LeaderboardRow(
                                rank: index + 1,
                                username: entry.username,
                                value: "\(entry.value)",
                                suffix: "coins",
                                isCurrentUser: entry.isCurrentUser
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let userId = selectedUserId, let username = selectedUsername {
                UserProfileView(userId: userId, username: username)
            }
        }
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let username: String
    let value: String
    let suffix: String
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 40, height: 40)
                
                Text("\(rank)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            // Username
            VStack(alignment: .leading, spacing: 2) {
                Text(username)
                    .font(.headline)
                    .foregroundStyle(isCurrentUser ? .blue : .primary)
                
                if isCurrentUser {
                    Text("You")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            // Value
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text(suffix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Chevron for other users
            if !isCurrentUser {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1:
            return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2:
            return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3:
            return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default:
            return Color(.systemGray)
        }
    }
}

#Preview {
    LeaderboardView()
}
