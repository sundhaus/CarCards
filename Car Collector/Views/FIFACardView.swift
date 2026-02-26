//
//  FIFACardView.swift
//  CarCardCollector
//
//  Reusable card component for displaying FriendActivity cards
//

import SwiftUI

struct FIFACardView: View {
    let card: FriendActivity
    let height: CGFloat
    var onSingleTap: (() -> Void)? = nil
    
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    @State private var usedFlatImage = false  // Track if we loaded the flat (baked) image
    @State private var showHeartAnimation = false
    @State private var hasLiked = false
    
    private var cardWidth: CGFloat { height * (16/9) }
    
    private var currentUserId: String? {
        FirebaseManager.shared.currentUserId
    }
    
    /// Preferred display URL: flat image first (border+text baked in), raw image as fallback
    private var preferredImageURL: String {
        if let flat = card.flatImageURL, !flat.isEmpty { return flat }
        return card.imageURL
    }
    
    var body: some View {
        ZStack {
            // Card background gradient (visible while loading / as fallback)
            RoundedRectangle(cornerRadius: height * 0.09)
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
            
            // Card image
            cardImageView
                .frame(width: cardWidth, height: height)
                .clipped()
            
            // Only show overlays if we're using the raw image (no flat image available)
            if !usedFlatImage {
                // Border PNG overlay based on customFrame
                if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                    Image(borderImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: height)
                        .allowsHitTesting(false)
                }
                
                // Card name overlay — adapts to card type
                cardNameOverlay
            }
            
            // Heat indicator — always shown (not part of flat image)
            if displayHeatCount > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: height * 0.09))
                            Text("\(displayHeatCount)")
                                .font(.system(size: height * 0.09, weight: .bold))
                        }
                        .foregroundColor(.orange)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .padding(.bottom, height * 0.08)
                        .padding(.trailing, height * 0.08)
                    }
                }
            }
            
            // Heat animation overlay
            if showHeartAnimation {
                Image(systemName: "flame.fill")
                    .font(.system(size: height * 0.4))
                    .foregroundColor(.orange)
                    .shadow(color: .black.opacity(0.5), radius: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: cardWidth, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.09))
        .liquidGlassShimmer(
            rarity: CardRarity.fromBorderName(card.customFrame),
            cornerRadius: height * 0.09,
            borderWidth: max(3.0, height * 0.018)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            toggleHeat()
        }
        .onTapGesture(count: 1) {
            onSingleTap?()
        }
        .onAppear {
            loadImage()
            if let uid = currentUserId {
                hasLiked = card.heatedBy.contains(uid)
            }
        }
    }
    
    // MARK: - Card Name Overlay (only used when no flat image)
    
    @ViewBuilder
    private var cardNameOverlay: some View {
        let config = CardBorderConfig.forFrame(card.customFrame)
        if card.cardType == "driver" {
            let inset = height * 0.08
            VStack(alignment: .leading, spacing: 1) {
                Text(card.cardMake.uppercased())
                    .font(.custom("Futura-Bold", fixedSize: height * 0.09))
                
                if !card.cardYear.isEmpty {
                    Text("\"\(card.cardYear.uppercased())\"")
                        .font(.custom("Futura-Light", fixedSize: height * 0.06))
                }
                
                Text(card.cardModel.uppercased())
                    .font(.custom("Futura-Bold", fixedSize: height * 0.09))
            }
            .foregroundStyle(config.textColor)
            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
            .padding(.top, inset)
            .padding(.leading, inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if card.cardType == "location" {
            VStack {
                HStack {
                    Text(card.cardMake.uppercased())
                        .font(.custom("Futura-Bold", fixedSize: height * 0.08))
                        .foregroundStyle(config.textColor)
                        .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        .padding(.top, height * 0.08)
                        .padding(.leading, height * 0.08)
                    Spacer()
                }
                Spacer()
            }
        } else {
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Text(card.cardMake.uppercased())
                            .font(.custom("Futura-Light", fixedSize: height * 0.08))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        
                        Text(card.cardModel.uppercased())
                            .font(.custom("Futura-Bold", fixedSize: height * 0.08))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                            .lineLimit(1)
                    }
                    .padding(.top, height * 0.08)
                    .padding(.leading, height * 0.08)
                    Spacer()
                }
                Spacer()
            }
        }
    }
    
    private var heatDelta: Int {
        let alreadyInServer = card.heatedBy.contains(currentUserId ?? "")
        if hasLiked && !alreadyInServer { return 1 }
        if !hasLiked && alreadyInServer { return -1 }
        return 0
    }
    
    private var displayHeatCount: Int {
        card.heatCount + heatDelta
    }
    
    private func toggleHeat() {
        guard let uid = currentUserId else { return }
        // Don't heat your own cards
        guard card.userId != uid else { return }
        
        if hasLiked {
            // Unlike
            hasLiked = false
            Task {
                do {
                    try await FriendsService.shared.removeHeat(activityId: card.id, userId: uid)
                    print("🔥 Removed heat from \(card.cardMake) \(card.cardModel)")
                } catch {
                    print("❌ Failed to remove heat: \(error)")
                    await MainActor.run { hasLiked = true }
                }
            }
        } else {
            // Like
            hasLiked = true
            triggerHeartAnimation()
            Task {
                do {
                    try await FriendsService.shared.addHeat(activityId: card.id, userId: uid)
                    print("🔥 Added heat to \(card.cardMake) \(card.cardModel)")
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
    
    @ViewBuilder
    private var cardImageView: some View {
        if let image = cardImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if isLoadingImage {
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .overlay(
                    ProgressView()
                        .tint(.gray)
                )
        } else {
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .overlay(
                    Image(systemName: card.cardType == "driver" ? "person.fill" : card.cardType == "location" ? "mappin.circle.fill" : "car.fill")
                        .font(.system(size: height * 0.3))
                        .foregroundStyle(.gray.opacity(0.4))
                )
        }
    }
    
    private func loadImage() {
        guard !isLoadingImage, cardImage == nil else { return }
        
        isLoadingImage = true
        
        // Prefer flat image (border + text baked in) over raw image
        let flatURL = card.flatImageURL.flatMap { $0.isEmpty ? nil : $0 }
        let urlString = flatURL ?? card.imageURL
        let isFlatURL = flatURL != nil
        
        guard let url = URL(string: urlString) else {
            // If flat URL failed, try raw URL as fallback
            if isFlatURL, let fallbackURL = URL(string: card.imageURL) {
                loadFromURL(fallbackURL, isFlat: false)
            } else {
                isLoadingImage = false
            }
            return
        }
        
        loadFromURL(url, isFlat: isFlatURL)
    }
    
    private func loadFromURL(_ url: URL, isFlat: Bool) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    cardImage = image
                    usedFlatImage = isFlat
                    isLoadingImage = false
                }
            } else if isFlat, let fallbackURL = URL(string: card.imageURL) {
                // Flat image failed to load — try raw image as fallback
                URLSession.shared.dataTask(with: fallbackURL) { data2, _, _ in
                    DispatchQueue.main.async {
                        if let data2 = data2, let image2 = UIImage(data: data2) {
                            cardImage = image2
                            usedFlatImage = false
                        }
                        isLoadingImage = false
                    }
                }.resume()
            } else {
                DispatchQueue.main.async {
                    isLoadingImage = false
                }
            }
        }.resume()
    }
}
