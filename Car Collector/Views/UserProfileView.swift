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
    @State private var isCheckingRelationship = true
    @State private var crownCard: CloudCard?
    @State private var selectedCard: AnyCard?
    @State private var showCardDetail = false
    @State private var isLoadingCardImage = false
    
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
            case .notFollowing: return "FOLLOW"
            case .followBack: return "FOLLOW BACK"
            case .following: return "FOLLOWING"
            case .friends: return "FRIENDS"
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
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.pTitle3)
                            .foregroundStyle(.primary)
                    }
                    
                    Text("PROFILE")
                        .font(.pTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 18)
                .padding(.bottom, 10)
                .glassEffect(.regular, in: .rect)
                
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
                                                    .font(.poppins(36))
                                                    .foregroundStyle(.white)
                                            }
                                    }
                                }
                                
                                // Username and level
                                VStack(spacing: 4) {
                                    Text(profile.username)
                                        .font(.pTitle2)
                                        .fontWeight(.bold)
                                    
                                    Text("Level \(profile.level)")
                                        .font(.pSubheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                // Relationship Status Bar (hide on own profile)
                                if userId != UserService.shared.currentProfile?.id {
                                    if isCheckingRelationship {
                                        ProgressView()
                                            .frame(width: 180, height: 36)
                                            .padding(.top, 4)
                                    } else {
                                        Button(action: handleRelationshipAction) {
                                            HStack(spacing: 8) {
                                                Image(systemName: relationshipStatus.icon)
                                                    .font(.pSubheadline)
                                                Text(relationshipStatus.buttonText)
                                                    .font(.pSubheadline)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundStyle(.white)
                                            .frame(width: 180, height: 36)
                                            .background(relationshipStatus.buttonColor)
                                            .cornerRadius(18)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                
                                // Stats row - Friends/Following/Followers
                                HStack(spacing: 32) {
                                    StatButton(title: "FRIENDS", count: followStats.friends)
                                    StatButton(title: "FOLLOWING", count: followStats.following)
                                    StatButton(title: "FOLLOWERS", count: followStats.followers)
                                }
                                .padding(.horizontal)
                                
                                // Additional stats
                                HStack(spacing: 24) {
                                    VStack(spacing: 4) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "car.fill")
                                                .font(.pCaption)
                                                .foregroundStyle(.blue)
                                            Text("\(profile.totalCardsCollected)")
                                                .font(.pHeadline)
                                                .fontWeight(.semibold)
                                        }
                                        Text("CARDS")
                                            .font(.pCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Divider()
                                        .frame(height: 30)
                                    
                                    VStack(spacing: 4) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "dollarsign.circle.fill")
                                                .font(.pCaption)
                                                .foregroundStyle(.yellow)
                                            Text("\(profile.coins)")
                                                .font(.pHeadline)
                                                .fontWeight(.semibold)
                                        }
                                        Text("COINS")
                                            .font(.pCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            
                            // Divider
                            Divider()
                            
                            // Crown showcase card
                            if let crown = crownCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "star.fill")
                                            .font(.pCaption)
                                            .foregroundStyle(.yellow)
                                        Text("SHOWCASE")
                                            .font(.pCaption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal)
                                    
                                    ZStack(alignment: .topTrailing) {
                                        UserCardView(card: crown, isLargeSize: true)
                                            .onTapGesture {
                                                Task {
                                                    isLoadingCardImage = true
                                                    let image = (try? await CardService.shared.loadImage(from: crown.imageURL)) ?? UIImage()
                                                    selectedCard = Self.anyCardFrom(cloud: crown, image: image)
                                                    isLoadingCardImage = false
                                                    withAnimation { showCardDetail = true }
                                                }
                                            }
                                        
                                        // Crown badge overlay
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.yellow)
                                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                                            .padding(8)
                                    }
                                    .padding(.horizontal)
                                }
                                .padding(.bottom, 8)
                                
                                Divider()
                            }
                            
                            // Garage header with toggle
                            HStack {
                                let garageCards = userCards.filter { $0.id != crownCard?.id }
                                Text("GARAGE (\(garageCards.count))")
                                    .font(.pHeadline)
                                
                                Spacer()
                                
                                Button(action: {
                                    cardsPerRow = cardsPerRow == 1 ? 2 : 1
                                }) {
                                    Image(systemName: cardsPerRow == 2 ? "square.grid.2x2" : "rectangle.grid.1x2")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Cards grid
                            if isLoadingCards {
                                ProgressView()
                                    .padding(.top, 40)
                            } else if userCards.filter({ $0.id != crownCard?.id }).isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "car")
                                        .font(.poppins(50))
                                        .foregroundStyle(.gray)
                                    Text("No cards yet")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(height: 200)
                            } else {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: cardsPerRow), spacing: 15) {
                                    ForEach(userCards.filter { $0.id != crownCard?.id }) { card in
                                        UserCardView(card: card, isLargeSize: cardsPerRow == 1)
                                            .onTapGesture {
                                                Task {
                                                    isLoadingCardImage = true
                                                    let image = (try? await CardService.shared.loadImage(from: card.imageURL)) ?? UIImage()
                                                    selectedCard = Self.anyCardFrom(cloud: card, image: image)
                                                    isLoadingCardImage = false
                                                    withAnimation {
                                                        showCardDetail = true
                                                    }
                                                }
                                            }
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
            
            // Loading overlay for card image
            if isLoadingCardImage {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(2)
            }
            
            // Full screen card detail overlay (same as garage)
            if showCardDetail, let card = selectedCard {
                UnifiedCardDetailView(
                    card: card,
                    isShowing: $showCardDetail,
                    onCardUpdated: { _ in }
                )
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadProfile()
            await loadCards()
            await loadFollowStats()
            await checkRelationshipStatus()
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
    
    static func anyCardFrom(cloud: CloudCard, image: UIImage) -> AnyCard {
        switch cloud.cardType {
        case "driver":
            var dc = DriverCard(
                image: image,
                firstName: cloud.firstName ?? cloud.make,
                lastName: cloud.lastName ?? cloud.model,
                nickname: cloud.nickname ?? ""
            )
            dc.capturedBy = cloud.capturedBy
            dc.capturedLocation = cloud.capturedLocation
            dc.firebaseId = cloud.id
            return .driver(dc)
        case "location":
            var lc = LocationCard(
                image: image,
                locationName: cloud.locationName ?? cloud.make
            )
            lc.capturedBy = cloud.capturedBy
            lc.capturedLocation = cloud.capturedLocation
            lc.firebaseId = cloud.id
            return .location(lc)
        default:
            let sc = SavedCard(
                image: image,
                make: cloud.make,
                model: cloud.model,
                color: cloud.color,
                year: cloud.year,
                capturedBy: cloud.capturedBy,
                capturedLocation: cloud.capturedLocation,
                previousOwners: cloud.previousOwners,
                customFrame: cloud.customFrame,
                firebaseId: cloud.id
            )
            return .vehicle(sc)
        }
    }
    
    private func loadCards() async {
        do {
            userCards = try await CardService.shared.fetchUserCards(uid: userId)
            
            // Determine crown card ID — prefer local data for own profile
            let isOwnProfile = userId == UserService.shared.currentProfile?.id
            let crownId: String? = {
                if isOwnProfile {
                    return UserService.shared.crownCardId
                } else {
                    return userProfile?.crownCardId
                }
            }()
            
            print("⭐ Profile crown lookup: isOwn=\(isOwnProfile), crownId='\(crownId ?? "nil")', cards=\(userCards.count)")
            print("⭐ userId=\(userId), currentProfileId=\(UserService.shared.currentProfile?.id ?? "nil")")
            
            if let crownId = crownId, !crownId.isEmpty {
                print("⭐ Card IDs: \(userCards.map { $0.id })")
                
                // Direct match
                if let match = userCards.first(where: { $0.id == crownId }) {
                    crownCard = match
                    print("⭐ Direct match found: \(match.make) \(match.model)")
                }
                
                // Case-insensitive fallback
                if crownCard == nil, let match = userCards.first(where: { $0.id.lowercased() == crownId.lowercased() }) {
                    crownCard = match
                    print("⭐ Case-insensitive match found: \(match.make) \(match.model)")
                }
                
                // Fallback: crownId might be a local UUID — resolve via local storage
                if crownCard == nil {
                    let localCards = CardStorage.loadCards()
                    if let localCard = localCards.first(where: { $0.id.uuidString == crownId }),
                       let fbId = localCard.firebaseId,
                       let match = userCards.first(where: { $0.id == fbId }) {
                        crownCard = match
                        print("⭐ Resolved local UUID → firebaseId: \(fbId), auto-fixing")
                        UserService.shared.setCrownCard(fbId)
                    }
                }
                
                print("⭐ Crown card result: \(crownCard != nil ? "\(crownCard!.make) \(crownCard!.model)" : "NOT FOUND")")
            } else {
                print("⭐ No crownCardId set for user")
                crownCard = nil
            }
            
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
    
    private func checkRelationshipStatus() async {
        // Direct Firestore queries instead of checking cached arrays
        do {
            isFollowing = try await friendsService.checkIfFollowing(userId: userId)
            followsMe = try await friendsService.checkIfFollowsMe(userId: userId)
            isCheckingRelationship = false
            print("👥 Relationship: isFollowing=\(isFollowing), followsMe=\(followsMe)")
        } catch {
            // Fallback to cached data
            isFollowing = friendsService.following.contains { $0.id == userId }
            followsMe = friendsService.followers.contains { $0.id == userId }
            isCheckingRelationship = false
            print("⚠️ Relationship check fell back to cache: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct StatButton: View {
    let title: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.pHeadline)
                .fontWeight(.bold)
            Text(title)
                .font(.pCaption)
                .foregroundStyle(.secondary)
        }
    }
}

struct UserCardView: View {
    let card: CloudCard
    let isLargeSize: Bool
    var isCrowned: Bool = false
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = true
    
    private var cardHeight: CGFloat { isLargeSize ? 202.5 : 100 }
    private var cardWidth: CGFloat { cardHeight * (16/9) }
    
    var body: some View {
        ZStack {
            // Card background with gradient
            RoundedRectangle(cornerRadius: cardHeight * 0.09)
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
                            Image(systemName: card.cardType == "driver" ? "person.fill" : card.cardType == "location" ? "mappin.circle.fill" : "car.fill")
                                .font(.system(size: isLargeSize ? 30 : 20))
                                .foregroundStyle(.gray.opacity(0.4))
                        )
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            
            // PNG border overlay based on customFrame
            if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .allowsHitTesting(false)
            }
            
            // Car name overlay
            if card.cardType == "driver" {
                // Driver: top-left in landscape, name stacked
                let config = CardBorderConfig.forFrame(card.customFrame)
                VStack(alignment: .leading, spacing: 1) {
                    Text((card.firstName ?? card.make).uppercased())
                        .font(.custom("Futura-Light", size: cardHeight * 0.08))
                    Text((card.lastName ?? card.model).uppercased())
                        .font(.custom("Futura-Bold", size: cardHeight * 0.08))
                }
                .foregroundStyle(config.textColor)
                .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                .padding(.top, cardHeight * 0.08)
                .padding(.leading, cardHeight * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if card.cardType == "location" {
                let config = CardBorderConfig.forFrame(card.customFrame)
                Text((card.locationName ?? card.make).uppercased())
                    .font(.custom("Futura-Bold", size: cardHeight * 0.08))
                    .foregroundStyle(config.textColor)
                    .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                    .padding(.top, cardHeight * 0.08)
                    .padding(.leading, cardHeight * 0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                // Vehicle: make + model horizontal
                VStack {
                    HStack {
                        HStack(spacing: isLargeSize ? 6 : 3) {
                            let config = CardBorderConfig.forFrame(card.customFrame)
                            Text(card.make.uppercased())
                                .font(.custom("Futura-Light", size: cardHeight * 0.08))
                                .foregroundStyle(config.textColor)
                                .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                            
                            Text(card.model.uppercased())
                                .font(.custom("Futura-Bold", size: cardHeight * 0.08))
                                .foregroundStyle(config.textColor)
                                .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                                .lineLimit(1)
                        }
                        .padding(.top, cardHeight * 0.08)
                        .padding(.leading, cardHeight * 0.08)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
        .overlay(alignment: .topTrailing) {
            if isCrowned {
                Image(systemName: "star.fill")
                    .font(.system(size: isLargeSize ? 14 : 10, weight: .bold))
                    .foregroundStyle(.yellow)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    .padding(isLargeSize ? 8 : 5)
            }
        }
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
