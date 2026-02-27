//
//  HomeView.swift
//  CarCardCollector
//
//  Home dashboard — Crown Card showcase, active quests, recent feed,
//  H2H status, weekly stats. Content-rich landing experience.
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
    @ObservedObject private var dashboard = HomeDashboardService.shared
    @ObservedObject private var userService = UserService.shared
    
    var body: some View {
        NavigationStack(path: $navigationController.homeNavigationPath) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DeviceScale.h(16)) {
                    
                    // MARK: - Crown Card Showcase
                    crownCardSection
                    
                    // MARK: - Active Quest Strip
                    questStripSection
                    
                    // MARK: - H2H Status Banner
                    h2hStatusSection
                    
                    // MARK: - Recent Friend Activity
                    recentFeedSection
                    
                    // MARK: - Weekly Stats
                    weeklyStatsSection
                    
                    // MARK: - Quick Actions Row
                    quickActionsRow
                    
                    Spacer(minLength: DeviceScale.h(80))
                }
                .padding(.top, DeviceScale.h(8))
            }
            .refreshable {
                await dashboard.forceRefresh()
            }
            .background {
                Image("HomeBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(Color.black.opacity(0.45))
                    .drawingGroup()
                    .ignoresSafeArea()
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
                if isFriendsOpen {
                    navigationController.preserveTab(1)
                } else {
                    navigationController.unpreserveTab(1)
                }
            }
            .onChange(of: navigationController.popToRootTrigger) { oldValue, newValue in
                guard !navigationController.preservedTabs.contains(1) else { return }
                showTransferList = false
                showFriends = false
                showLeaderboard = false
                showExplore = false
                showHeadToHead = false
                navigationController.unpreserveTab(1)
                print("🏠 HomeView: Reset all navigation booleans from trigger")
            }
            .task {
                await dashboard.refreshAll()
            }
        }
    }
    
    // MARK: - Crown Card Showcase
    
    @ViewBuilder
    private var crownCardSection: some View {
        VStack(spacing: 0) {
            if dashboard.isLoadingCrown {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading showcase...")
                        .font(.pCaption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(height: DeviceScale.h(220))
            } else if let card = dashboard.crownCard, let image = dashboard.crownCardImage {
                // Crown card with 3D tilt
                VStack(spacing: DeviceScale.h(8)) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                            .font(.poppins(14))
                        Text("SHOWCASE")
                            .font(.poppins(14))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        if let rarity = card.rarity, let tier = CardRarity(rawValue: rarity) {
                            Text(tier.rawValue.uppercased())
                                .font(.poppins(11))
                                .foregroundStyle(tier.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(tier.color.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Card image with tilt effect and live rarity effects
                    let cardHeight = DeviceScale.h(200)
                    let cardWidth = cardHeight * (16/9)
                    let cornerRadius = cardHeight * 0.09
                    let parsedRarity = card.rarity.flatMap { CardRarity(rawValue: $0) }
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        // Unified holo + rarity effects (consolidated draw calls)
                        .unifiedCardEffects(rarity: parsedRarity, holoEffect: card.holoEffect)
                        .shadow(color: crownGlowColor(for: card).opacity(0.5), radius: 16, x: 0, y: 4)
                    
                    // Card name
                    Text("\(card.make.uppercased()) \(card.model.uppercased())")
                        .font(.poppins(16))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.vertical, DeviceScale.h(12))
            } else {
                // No crown card set — prompt
                Button {
                    navigationController.selectedTab = 4 // Go to Garage
                } label: {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.yellow.opacity(0.6))
                        }
                        
                        Text("SET YOUR CROWN CARD")
                            .font(.poppins(16))
                            .foregroundStyle(.white)
                        
                        Text("Star a card from your Garage to showcase it here")
                            .font(.poppins(12))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: DeviceScale.h(180))
                    .solidGlass(cornerRadius: 16)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Quest Strip
    
    @ViewBuilder
    private var questStripSection: some View {
        if !dashboard.quests.isEmpty {
            VStack(alignment: .leading, spacing: DeviceScale.h(8)) {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.orange)
                    Text("ACTIVE QUESTS")
                        .font(.poppins(14))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DeviceScale.w(12)) {
                        ForEach(dashboard.quests) { quest in
                            questCard(quest)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func questCard(_ quest: ActiveQuest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon and title
            HStack(spacing: 8) {
                Image(systemName: quest.icon)
                    .font(.poppins(16))
                    .foregroundStyle(quest.isComplete ? .green : .orange)
                
                Text(quest.title)
                    .font(.poppins(13))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            
            // Description
            Text(quest.description)
                .font(.poppins(11))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            quest.isComplete
                            ? LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * quest.progressFraction, height: 6)
                }
            }
            .frame(height: 6)
            
            // Progress text and reward
            HStack {
                Text("\(quest.progress)/\(quest.target)")
                    .font(.poppins(11))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                HStack(spacing: 3) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text("\(quest.rewardCoins)")
                        .font(.poppins(10))
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(12)
        .frame(width: DeviceScale.w(200))
        .solidGlass(cornerRadius: 12)
    }
    
    // MARK: - H2H Status Banner
    
    @ViewBuilder
    private var h2hStatusSection: some View {
        let pendingCount = h2hService.myPendingChallenges.count
        let activeCount = h2hService.activeRaces.count
        
        Button {
            showHeadToHead = true
        } label: {
            HStack(spacing: DeviceScale.w(12)) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DeviceScale.w(44), height: DeviceScale.w(44))
                    
                    Image(systemName: "bolt.fill")
                        .font(.poppins(20))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if pendingCount > 0 {
                        Text("YOU HAVE \(pendingCount) PENDING \(pendingCount == 1 ? "BATTLE" : "BATTLES")")
                            .font(.poppins(13))
                            .foregroundStyle(.white)
                    } else if activeCount > 0 {
                        Text("\(activeCount) LIVE \(activeCount == 1 ? "RACE" : "RACES") IN PROGRESS")
                            .font(.poppins(13))
                            .foregroundStyle(.white)
                    } else {
                        Text("HEAD TO HEAD")
                            .font(.poppins(13))
                            .foregroundStyle(.white)
                    }
                    
                    if pendingCount > 0 {
                        Text("Tap to respond")
                            .font(.poppins(11))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text("Challenge someone to a drag race!")
                            .font(.poppins(11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.poppins(14))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.red)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.poppins(14))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(DeviceScale.w(14))
            .solidGlass(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    // MARK: - Recent Friend Activity
    
    @ViewBuilder
    private var recentFeedSection: some View {
        VStack(alignment: .leading, spacing: DeviceScale.h(8)) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.cyan)
                Text("FRIEND ACTIVITY")
                    .font(.poppins(14))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button {
                    showFriends = true
                } label: {
                    Text("See All")
                        .font(.poppins(12))
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal)
            
            if dashboard.isLoadingFeed {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                }
                .frame(height: DeviceScale.h(100))
            } else if dashboard.recentFeed.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Follow people to see their captures here")
                        .font(.poppins(12))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: DeviceScale.h(100))
                .solidGlass(cornerRadius: 12)
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DeviceScale.w(12)) {
                        ForEach(dashboard.recentFeed) { activity in
                            feedCardThumbnail(activity)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private func feedCardThumbnail(_ activity: FriendActivity) -> some View {
        let cardHeight = DeviceScale.h(140)
        
        return VStack(alignment: .leading, spacing: 6) {
            // Card image
            FIFACardView(card: activity, height: cardHeight, onSingleTap: {
                showFriends = true
            })
            .frame(width: cardHeight * (16/9), height: cardHeight)
            
            // Username and time
            HStack {
                Text(activity.username)
                    .font(.poppins(11))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(activity.timeAgo)
                    .font(.poppins(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(width: cardHeight * (16/9))
        }
    }
    
    // MARK: - Weekly Stats
    
    @ViewBuilder
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: DeviceScale.h(8)) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.yellow)
                Text("THIS WEEK")
                    .font(.poppins(14))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: DeviceScale.w(8)) {
                statTile(
                    value: "\(dashboard.weeklyStats.cardsThisWeek)",
                    label: "Cards",
                    icon: "camera.fill",
                    color: .cyan
                )
                
                statTile(
                    value: "\(dashboard.weeklyStats.h2hWins)/\(dashboard.weeklyStats.h2hTotal)",
                    label: "H2H Wins",
                    icon: "bolt.fill",
                    color: .orange
                )
                
                statTile(
                    value: "\(dashboard.weeklyStats.heatsReceived)",
                    label: "Heats",
                    icon: "flame.fill",
                    color: .red
                )
                
                statTile(
                    value: "\(totalCards)",
                    label: "Total",
                    icon: "square.stack.3d.up.fill",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
    
    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.poppins(16))
                .foregroundStyle(color)
            
            Text(value)
                .font(.poppins(18))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.poppins(10))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DeviceScale.h(12))
        .solidGlass(cornerRadius: 12)
    }
    
    // MARK: - Quick Actions Row (secondary nav)
    
    @ViewBuilder
    private var quickActionsRow: some View {
        VStack(alignment: .leading, spacing: DeviceScale.h(8)) {
            HStack {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundStyle(.white.opacity(0.5))
                Text("QUICK ACCESS")
                    .font(.poppins(14))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(spacing: DeviceScale.w(12)) {
                quickActionButton(
                    title: "Leaderboard",
                    icon: "chart.bar.fill",
                    gradient: [Color(red: 1.0, green: 0.8, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)]
                ) {
                    showLeaderboard = true
                }
                
                quickActionButton(
                    title: "Explore",
                    icon: "globe",
                    gradient: [.green, .cyan]
                ) {
                    showExplore = true
                }
                
                quickActionButton(
                    title: "Transfer List",
                    icon: "doc.text.fill",
                    gradient: [Color(red: 0.6, green: 0.2, blue: 1.0), Color(red: 0.35, green: 0.1, blue: 0.8)]
                ) {
                    showTransferList = true
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func quickActionButton(title: String, icon: String, gradient: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: DeviceScale.w(40), height: DeviceScale.w(40))
                    
                    Image(systemName: icon)
                        .font(.poppins(16))
                        .foregroundStyle(.white)
                }
                
                Text(title)
                    .font(.poppins(11))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DeviceScale.h(12))
            .solidGlass(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private func crownGlowColor(for card: CloudCard) -> Color {
        guard let rarityString = card.rarity,
              let rarity = CardRarity(rawValue: rarityString) else {
            return .white
        }
        return rarity.color
    }
}

#Preview {
    HomeView(
        showProfile: .constant(false),
        levelSystem: LevelSystem(),
        totalCards: 10
    )
}
