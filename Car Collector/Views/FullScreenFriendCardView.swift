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
    var showUserInfo: Bool = false
    
    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0
    @State private var isFetchingSpecs = false
    @State private var fetchedSpecs: VehicleSpecs?
    @State private var profileImage: UIImage?
    
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
                    cardContent(screenSize: geometry.size)
                        .rotationEffect(.degrees(90))
                        .cardTilt()
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
                        
                        if showUserInfo {
                            // User profile chip — tappable
                            NavigationLink {
                                UserProfileView(userId: activity.userId, username: activity.username)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(activity.username)
                                        .font(.pCaption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    
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
                                }
                                .padding(.leading, 12)
                                .padding(.trailing, 6)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.6))
                                .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 20)
                        } else if !isFetchingSpecs {
                            // Flip hint (when no user info shown)
                            Text(specsAreComplete(fetchedSpecs) ? "Tap card to flip" : "Tap to load stats")
                                .font(.pCaption)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.6))
                                .cornerRadius(20)
                                .padding(.trailing, 20)
                        }
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
            if showUserInfo {
                await loadProfilePicture()
            }
        }
    }
    
    // MARK: - Card Content
    
    private func cardContent(screenSize: CGSize) -> some View {
        let cardWidth: CGFloat = screenSize.height * 0.8
        let cardHeight: CGFloat = cardWidth / 16 * 9
        
        return ZStack {
            // Front
            if !isFlipped {
                FIFACardView(card: activity, height: cardHeight)
                    .frame(width: cardWidth, height: cardHeight)
                    .rotation3DEffect(
                        .degrees(flipDegrees),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            
            // Back — specs
            if isFlipped {
                if let specs = fetchedSpecs {
                    CardBackView(
                        make: activity.cardMake,
                        model: activity.cardModel,
                        year: activity.cardYear,
                        specs: specs,
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
        .onTapGesture {
            guard !isFetchingSpecs else { return }
            
            if specsAreComplete(fetchedSpecs) {
                // Flip
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    flipDegrees += 180
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isFlipped.toggle()
                    }
                }
            } else {
                // Fetch specs, then auto-flip
                Task {
                    await fetchSpecs()
                }
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
