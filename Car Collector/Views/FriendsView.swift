//
//  FriendsView.swift
//  CarCardCollector
//
//  Friends feed showing recent card additions from people you follow
//  Now with Heat system for identifying top weekly cards
//

import SwiftUI

struct FriendsView: View {
    var isLandscape: Bool = false
    @StateObject private var friendsService = FriendsService.shared
    @State private var showFriendsList = false
    @State private var showSearch = false
    @State private var fullScreenActivity: FriendActivity? = nil
    @Environment(\.dismiss) private var dismiss
    
    // Generate gradient colors based on level (same as LevelHeader)
    private func levelGradient(for level: Int) -> [Color] {
        let colors: [Color] = [
            .red,
            Color(red: 1.0, green: 0.5, blue: 0.0), // Orange
            .yellow,
            .green,
            .cyan,
            .blue,
            Color(red: 0.5, green: 0.0, blue: 1.0), // Purple
            Color(red: 1.0, green: 0.0, blue: 1.0), // Magenta
            .red // Complete the cycle
        ]
        
        let cycleLength = 80
        let position = (level - 1) % cycleLength
        let segmentLength = 10
        let colorIndex = position / segmentLength
        
        let startColor = colors[colorIndex]
        let endColor = colors[colorIndex + 1]
        
        return [startColor, endColor]
    }
    
    var body: some View {
        ZStack {
                // Dark blue background
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header banner
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.pTitle3)
                                .foregroundStyle(.primary)
                        }
                        
