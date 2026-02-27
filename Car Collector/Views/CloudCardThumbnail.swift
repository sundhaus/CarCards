//
//  CloudCardThumbnail.swift
//  Car Collector
//
//  Reusable thumbnail for displaying cloud-sourced cards (Firestore) with
//  proper flat image loading and live rarity effects.
//
//  Architecture:
//  - FLAT IMAGE (static, baked): photo + border + text → loaded from flatImageURL
//  - LIVE OVERLAYS (dynamic, never baked): shimmer border, glow, particles,
//    holographic patterns → applied as SwiftUI overlays at display time
//
//  Use this instead of manually loading imageURL + PNG borders + text overlays.
//  Works with CloudCard, CloudListing, or raw URL strings.
//

import SwiftUI

// MARK: - Cloud Card Thumbnail

/// Displays a cloud-sourced card with flat image + live rarity effects.
/// Prefers flatImageURL (border+text baked in), falls back to raw imageURL
/// with manual overlays only when no flat image exists.
struct CloudCardThumbnail: View {
    let flatImageURL: String?
    let rawImageURL: String
    let rarity: CardRarity?
    let holoEffect: String?
    let customFrame: String?
    let cardType: String
    let make: String
    let model: String
    let firstName: String?
    let lastName: String?
    let locationName: String?
    let height: CGFloat
    let capturedByLevel: Int?
    
    @State private var cardImage: UIImage?
    @State private var isLoading = true
    @State private var usedFlatImage = false
    
    private var width: CGFloat { height * (16.0 / 9.0) }
    private var cornerRadius: CGFloat { height * 0.09 }
    
    // MARK: - Convenience Initializers
    
    /// Initialize from a CloudCard
    init(card: CloudCard, height: CGFloat) {
        self.flatImageURL = card.flatImageURL
        self.rawImageURL = card.imageURL
        self.rarity = card.rarity.flatMap { CardRarity(rawValue: $0) }
        self.holoEffect = card.holoEffect  // Now available on CloudCard
        self.customFrame = card.customFrame
        self.cardType = card.cardType
        self.make = card.make
        self.model = card.model
        self.firstName = card.firstName
        self.lastName = card.lastName
        self.locationName = card.locationName
        self.height = height
        self.capturedByLevel = card.capturedByLevel
    }
    
    /// Initialize from a CloudListing
    init(listing: CloudListing, height: CGFloat) {
        self.flatImageURL = listing.flatImageURL
        self.rawImageURL = listing.imageURL
        self.rarity = listing.rarity.flatMap { CardRarity(rawValue: $0) }
        self.holoEffect = listing.holoEffect
        self.customFrame = listing.customFrame
        self.cardType = "vehicle"
        self.make = listing.make
        self.model = listing.model
        self.firstName = nil
        self.lastName = nil
        self.locationName = nil
        self.height = height
        self.capturedByLevel = nil
    }
    
    /// Initialize from a FriendActivity (for contexts not using FIFACardView)
    init(activity: FriendActivity, height: CGFloat) {
        self.flatImageURL = activity.flatImageURL
        self.rawImageURL = activity.imageURL
        self.rarity = activity.rarity.flatMap { CardRarity(rawValue: $0) }
        self.holoEffect = activity.holoEffect
        self.customFrame = activity.customFrame
        self.cardType = activity.cardType
        self.make = activity.cardMake
        self.model = activity.cardModel
        self.firstName = nil
        self.lastName = nil
        self.locationName = nil
        self.height = height
        self.capturedByLevel = nil
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient (visible while loading)
            RoundedRectangle(cornerRadius: cornerRadius)
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
            if let image = cardImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .tint(.gray)
            } else {
                Image(systemName: cardTypeIcon)
                    .font(.system(size: height * 0.3))
                    .foregroundStyle(.gray.opacity(0.4))
            }
            
