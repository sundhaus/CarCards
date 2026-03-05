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
    var showRarityEffects: Bool = true  // Disable when parent adds full rarityEffects
    
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    @State private var usedFlatImage = false  // Track if we loaded the flat (baked) image
    @State private var showHeartAnimation = false
    @State private var hasLiked = false
    @State private var lastLoadedURL: String?  // Track which URL we loaded to detect changes
    
    private var cardWidth: CGFloat { height * (16/9) }
    
    private var currentUserId: String? {
        FirebaseManager.shared.currentUserId
    }
    
    /// Preferred display URL: flat image first (border+text baked in), raw image as fallback
    private var preferredImageURL: String {
        if let flat = card.flatImageURL, !flat.isEmpty { return flat }
        return card.imageURL
    }
    
    /// Whether this card has a flat image URL — used to suppress old border
    /// overlays while the flat image is still loading
    private var hasFlatURL: Bool {
        if let flat = card.flatImageURL, !flat.isEmpty { return true }
        return false
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
            
            // Only show border/text overlays if we loaded the raw image
            // (i.e. no flat image exists at all — NOT just "flat hasn't loaded yet")
            if !usedFlatImage && !hasFlatURL {
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
        // Static holo pattern + frozen prismatic rainbow (visible, zero CPU)
        .staticHoloThumbnail(holoEffect: card.holoEffect, cornerRadius: height * 0.09)
        // Rarity border effects (shimmer border for Epic, glow pulse for Legendary)
        .overlay {
            if showRarityEffects, let rarityStr = card.rarity, let rarity = CardRarity(rawValue: rarityStr), rarity >= .epic {
                ThumbnailRarityBorderOverlay(rarity: rarity, cornerRadius: height * 0.09)
            }
        }
        .thumbnailShimmer(for: card.rarity.flatMap { CardRarity(rawValue: $0) })
        // Rarity-colored glow shadow
        .shadow(
            color: showRarityEffects ? rarityGlowColor.opacity(0.5) : Color.black.opacity(0.3),
            radius: showRarityEffects && hasHighRarity ? 8 : 6,
            x: 0, y: 3
        )
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
        .onChange(of: card.flatImageURL) { _, newURL in
            // flatImageURL changed (migration updated Firestore) — reload
            let currentPreferred = newURL.flatMap { $0.isEmpty ? nil : $0 } ?? card.imageURL
            if currentPreferred != lastLoadedURL {
                // Clear immediately — no flash of stale card design
                cardImage = nil
                isLoadingImage = false
                lastLoadedURL = nil
                loadImage()
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
    
    // MARK: - Rarity Glow
    
    private var parsedRarity: CardRarity? {
        card.rarity.flatMap { CardRarity(rawValue: $0) }
    }
    
    private var hasHighRarity: Bool {
        guard let r = parsedRarity else { return false }
        return r >= .rare
    }
    
    private var rarityGlowColor: Color {
        guard let r = parsedRarity else { return Color.black.opacity(0.3) }
        switch r {
        case .common:    return Color.black.opacity(0.3)
        case .uncommon:  return Color.green.opacity(0.4)
        case .rare:      return Color.blue
        case .epic:      return Color.purple
        case .legendary: return Color.yellow
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
                    
                    // Track daily challenge progress for giving heats
                    DailyChallengeService.shared.onHeatGiven(uid: uid)
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
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .overlay(
                    ProgressView()
                        .tint(.gray)
                )
        } else {
            Rectangle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
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
        
        // Track which URL we're loading so onChange can detect updates
        lastLoadedURL = urlString
        
        guard let url = URL(string: urlString) else {
            // If flat URL failed, try raw URL as fallback
            if isFlatURL, let fallbackURL = URL(string: card.imageURL) {
                Task { await loadFromURL(fallbackURL, isFlat: false) }
            } else {
                isLoadingImage = false
            }
            return
        }
        
        Task { await loadFromURL(url, isFlat: isFlatURL) }
    }
    
    private func loadFromURL(_ url: URL, isFlat: Bool) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                cardImage = image
                usedFlatImage = isFlat
                isLoadingImage = false
                return
            }
        } catch {}
        
        // Flat image failed — try raw image as fallback
        if isFlat, let fallbackURL = URL(string: card.imageURL) {
            do {
                let (data2, _) = try await URLSession.shared.data(from: fallbackURL)
                if let image2 = UIImage(data: data2) {
                    cardImage = image2
                    usedFlatImage = false
                }
            } catch {}
        }
        isLoadingImage = false
    }
}
