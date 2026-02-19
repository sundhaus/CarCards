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
                Color.appBackgroundSolid
                    .ignoresSafeArea(edges: .all)
                
                VStack(spacing: 0) {
                    // Glass segmented tabs
                    HStack(spacing: 6) {
                        ForEach(["Cards", "Heat", "Earnings"], id: \.self) { tab in
                            let index = ["Cards", "Heat", "Earnings"].firstIndex(of: tab)!
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = index
                                }
                            }) {
                                Text(tab)
                                    .font(.pSubheadline)
                                    .fontWeight(selectedTab == index ? .semibold : .regular)
                                    .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background {
                                        if selectedTab == index {
                                            Capsule()
                                                .fill(.white.opacity(0.15))
                                        }
                                    }
                            }
                        }
                    }
                    .padding(4)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    // Tab Content
                    if selectedTab == 0 {
                        CardsLeaderboard(entries: leaderboardService.cardsLeaderboard)
                    } else if selectedTab == 1 {
                        HeatLeaderboard(entries: leaderboardService.heatLeaderboard)
                    } else {
                        EarningsLeaderboard(entries: leaderboardService.earningsLeaderboard)
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.bottom, isLandscape ? 0 : 100)
                .padding(.trailing, isLandscape ? 100 : 0)
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
                        .font(.poppins(60))
                        .foregroundStyle(.gray)
                    Text("No data available")
                        .font(.pTitle2)
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
                        .font(.poppins(60))
                        .foregroundStyle(.gray)
                    Text("No data available")
                        .font(.pTitle2)
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
                        .font(.poppins(60))
                        .foregroundStyle(.gray)
                    Text("No data available")
                        .font(.pTitle2)
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
                    .font(.poppins(18))
                    .foregroundStyle(.white)
            }
            
            // Username
            VStack(alignment: .leading, spacing: 2) {
                Text(username)
                    .font(.pHeadline)
                    .foregroundStyle(isCurrentUser ? .blue : .primary)
                
                if isCurrentUser {
                    Text("You")
                        .font(.pCaption)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            // Value
            HStack(spacing: 4) {
                Text(value)
                    .font(.poppins(20))
                    .foregroundStyle(.primary)
                
                Text(suffix)
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
            }
            
            // Chevron for other users
            if !isCurrentUser {
                Image(systemName: "chevron.right")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.15) : Color.white.opacity(0.08))
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
