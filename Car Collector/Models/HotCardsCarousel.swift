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
    
    // MARK: - Card Stack View (3D Infinite Swipe)
    
    private var cardStackView: some View {
        GeometryReader { geometry in
            ZStack {
                // Show up to 3 cards in the stack for depth effect
                ForEach(0..<min(3, hotCardsService.hotCards.count), id: \.self) { position in
                    let cardIndex = getCardIndex(for: position)
                    
                    if cardIndex < hotCardsService.hotCards.count {
                        let card = hotCardsService.hotCards[cardIndex]
                        
                        HotCardItem(card: card)
                            .frame(width: min(geometry.size.width - 40, 350))
                            .offset(x: getOffsetX(for: position), y: getOffsetY(for: position))
                            .scaleEffect(getScale(for: position))
                            .rotationEffect(getRotation(for: position), anchor: .bottom)
                            .rotation3DEffect(
                                getRotation3D(for: position),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.5
                            )
                            .opacity(getOpacity(for: position))
                            .zIndex(Double(3 - position))
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: dragOffset)
                            .gesture(
                                position == 0 ? // Only front card is swipeable
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation.width
                                    }
                                    .onEnded { value in
                                        handleSwipeEnd(translation: value.translation.width)
                                    }
                                : nil
                            )
                    }
                }
            }
            .frame(width: geometry.size.width, height: 300)
        }
        .frame(height: 300)
        .padding(.bottom, 12)
    }
    
    // MARK: - Position Calculations
    
    private func getCardIndex(for position: Int) -> Int {
        // Infinite loop through cards
        let index = (currentIndex + position) % hotCardsService.hotCards.count
        return index >= 0 ? index : index + hotCardsService.hotCards.count
    }
    
    private func getOffsetX(for position: Int) -> CGFloat {
        if position == 0 {
            // Front card follows drag
            return dragOffset * 0.7
        } else {
            // Cards behind move slightly when front card is dragged
            return -dragOffset * 0.1 * CGFloat(position)
        }
    }
    
    private func getOffsetY(for position: Int) -> CGFloat {
        // Stack cards with slight vertical offset
        return CGFloat(position) * 8
    }
    
    private func getScale(for position: Int) -> CGFloat {
        if position == 0 {
            // Front card scales down when dragged
            let dragScale = 1.0 - min(abs(dragOffset) / 1000, 0.15)
            return dragScale
        } else {
            // Cards behind are progressively smaller
            let baseScale = 1.0 - (CGFloat(position) * 0.08)
            // Scale up slightly when front card is dragged
            let dragInfluence = min(abs(dragOffset) / 2000, 0.04) * CGFloat(position)
            return baseScale + dragInfluence
        }
    }
    
    private func getRotation(for position: Int) -> Angle {
        if position == 0 {
            // Front card rotates with drag (subtle tilt)
            return Angle(degrees: Double(dragOffset) / 15)
        }
        return Angle(degrees: 0)
    }
    
    private func getRotation3D(for position: Int) -> Angle {
        if position == 0 {
            // 3D rotation on Y-axis when dragging
            return Angle(degrees: Double(dragOffset) / 10)
        }
        return Angle(degrees: 0)
    }
    
    private func getOpacity(for position: Int) -> Double {
        if position == 0 {
            // Front card fades when dragged far
            return max(0.4, 1.0 - abs(dragOffset) / 500)
        } else if position <= 2 {
            // Show first 3 cards
            return 1.0 - (Double(position) * 0.25)
        }
        return 0
    }
    
    // MARK: - Swipe Handling
    
    private func handleSwipeEnd(translation: CGFloat) {
        let threshold: CGFloat = 100
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
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
    
    var body: some View {
        VStack(spacing: 12) {
            // Card image with 3D shadow
            ZStack {
                // Shadow layer
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.5),
                                Color.black.opacity(0.25),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blur(radius: 12)
                    .offset(y: 18)
                
                // Card with image
                cardImageView
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipped()
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: 12)
                    .overlay(
                        // Custom frame border if present
                        customFrameOverlay
                    )
            }
            
            // Heat info
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