                        Text("FRIENDS")
                            .font(.pTitle2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                showFriendsList = true
                            }
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.pTitle3)
                                    .foregroundStyle(.primary)
                                
                                // Notification badge
                                if friendsService.newFollowersCount > 0 {
                                    ZStack {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 18, height: 18)
                                        
                                        Text("\(friendsService.newFollowersCount)")
                                            .font(.poppins(10))
                                            .foregroundStyle(.primary)
                                    }
                                    .offset(x: 8, y: -8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 18)
                    .padding(.bottom, 10)
                    .glassEffect(.regular, in: .rect)
                    
                    // Friends activity feed
                    ScrollView {
                        VStack(spacing: 0) {
                            if friendsService.isLoading {
                                ProgressView()
                                    .padding(.top, 60)
                            } else if friendsService.friendActivities.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.2")
                                        .font(.poppins(50))
                                        .foregroundStyle(.gray)
                                    Text("No recent activity")
                                        .foregroundStyle(.secondary)
                                    Text("Follow people to see their cards")
                                        .font(.pCaption)
                                        .foregroundStyle(.secondary)
                                    
                                    Button(action: {
                                        showSearch = true
                                    }) {
                                        HStack {
                                            Image(systemName: "person.badge.plus")
                                            Text("Find People")
                                        }
                                        .font(.pSubheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(.blue)
                                        .cornerRadius(20)
                                    }
                                    .padding(.top, 8)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .padding(.top, 60)
                            } else {
                                ForEach(friendsService.friendActivities) { activity in
                                    FriendActivityCard(
                                        activity: activity,
                                        levelGradient: levelGradient(for: activity.level),
                                        onCardTap: {
                                            fullScreenActivity = activity
                                        }
                                    )
                                    
                                    if activity.id != friendsService.friendActivities.last?.id {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.08))
                                            .frame(height: 1)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.bottom, isLandscape ? 20 : 100)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .padding(.trailing, isLandscape ? 100 : 0)
                
                // Friends/Following/Followers list popup
                if showFriendsList {
                    FollowListPopup(
                        isShowing: $showFriendsList,
                        onSearch: {
                            showFriendsList = false
                            showSearch = true
                        },
                        levelGradient: levelGradient
                    )
                }
                
                // Search/Follow users popup
                if showSearch {
                    SearchUsersView(isShowing: $showSearch)
                }
                
                // Bottom blur gradient behind hub (portrait mode)
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .clear, Color(.systemGray6).opacity(0.7), Color(.systemGray6), Color(.systemGray6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea(edges: .bottom)
                
                // Fullscreen card overlay
                if let activity = fullScreenActivity {
                    FullScreenFriendCardView(
                        activity: activity,
                        isShowing: Binding(
                            get: { fullScreenActivity != nil },
                            set: { if !$0 { fullScreenActivity = nil } }
                        )
                    )
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                startListeners()
            }
    }
    
    private func startListeners() {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        friendsService.listenToFollows(uid: uid)
        friendsService.listenToFriendActivities(uid: uid)
    }
}

// Individual friend activity card in feed
struct FriendActivityCard: View {
    let activity: FriendActivity
    let levelGradient: [Color]
    var onCardTap: () -> Void
    
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    @State private var profileImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Friend info header — taps navigate to profile
            NavigationLink {
                UserProfileView(userId: activity.userId, username: activity.username)
            } label: {
                HStack(spacing: 8) {
                    // Profile picture
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: levelGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text(String(activity.username.prefix(1)).uppercased())
                                    .font(.poppins(14))
                                    .foregroundStyle(.white)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.username)
                            .font(.pSubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("added a card")
                            .font(.pCaption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(activity.timeAgo)
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Card preview — tap opens fullscreen
            FIFACardView(card: activity, height: 202.5)
                .frame(width: 360, height: 202.5)
                .onTapGesture {
                    onCardTap()
                }
                .padding(.horizontal)
                .padding(.bottom, 14)
        }
        .task {
            await loadCardImage()
            await loadProfilePicture()
        }
    }
    
    private func loadCardImage() async {
        isLoadingImage = true
        
        do {
            let image = try await CardService.shared.loadImage(from: activity.imageURL)
            await MainActor.run {
                cardImage = image
                isLoadingImage = false
            }
        } catch {
            print("❌ Failed to load card image: \(error)")
            await MainActor.run {
                isLoadingImage = false
            }
        }
    }
    
    private func loadProfilePicture() async {
        do {
            if let profile = try await UserService.shared.fetchProfile(uid: activity.userId),
               let urlString = profile.profilePictureURL {
                let image = try await CardService.shared.loadImage(from: urlString)
                await MainActor.run {
                    profileImage = image
                }
            }
        } catch {
            print("⚠️ Failed to load profile picture: \(error)")
        }
    }
}


// Friends/Following/Followers list popup
struct FollowListPopup: View {
    @Binding var isShowing: Bool
    var onSearch: () -> Void
    var levelGradient: (Int) -> [Color]
    @StateObject private var friendsService = FriendsService.shared
    @State private var selectedTab: FollowTab = .friends
    
    enum FollowTab: String, CaseIterable {
        case friends = "FRIENDS"
        case following = "FOLLOWING"
        case followers = "FOLLOWERS"
    }
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }
            
            // Popup card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(selectedTab.rawValue)
                        .font(.pTitle2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.pTitle2)
                            .foregroundStyle(.gray)
                    }
                }
                .padding()
                
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(FollowTab.allCases, id: \.self) { tab in
                        TabButton(
                            title: tab.rawValue,
                            count: countForTab(tab),
                            notificationCount: tab == .followers ? friendsService.newFollowersCount : nil,
                            isSelected: selectedTab == tab,
                            action: {
                                withAnimation {
                                    selectedTab = tab
                                    if tab == .followers {
                                        friendsService.markFollowersAsViewed()
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // List content
                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .friends:
                            if friendsService.friends.isEmpty {
                                emptyStateView(message: "No mutual friends yet")
                            } else {
                                ForEach(friendsService.friends) { person in
                                    FollowRow(person: person, levelGradient: levelGradient(person.level))
                                    if person.id != friendsService.friends.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            
                        case .following:
                            if friendsService.following.isEmpty {
                                emptyStateView(message: "You're not following anyone yet")
                            } else {
                                ForEach(friendsService.following) { person in
                                    FollowRow(person: person, levelGradient: levelGradient(person.level))
                                    if person.id != friendsService.following.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            
                        case .followers:
                            if friendsService.followers.isEmpty {
                                emptyStateView(message: "No followers yet")
                            } else {
                                ForEach(friendsService.followers) { person in
                                    FollowRow(person: person, levelGradient: levelGradient(person.level))
                                    if person.id != friendsService.followers.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                
                // Bottom button
                Button(action: {
                    onSearch()
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Find People to Follow")
                    }
                    .font(.pSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .cornerRadius(12)
                }
                .padding()
            }
            .frame(maxWidth: 500)
            .background(.regularMaterial)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(40)
        }
        .transition(.opacity)
    }
    
    private func countForTab(_ tab: FollowTab) -> Int {
        switch tab {
        case .friends:
            return friendsService.friends.count
        case .following:
            return friendsService.following.count
        case .followers:
            return friendsService.followers.count
        }
    }
    
    @ViewBuilder
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.poppins(40))
                .foregroundStyle(.gray)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// Tab button
struct TabButton: View {
    let title: String
    let count: Int
    let notificationCount: Int?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.pSubheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                HStack(spacing: 4) {
                    Text("\(count)")
                        .font(.pCaption)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                    
                    // Notification badge
                    if let notificationCount = notificationCount, notificationCount > 0 {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 16, height: 16)
                            
                            Text("\(notificationCount)")
                                .font(.poppins(9))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(isSelected ? Color.blue : Color.clear)
                        .frame(height: 2)
                }
            )
        }
    }
}

// Search users view — live search as you type
struct SearchUsersView: View {
    @Binding var isShowing: Bool
    @State private var searchQuery = ""
    @State private var searchResults: [FriendProfile] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }
            
            // Search popup
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Find People")
                        .font(.pTitle2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.pTitle2)
                            .foregroundStyle(.gray)
                    }
                }
                .padding()
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search by username", text: $searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: searchQuery) { _, newValue in
                            if newValue.isEmpty {
                                searchResults = []
                                hasSearched = false
                                searchTask?.cancel()
                                isSearching = false
                            } else {
                                performDebouncedSearch()
                            }
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            searchResults = []
                            hasSearched = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Messages
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.pCaption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                
                if let successMessage = successMessage {
                    Text(successMessage)
                        .font(.pCaption)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                
                Divider()
                
                // Search results
                ScrollView {
                    VStack(spacing: 0) {
                        if searchQuery.isEmpty {
                            // Idle state
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.poppins(40))
                                    .foregroundStyle(.gray.opacity(0.5))
                                Text("Type a username to search")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else if searchResults.isEmpty && hasSearched && !isSearching {
                            VStack(spacing: 12) {
                                Image(systemName: "person.fill.questionmark")
                                    .font(.poppins(40))
                                    .foregroundStyle(.gray)
                                Text("No users found")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            ForEach(searchResults) { user in
                                SearchResultRow(
                                    user: user,
                                    onFollow: { followUser(user) },
                                    onUnfollow: { unfollowUser(user) }
                                )
                                
                                if user.id != searchResults.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
            .frame(maxWidth: 500)
            .background(.regularMaterial)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(40)
        }
        .transition(.opacity)
    }
    
    // MARK: - Debounced Search
    
    private func performDebouncedSearch() {
        // Cancel previous search
        searchTask?.cancel()
        
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            searchResults = []
            hasSearched = false
            isSearching = false
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        searchTask = Task {
            // Debounce: wait 300ms so we don't fire on every keystroke
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard !Task.isCancelled else { return }
            
            do {
                let results = try await UserService.shared.searchUsers(query: query)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    searchResults = results.map { FriendProfile(profile: $0) }
                    hasSearched = true
                    isSearching = false
                    
                    // Update follow status for results
                    updateFollowStatus()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                    hasSearched = true
                }
            }
        }
    }
    
    private func updateFollowStatus() {
        guard let myUid = FirebaseManager.shared.currentUserId else { return }
        
        let followingIds = Set(FriendsService.shared.following.map { $0.id })
        let followerIds = Set(FriendsService.shared.followers.map { $0.id })
        
        for index in searchResults.indices {
            let userId = searchResults[index].id
            
            // Skip current user
            if userId == myUid {
                continue
            }
            
            searchResults[index].isFollowing = followingIds.contains(userId)
            searchResults[index].followsMe = followerIds.contains(userId)
            searchResults[index].isFriend = followingIds.contains(userId) && followerIds.contains(userId)
        }
    }
    
    private func followUser(_ user: FriendProfile) {
        Task {
            do {
                try await FriendsService.shared.followUser(userId: user.id)
                
                await MainActor.run {
                    successMessage = "Now following \(user.username)"
                    
                    // Update local state
                    if let index = searchResults.firstIndex(where: { $0.id == user.id }) {
                        searchResults[index].isFollowing = true
                        searchResults[index].isFriend = searchResults[index].followsMe
                    }
                    
                    // Clear success message after delay
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            successMessage = nil
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func unfollowUser(_ user: FriendProfile) {
        Task {
            do {
                try await FriendsService.shared.unfollowUser(userId: user.id)
                
                await MainActor.run {
                    if let index = searchResults.firstIndex(where: { $0.id == user.id }) {
                        searchResults[index].isFollowing = false
                        searchResults[index].isFriend = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}


// Individual follow row
struct FollowRow: View {
    let person: FriendProfile
    let levelGradient: [Color]
    
    var body: some View {
        NavigationLink {
            UserProfileView(userId: person.id, username: person.username)
        } label: {
            HStack(spacing: 12) {
                // Level bubble
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: levelGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Text("\(person.level)")
                        .font(.poppins(16))
                        .foregroundStyle(.primary)
                }
                
                // Username and stats
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(person.username)
                            .font(.pSubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        if person.isFriend {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.pCaption)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Text("\(person.totalCards) cards")
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Follow status indicator
                if person.followsMe && !person.isFollowing {
                    Text("Follows you")
                        .font(.pCaption)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }
}

// Search result row
struct SearchResultRow: View {
    let user: FriendProfile
    let onFollow: () -> Void
    let onUnfollow: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Tappable user info area
            NavigationLink {
                UserProfileView(userId: user.id, username: user.username)
            } label: {
                HStack(spacing: 12) {
                    // Profile circle placeholder
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(user.username.prefix(1)).uppercased())
                                .font(.pHeadline)
                                .foregroundStyle(.primary)
                        )
                    
                    // Username and stats
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(user.username)
                                .font(.pSubheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            if user.isFriend {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.pCaption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Text("Level \(user.level)")
                                .font(.pCaption)
                                .foregroundStyle(.secondary)
                            
                            Text("•")
                                .foregroundStyle(.secondary)
                            
                            Text("\(user.totalCards) cards")
                                .font(.pCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Follow/Following button
            if user.isFollowing {
                Button(action: onUnfollow) {
                    Text("FOLLOWING")
                        .font(.pCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue)
                        .cornerRadius(12)
                }
            } else {
                Button(action: onFollow) {
                    Image(systemName: "person.badge.plus")
                        .font(.pTitle3)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    FriendsView()
}
