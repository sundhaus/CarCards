//
//  HotCardsCarousel.swift
//  CarCardCollector
//
//  3D infinite swipe stack carousel showing cards with most heat globally
//

import SwiftUI

struct HotCardsCarousel: View {
    @StateObject private var hotCardsService = HotCardsService()
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Featured Collections")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            if hotCardsService.isLoading {
                loadingView
            } else if hotCardsService.hotCards.isEmpty {
                emptyView
            } else {
                cardStackView
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.25, blue: 0.35), Color(red: 0.15, green: 0.2, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .onAppear {
            hotCardsService.fetchHotCards(limit: 20)
        }
    }
    
    // MARK: - Carousel Wheel View (3D Rotating Carousel)
    
    private var cardStackView: some View {
        GeometryReader { geometry in
            ZStack {
                // Show 5 positions for smooth transitions: -2, -1, 0, 1, 2
                // But only -1, 0, 1 are visible (others are off-screen staging)
                ForEach(-2...2, id: \.self) { offset in
                    let cardIndex = getCardIndex(for: offset)
                    
                    if cardIndex >= 0 && cardIndex < hotCardsService.hotCards.count {
                        let card = hotCardsService.hotCards[cardIndex]
                        
                        HotCardItem(card: card, position: offset == 0 ? 0 : 1)
                            .frame(width: min(geometry.size.width - 100, 320))
                            .offset(x: getCarouselOffsetX(for: offset), y: 0)
                            .scaleEffect(getCarouselScale(for: offset))
                            .rotation3DEffect(
                                getCarousel3DRotation(for: offset),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.3
                            )
                            .opacity(getCarouselOpacity(for: offset))
                            .zIndex(offset == 0 ? 10 : Double(5 - abs(offset)))
                    }
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: currentIndex)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
            .frame(width: geometry.size.width, height: 300)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        handleCarouselSwipe(translation: value.translation.width)
                    }
            )
        }
        .frame(height: 300)
        .padding(.bottom, 12)
    }
    
    
    // MARK: - Carousel Position Calculations
    
    private func getCardIndex(for offset: Int) -> Int {
        // Offset: -2, -1 (left cards), 0 (center card), 1, 2 (right cards)
        let index = currentIndex + offset
        let totalCards = hotCardsService.hotCards.count
        
        if index < 0 {
            return index + totalCards
        } else if index >= totalCards {
            return index - totalCards
        }
        return index
    }
    
    private func getCarouselOffsetX(for offset: Int) -> CGFloat {
        // Base position for each card
        let baseOffset: CGFloat
        
        switch offset {
        case -2: // Far left (off-screen staging)
            baseOffset = -500
        case -1: // Left card
            baseOffset = -220
        case 0: // Center card
            baseOffset = 0
        case 1: // Right card
            baseOffset = 220
        case 2: // Far right (off-screen staging)
            baseOffset = 500
        default:
            baseOffset = 0
        }
        
        // Add drag influence - center card follows drag, side cards move opposite
        if offset == 0 {
            return baseOffset + (dragOffset * 0.8)
        } else if abs(offset) == 1 {
            // Visible side cards - parallax effect
            return baseOffset - (dragOffset * 0.15)
        } else {
            // Staging cards - minimal movement
            return baseOffset - (dragOffset * 0.05)
        }
    }
    
    private func getCarouselScale(for offset: Int) -> CGFloat {
        if offset == 0 {
            // Center card is full size
            let dragScale = 1.0 - (abs(dragOffset) / 2000.0)
            return max(0.9, dragScale)
        } else if abs(offset) == 1 {
            // Visible side cards are 75% size
            return 0.75
        } else {
            // Staging cards are small
            return 0.5
        }
    }
    
    private func getCarousel3DRotation(for offset: Int) -> Angle {
        let dragInfluence = Double(dragOffset) / 10.0
        
        switch offset {
        case -2: // Far left staging - rotated away more
            return Angle(degrees: -75.0)
        case -1: // Left card - rotate LEFT (away from center)
            return Angle(degrees: -55.0 + dragInfluence)
        case 0: // Center card - slight rotation based on drag
            return Angle(degrees: Double(dragOffset) / 20.0)
        case 1: // Right card - rotate RIGHT (away from center)
            return Angle(degrees: 55.0 + dragInfluence)
        case 2: // Far right staging - rotated away more
            return Angle(degrees: 75.0)
        default:
            return Angle(degrees: 0)
        }
    }
    
    private func getCarouselOpacity(for offset: Int) -> Double {
        if offset == 0 {
            // Center card always visible
            return 1.0
        } else if abs(offset) == 1 {
            // Visible side cards slightly faded
            return 0.6
        } else {
            // Staging cards invisible (off-screen)
            return 0
        }
    }
    
    // MARK: - Swipe Handling
    
    private func handleCarouselSwipe(translation: CGFloat) {
        let threshold: CGFloat = 80
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            if translation > threshold {
                // Swiped right - go to previous card (infinite loop)
                currentIndex = (currentIndex - 1 + hotCardsService.hotCards.count) % hotCardsService.hotCards.count
            } else if translation < -threshold {
                // Swiped left - go to next card (infinite loop)
                currentIndex = (currentIndex + 1) % hotCardsService.hotCards.count
            }
            
            // Reset drag offset
            dragOffset = 0
        }
    }
    
    // MARK: - Loading & Empty States
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .tint(.white)
            Text("Loading hot cards...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange.opacity(0.7))
            
            Text("No hot cards yet")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            Text("Be the first to get some heat!")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
    }
}

// MARK: - Hot Card Item

struct HotCardItem: View {
    let card: FriendActivity
    let position: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // Card image with 3D shadow
            ZStack {
                // Shadow layer - cast below
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.6),
                                Color.black.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blur(radius: 15)
                    .offset(x: 0, y: 25)
                
                // Card with image
                cardImageView
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipped()
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 6)
                    .overlay(
                        // Custom frame border if present
                        customFrameOverlay
                    )
            }
            
            // Heat info - ONLY show for front card
            if position == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("\(card.heatCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(card.cardMake)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text("\(card.cardModel) '\(String(card.cardYear.suffix(2)))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var cardImageView: some View {
        if let url = URL(string: card.imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderView(isLoading: true)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderView(isLoading: false)
                @unknown default:
                    placeholderView(isLoading: false)
                }
            }
        } else {
            placeholderView(isLoading: false)
        }
    }
    
    @ViewBuilder
    private var customFrameOverlay: some View {
        if let frameName = card.customFrame, frameName != "None" {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    frameName == "White" ? Color.white : Color.black,
                    lineWidth: 6
                )
        }
    }
    
    private func placeholderView(isLoading: Bool) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HotCardsCarousel()
            .padding()
    }
}
