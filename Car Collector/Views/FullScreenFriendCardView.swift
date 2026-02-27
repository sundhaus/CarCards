//
//  FullScreenFriendCardView.swift
//  CarCardCollector
//
//  Standalone fullscreen card overlay for FriendActivity cards.
//  Shows FIFA-style card large with flip-to-specs support.
//

import SwiftUI

struct FullScreenFriendCardView: View {
    let activity: FriendActivity
    @Binding var isShowing: Bool
    
    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0
    @State private var isFetchingSpecs = false
    @State private var fetchedSpecs: VehicleSpecs?
    @State private var profileImage: UIImage?
    @State private var showHeartAnimation = false
    @State private var hasLiked = false
    
    private var currentUserId: String? {
        FirebaseManager.shared.currentUserId
    }
    
    private var displayRarity: CardRarity? {
        fetchedSpecs?.rarity ?? activity.rarity.flatMap { CardRarity(rawValue: $0) }
    }
    
    private func rarityGlowColor(for rarity: CardRarity?) -> Color {
        guard let r = rarity else { return .clear }
        switch r {
        case .common:    return .clear
        case .uncommon:  return Color.green.opacity(0.4)
        case .rare:      return Color.blue
        case .epic:      return Color.purple
        case .legendary: return Color.yellow
        }
    }
    
    private func specsAreComplete(_ specs: VehicleSpecs?) -> Bool {
        guard let specs = specs else { return false }
        return specs.horsepower != "N/A" && specs.torque != "N/A"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background — tap to dismiss
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.25)) {
                            isShowing = false
                        }
                    }
                
                // Card container — rotated landscape in portrait mode
                VStack {
                    Spacer()
                    ZStack {
                        cardContent(screenSize: geometry.size)
                            .rotationEffect(.degrees(90))
                    }
                    .shadow(color: rarityGlowColor(for: displayRarity).opacity(0.6), radius: 20)
                    .cardTilt(for: displayRarity)
                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // X button — top left, User info — top right
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.pTitle2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(20)
                        
                        Spacer()
                        
                        // User profile chip — always visible, pfp first
                        NavigationLink {
                            UserProfileView(userId: activity.userId, username: activity.username)
                        } label: {
                            HStack(spacing: 8) {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 30, height: 30)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(.white.opacity(0.3))
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            Text(String(activity.username.prefix(1)).uppercased())
                                                .font(.poppins(13))
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.white)
                                        }
                                }
                                
                                Text(activity.username)
                                    .font(.pCaption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.6))
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                
                // Loading spinner
                if isFetchingSpecs {
                    ProgressView()
                        .scaleEffect(2.0)
                        .tint(.white)
                }
            }
        }
        .transition(.opacity)
        .task {
            await loadProfilePicture()
            if let uid = currentUserId {
                hasLiked = activity.heatedBy.contains(uid)
            }
        }
    }
    
    // MARK: - Card Content
    
    private func cardContent(screenSize: CGSize) -> some View {
        let cardWidth: CGFloat = screenSize.height * 0.8
        let cardHeight: CGFloat = cardWidth / 16 * 9
        let displayRarity: CardRarity? = fetchedSpecs?.rarity ?? activity.rarity.flatMap { CardRarity(rawValue: $0) }
        
        return ZStack {
            // Front
            if !isFlipped {
                FIFACardView(card: activity, height: cardHeight, showRarityEffects: false)
                    .frame(width: cardWidth, height: cardHeight)
                    .unifiedCardEffects(rarity: displayRarity, holoEffect: activity.holoEffect)
                    .allowsHitTesting(false)
                    .rotation3DEffect(
                        .degrees(flipDegrees),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            
            // Back — specs
            if isFlipped {
                if let specs = fetchedSpecs {
                    RarityCardBackView(
                        make: activity.cardMake,
                        model: activity.cardModel,
                        year: activity.cardYear,
                        specs: specs,
                        rarity: specs.rarity ?? .common,
                        customFrame: activity.customFrame,
                        cardHeight: cardHeight
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .rotation3DEffect(
                        .degrees(flipDegrees),
                        axis: (x: 0, y: 1, z: 0)
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            toggleHeat()
        }
        .onTapGesture(count: 1) {
            guard !isFetchingSpecs else { return }
            if specsAreComplete(fetchedSpecs) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    flipDegrees += 180
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isFlipped.toggle()
                    }
                }
            } else {
                Task {
                    await fetchSpecs()
                }
            }
        }
        .overlay {
            if showHeartAnimation {
                Image(systemName: "flame.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)
                    .shadow(color: .black.opacity(0.5), radius: 10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Fetch Specs
    
    private func fetchSpecs() async {
        guard fetchedSpecs == nil else { return }
        
        await MainActor.run { isFetchingSpecs = true }
        
        do {
            let vehicleService = VehicleIdentificationService()
            let specs = try await vehicleService.fetchSpecs(
                make: activity.cardMake,
                model: activity.cardModel,
                year: activity.cardYear
            )
            
            await MainActor.run {
                fetchedSpecs = specs
                isFetchingSpecs = false
                
                // Auto-flip to show specs
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    flipDegrees += 180
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isFlipped.toggle()
                    }
                }
            }
        } catch {
            print("❌ Failed to fetch specs: \(error)")
            await MainActor.run { isFetchingSpecs = false }
        }
    }
    
    // MARK: - Heat Toggle
    
    private func toggleHeat() {
        guard let uid = currentUserId else { return }
        guard activity.userId != uid else { return }
        
        if hasLiked {
            hasLiked = false
            Task {
                do {
                    try await FriendsService.shared.removeHeat(activityId: activity.id, userId: uid)
                    print("🔥 Removed heat from \(activity.cardMake) \(activity.cardModel)")
                } catch {
                    print("❌ Failed to remove heat: \(error)")
                    await MainActor.run { hasLiked = true }
                }
            }
        } else {
            hasLiked = true
            triggerHeartAnimation()
            Task {
                do {
                    try await FriendsService.shared.addHeat(activityId: activity.id, userId: uid)
                    print("🔥 Added heat to \(activity.cardMake) \(activity.cardModel)")
                } catch {
                    print("❌ Failed to add heat: \(error)")
                    await MainActor.run { hasLiked = false }
                }
            }
        }
    }
    
    private func triggerHeartAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            showHeartAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showHeartAnimation = false
            }
        }
    }
    
    // MARK: - Load Profile Picture
    
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