            // Fallback border + text overlays (only when no flat image)
            if !usedFlatImage && !hasFlatURL {
                fallbackBorderOverlay
                fallbackTextOverlay
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        // Live holographic pattern effect (auto-animated for thumbnails)
        .holoEffectThumbnail(holoEffect, cornerRadius: cornerRadius)
        // Live rarity border effects (shimmer for Epic, glow for Legendary)
        .overlay {
            if let rarity = rarity, rarity >= .epic {
                ThumbnailRarityBorderOverlay(rarity: rarity, cornerRadius: cornerRadius)
            }
        }
        // One-shot shimmer sweep
        .thumbnailShimmer(for: rarity)
        // Prestige level badge (Level 25+ creators)
        .overlay(alignment: .bottomLeading) {
            if let level = capturedByLevel {
                LevelBadgeOverlay(level: level)
                    .padding(6)
            }
        }
        // Rarity-colored glow shadow
        .shadow(
            color: rarityGlowColor.opacity(0.5),
            radius: hasHighRarity ? 8 : 6,
            x: 0, y: 3
        )
        .task {
            await loadImage()
        }
    }
    
    // MARK: - Flat URL Check
    
    private var hasFlatURL: Bool {
        if let flat = flatImageURL, !flat.isEmpty { return true }
        return false
    }
    
    // MARK: - Image Loading
    
    private func loadImage() async {
        // Prefer flat image (border + text baked in)
        let flatURL = flatImageURL.flatMap { $0.isEmpty ? nil : $0 }
        let urlString = flatURL ?? rawImageURL
        let isFlatURL = flatURL != nil
        
        guard let url = URL(string: urlString) else {
            // If flat URL was bad, try raw URL
            if isFlatURL {
                await loadFromURL(rawImageURL, isFlat: false)
            } else {
                isLoading = false
            }
            return
        }
        
        await loadFromURL(urlString, isFlat: isFlatURL)
    }
    
    private func loadFromURL(_ urlString: String, isFlat: Bool) async {
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    cardImage = image
                    usedFlatImage = isFlat
                    isLoading = false
                }
            } else if isFlat {
                // Flat image decode failed — try raw
                await loadFromURL(rawImageURL, isFlat: false)
            } else {
                await MainActor.run { isLoading = false }
            }
        } catch {
            if isFlat {
                await loadFromURL(rawImageURL, isFlat: false)
            } else {
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    // MARK: - Fallback Overlays (only when no flat image exists)
    
    @ViewBuilder
    private var fallbackBorderOverlay: some View {
        let config = CardBorderConfig.forFrame(customFrame, rarity: rarity)
        if let borderName = config.borderImageName {
            Image(borderName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .allowsHitTesting(false)
        }
    }
    
    @ViewBuilder
    private var fallbackTextOverlay: some View {
        let config = CardBorderConfig.forFrame(customFrame, rarity: rarity)
        let textPadding = height * 0.08
        let fontSize = height * 0.08
        
        VStack {
            HStack {
                if cardType == "driver" {
                    VStack(alignment: .leading, spacing: 1) {
                        Text((firstName ?? make).uppercased())
                            .font(.custom("Futura-Light", fixedSize: fontSize))
                        Text((lastName ?? model).uppercased())
                            .font(.custom("Futura-Bold", fixedSize: fontSize))
                    }
                    .foregroundStyle(config.textColor)
                    .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                } else if cardType == "location" {
                    Text((locationName ?? make).uppercased())
                        .font(.custom("Futura-Bold", fixedSize: fontSize))
                        .foregroundStyle(config.textColor)
                        .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                } else {
                    HStack(spacing: height > 120 ? 6 : 3) {
                        Text(make.uppercased())
                            .font(.custom("Futura-Light", fixedSize: fontSize))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        Text(model.uppercased())
                            .font(.custom("Futura-Bold", fixedSize: fontSize))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.top, textPadding)
            .padding(.leading, textPadding)
            Spacer()
        }
    }
    
    // MARK: - Helpers
    
    private var cardTypeIcon: String {
        switch cardType {
        case "driver": return "person.fill"
        case "location": return "mappin.circle.fill"
        default: return "car.fill"
        }
    }
    
    private var hasHighRarity: Bool {
        guard let r = rarity else { return false }
        return r >= .rare
    }
    
    private var rarityGlowColor: Color {
        guard let r = rarity else { return Color.black.opacity(0.3) }
        switch r {
        case .common:    return Color.black.opacity(0.3)
        case .uncommon:  return Color.green.opacity(0.4)
        case .rare:      return Color.blue
        case .epic:      return Color.purple
        case .legendary: return Color.yellow
        }
    }
}
