//
//  UniversalCardView.swift
//  CarCardCollector
//
//  Universal card component that works with any card type
//  Displays card with PNG border overlay based on customFrame property
//

import SwiftUI

struct UniversalCardView: View {
    let cardData: CardDisplayData
    let height: CGFloat
    
    private var width: CGFloat { height * (16/9) }
    private var config: CardBorderConfig {
        CardBorderConfig.forFrame(cardData.customFrame)
    }
    
    var body: some View {
        ZStack {
            // Base card image
            cardImageView
                .frame(width: width, height: height)
                .clipped()
                .cornerRadius(8)
            
            // PNG Border overlay (if specified)
            if let borderImage = config.borderImageName {
                Image(borderImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .allowsHitTesting(false)
            }
            
            // Text overlay
            textOverlay
            
            // Heat indicator
            if let heat = cardData.heatCount, heat > 0 {
                heatOverlay(count: heat)
            }
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Image View
    
    @ViewBuilder
    private var cardImageView: some View {
        if let image = cardData.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
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
                .overlay(
                    Image(systemName: "car.fill")
                        .font(.system(size: height * 0.3))
                        .foregroundStyle(.white.opacity(0.3))
                )
        }
    }
    
    // MARK: - Text Overlay
    
    @ViewBuilder
    private var textOverlay: some View {
        VStack {
            if config.textPosition == .topLeft || config.textPosition == .topRight {
                textContent
                Spacer()
            } else {
                Spacer()
                textContent
            }
        }
    }
    
    @ViewBuilder
    private var textContent: some View {
        HStack {
            if config.textPosition == .topLeft || config.textPosition == .bottomLeft {
                carNameText
                Spacer()
            } else {
                Spacer()
                carNameText
            }
        }
        .padding(height * 0.08)
    }
    
    private var carNameText: some View {
        HStack(spacing: 6) {
            Text(cardData.make.uppercased())
                .font(.system(size: height * 0.08, weight: .semibold))
                .foregroundStyle(config.textColor)
                .shadow(
                    color: config.textShadow.color,
                    radius: config.textShadow.radius,
                    x: config.textShadow.x,
                    y: config.textShadow.y
                )
            
            Text(cardData.model)
                .font(.system(size: height * 0.08, weight: .bold))
                .foregroundStyle(config.textColor)
                .shadow(
                    color: config.textShadow.color,
                    radius: config.textShadow.radius,
                    x: config.textShadow.x,
                    y: config.textShadow.y
                )
                .lineLimit(1)
        }
    }
    
    // MARK: - Heat Overlay
    
    @ViewBuilder
    private func heatOverlay(count: Int) -> some View {
        if config.heatPosition != .hidden {
            VStack {
                if config.heatPosition == .bottomLeft || config.heatPosition == .bottomRight {
                    Spacer()
                }
                
                HStack {
                    if config.heatPosition == .topRight || config.heatPosition == .bottomRight {
                        Spacer()
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: height * 0.09))
                        Text("\(count)")
                            .font(.system(size: height * 0.09, weight: .bold))
                    }
                    .foregroundStyle(.orange)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    
                    if config.heatPosition == .topLeft || config.heatPosition == .bottomLeft {
                        Spacer()
                    }
                }
                
                if config.heatPosition == .topLeft || config.heatPosition == .topRight {
                    Spacer()
                }
            }
            .padding(height * 0.08)
        }
    }
}

// MARK: - Card Display Data

struct CardDisplayData {
    let make: String
    let model: String
    let image: UIImage?
    let customFrame: String?
    let heatCount: Int?
    
    // Convenience initializers for different card types
    init(savedCard: SavedCard) {
        self.make = savedCard.make
        self.model = savedCard.model
        self.image = savedCard.image
        self.customFrame = savedCard.customFrame
        self.heatCount = nil
    }
    
    init(friendActivity: FriendActivity) {
        self.make = friendActivity.cardMake
        self.model = friendActivity.cardModel
        self.image = nil // Will be loaded async
        self.customFrame = nil // FriendActivity doesn't have customFrame yet
        self.heatCount = friendActivity.heatCount
    }
    
    init(cloudCard: CloudCard) {
        self.make = cloudCard.make
        self.model = cloudCard.model
        self.image = nil // Will be loaded async
        self.customFrame = cloudCard.customFrame
        self.heatCount = nil
    }
    
    init(listing: CloudListing) {
        self.make = listing.make
        self.model = listing.model
        self.image = nil // Will be loaded async  
        self.customFrame = listing.customFrame
        self.heatCount = nil
    }
}
