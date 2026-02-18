//
//  UserProfileView.swift
//  CarCardCollector
//
//  View to display another user's profile and their garage
//  Now includes relationship status bar with Follow/Follow Back/Following/Friends
//

import SwiftUI

struct UserProfileView: View {
    let userId: String
    let username: String // Pass this in for immediate display
    @Environment(\.dismiss) private var dismiss
    
    @State private var userProfile: UserProfile?
    @State private var userCards: [CloudCard] = []
    @State private var profileImage: UIImage?
    @State private var isLoadingProfile = true
    @State private var isLoadingCards = true
    @State private var cardsPerRow = 2
    @State private var followStats: (friends: Int, following: Int, followers: Int) = (0, 0, 0)
    @State private var isFollowing = false
    @State private var followsMe = false
    
    @ObservedObject private var friendsService = FriendsService.shared
    
    // Computed property for relationship status
    private var relationshipStatus: RelationshipStatus {
        if isFollowing && followsMe {
            return .friends
        } else if isFollowing {
            return .following
        } else if followsMe {
            return .followBack
        } else {
            return .notFollowing
        }
    }
    
    enum RelationshipStatus {
        case notFollowing
        case followBack
        case following
        case friends
        
        var buttonText: String {
            switch self {
            case .notFollowing: return "Follow"
            case .followBack: return "Follow Back"
            case .following: return "Following"
            case .friends: return "Friends"
            }
        }
        
        var buttonColor: Color {
            switch self {
            case .notFollowing: return .blue
            case .followBack: return .green
            case .following: return .gray
            case .friends: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .notFollowing: return "person.badge.plus"
            case .followBack: return "person.badge.plus"
            case .following: return "checkmark"
            case .friends: return "person.2.fill"
            }
        }
    }
    
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
            Color(.systemGray6)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header with back button
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                    
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                        
                        Text("Profile")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Placeholder for symmetry
                        Color.clear
                            .frame(width: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .frame(height: 60)
                
                if isLoadingProfile {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let profile = userProfile {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile header
                            VStack(spacing: 16) {
                                // Profile picture with level ring
                                ZStack {
                                    // Level ring
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: levelGradient(for: profile.level),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 4
                                        )
                                        .frame(width: 88, height: 88)
                                    
                                    // Profile picture
                                    if let profileImage = profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: levelGradient(for: profile.level),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 80, height: 80)
                                            .overlay {
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 36))
                                                    .foregroundStyle(.white)
                                            }
                                    }
                                }
                                
                                // Username and level
                                VStack(spacing: 4) {
                                    Text(profile.username)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text("Level \(profile.level)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                // Relationship Status Bar
                                Button(action: handleRelationshipAction) {
                                    HStack(spacing: 8) {
                                        Image(systemName: relationshipStatus.icon)
                                            .font(.subheadline)
                                        Text(relationshipStatus.buttonText)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(width: 180, height: 36)
                                    .background(relationshipStatus.buttonColor)
                                    .cornerRadius(18)
                                }
                                .padding(.top, 4)
                                
                                // Stats row - Friends/Following/Followers
                                HStack(spacing: 32) {
                                    StatButton(title: "Friends", count: followStats.friends)
                                    StatButton(title: "Following", count: followStats.following)
                                    StatButton(title: "Followers", count: followStats.followers)
                                }
                                .padding(.horizontal)
                                
                                // Additional stats
                                HStack(spacing: 24) {
                                    VStack(spacing: 4) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "car.fill")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                            Text("\(profile.totalCardsCollected)")
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                        }
                                        Text("Cards")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Divider()
                                        .frame(height: 30)
                                    
                                    VStack(spacing: 4) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "dollarsign.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.yellow)
                                            Text("\(profile.coins)")
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                        }
                                        Text("Coins")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            
                            // Divider
                            Divider()
                            
                            // Garage header with toggle
                            HStack {
                                Text("Garage (\(userCards.count))")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: {
                                    cardsPerRow = cardsPerRow == 1 ? 2 : 1
                                }) {
                                    Image(systemName: cardsPerRow == 1 ? "square.grid.2x2" : "rectangle")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Cards grid
                            if isLoadingCards {
                                ProgressView()
                                    .padding(.top, 40)
                            } else if userCards.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "car")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.gray)
                                    Text("No cards yet")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(height: 200)
                            } else {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: cardsPerRow), spacing: 15) {
                                    ForEach(userCards) { card in
                                        UserCardView(card: card, isLargeSize: cardsPerRow == 1)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                } else {
                    Spacer()
                    Text("Profile not found")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadProfile()
            await loadCards()
            await loadFollowStats()
            checkRelationshipStatus()
        }
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
        }
        .onDisappear {
            OrientationManager.unlockOrientation()
        }
    }
    
    // MARK: - Actions
    
    private func handleRelationshipAction() {
        Task {
            switch relationshipStatus {
            case .notFollowing, .followBack:
                // Follow the user
                do {
                    try await friendsService.followUser(userId: userId)
                    isFollowing = true
                    await loadFollowStats() // Refresh stats
                } catch {
                    print("❌ Follow failed: \(error)")
                }
                
            case .following, .friends:
                // Unfollow the user
                do {
                    try await friendsService.unfollowUser(userId: userId)
                    isFollowing = false
                    await loadFollowStats() // Refresh stats
                } catch {
                    print("❌ Unfollow failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadProfile() async {
        do {
            if let profile = try await UserService.shared.fetchProfile(uid: userId) {
                userProfile = profile
                
                // Load profile picture if available
                if let urlString = profile.profilePictureURL {
                    profileImage = try? await CardService.shared.loadImage(from: urlString)
                }
            }
            isLoadingProfile = false
        } catch {
            print("❌ Failed to load profile: \(error)")
            isLoadingProfile = false
        }
    }
    
    private func loadCards() async {
        do {
            userCards = try await CardService.shared.fetchUserCards(uid: userId)
            isLoadingCards = false
        } catch {
            print("❌ Failed to load cards: \(error)")
            isLoadingCards = false
        }
    }
    
    private func loadFollowStats() async {
        do {
            followStats = try await FriendsService.shared.getFollowStats(userId: userId)
        } catch {
            print("❌ Failed to load follow stats: \(error)")
        }
    }
    
    private func checkRelationshipStatus() {
        // Check if I'm following them
        isFollowing = friendsService.following.contains { $0.id == userId }
        
        // Check if they're following me
        followsMe = friendsService.followers.contains { $0.id == userId }
    }
}

// MARK: - Supporting Views

struct StatButton: View {
    let title: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct UserCardView: View {
    let card: CloudCard
    let isLargeSize: Bool
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = true
    
    private var cardHeight: CGFloat { isLargeSize ? 202.5 : 100 }
    private var cardWidth: CGFloat { cardHeight * (16/9) }
    
    var body: some View {
        ZStack {
            // Card background with gradient
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.85, blue: 0.88),
                            Color(red: 0.75, green: 0.75, blue: 0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Car image - full bleed
            Group {
                if isLoadingImage {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .tint(.gray)
                        )
                } else if let image = cardImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .overlay(
                            Image(systemName: "car.fill")
                                .font(.system(size: isLargeSize ? 30 : 20))
                                .foregroundStyle(.gray.opacity(0.4))
                        )
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            
            // Programmatic border overlay
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.black, lineWidth: 5)
                .allowsHitTesting(false)
            
            // Car name overlay - top left, horizontal
            VStack {
                HStack {
                    HStack(spacing: isLargeSize ? 6 : 3) {
                        Text(card.make.uppercased())
                            .font(.system(size: cardHeight * 0.08, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                        
                        Text(card.model)
                            .font(.system(size: cardHeight * 0.08, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                            .lineLimit(1)
                    }
                    .padding(.top, cardHeight * 0.08)
                    .padding(.leading, cardHeight * 0.08)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipped()
        .shadow(color: Color.black.opacity(0.3), radius: isLargeSize ? 6 : 4, x: 0, y: 3)
        .task {
            await loadCardImage()
        }
    }
    
    private func loadCardImage() async {
        do {
            cardImage = try await CardService.shared.loadImage(from: card.imageURL)
            isLoadingImage = false
        } catch {
            print("❌ Failed to load card image: \(error)")
            isLoadingImage = false
        }
    }
}

#Preview {
    UserProfileView(userId: "preview-id", username: "john_doe")
}
