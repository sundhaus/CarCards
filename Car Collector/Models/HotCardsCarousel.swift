//
//  HotCardsCarousel.swift
//  CarCardCollector
//
//  3D horizontal carousel with free scrolling, snap on release, infinite loop, and blur
//

import SwiftUI

struct HotCardsCarousel: View {
    @StateObject private var hotCardsService = HotCardsService()
    @State private var currentIndex = 0
    @State private var isDragging = false
    
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
                carouselView
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
            hotCardsService.fetchHotCardsIfNeeded(limit: 20)
        }
    }
    
    // MARK: - Carousel View (Free Scroll + Snap on Release + Blur)
    
    private var carouselView: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {
                        // Create infinite loop by repeating cards
                        ForEach(createInfiniteArray(), id: \.id) { item in
                            GeometryReader { cardGeometry in
                                HotCardItem(card: item.card)
                                    .rotation3DEffect(
                                        getRotationAngle(for: cardGeometry, screenWidth: geometry.size.width),
                                        axis: (x: 0, y: 1, z: 0),
                                        anchor: .center,
                                        anchorZ: 0.0,
                                        perspective: 1.0
                                    )
                                    .blur(radius: getBlurRadius(for: cardGeometry, screenWidth: geometry.size.width))
                                    .scaleEffect(getScale(for: cardGeometry, screenWidth: geometry.size.width))
                                    .anchorPreference(
                                        key: CardPositionPreferenceKey.self,
                                        value: .bounds
                                    ) { anchor in
                                        [CardPosition(id: item.id, bounds: anchor)]
                                    }
                            }
                            .frame(width: 280, height: 220)
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, (geometry.size.width - 280) / 2)
                    .padding(.vertical, 12)
                }
                .overlayPreferenceValue(CardPositionPreferenceKey.self) { preferences in
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: isDragging) { oldValue, newValue in
                                if oldValue && !newValue {
                                    // User just stopped dragging - wait for momentum to settle
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        snapToClosestCard(preferences: preferences, geometry: geo, proxy: proxy)
                                    }
                                }
                            }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            isDragging = true
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .onAppear {
                    // Start in the middle of infinite array
                    let startIndex = hotCardsService.hotCards.count * 50
                    proxy.scrollTo(startIndex, anchor: .center)
                    currentIndex = startIndex
                }
            }
        }
        .frame(height: 240)
    }
    
    // MARK: - Preference Key for Card Positions
    
    private struct CardPosition {
        let id: Int
        let bounds: Anchor<CGRect>
    }
    
    private struct CardPositionPreferenceKey: PreferenceKey {
        static var defaultValue: [CardPosition] = []
        
        static func reduce(value: inout [CardPosition], nextValue: () -> [CardPosition]) {
            value.append(contentsOf: nextValue())
        }
    }
    
    // MARK: - Find and Snap to Center
    
    private func snapToClosestCard(preferences: [CardPosition], geometry: GeometryProxy, proxy: ScrollViewProxy) {
        let screenCenter = geometry.size.width / 2
        
        // Find card closest to center
        var closestCard: (id: Int, distance: CGFloat)?
        
        for position in preferences {
            let rect = geometry[position.bounds]
            let cardMidX = rect.midX
            let distance = abs(cardMidX - screenCenter)
            
            if closestCard == nil || distance < closestCard!.distance {
                closestCard = (position.id, distance)
            }
        }
        
        guard let closest = closestCard else { return }
        
        // Snap to that card
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            proxy.scrollTo(closest.id, anchor: .center)
            currentIndex = closest.id
        }
        
        // Reset to middle if we're getting near edges
        let totalCards = hotCardsService.hotCards.count
        if totalCards > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let middlePosition = totalCards * 50
                if currentIndex < totalCards * 10 || currentIndex > totalCards * 90 {
                    let offset = currentIndex % totalCards
                    currentIndex = middlePosition + offset
                    proxy.scrollTo(currentIndex, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Infinite Loop
    
    private struct CardItem: Identifiable {
        let id: Int
        let card: FriendActivity
    }
    
    private func createInfiniteArray() -> [CardItem] {
        guard !hotCardsService.hotCards.isEmpty else { return [] }
        
        var items: [CardItem] = []
        let cards = hotCardsService.hotCards
        
        // Create 100 copies for smooth infinite scrolling
        for i in 0..<(cards.count * 100) {
            let cardIndex = i % cards.count
            items.append(CardItem(id: i, card: cards[cardIndex]))
        }
        
        return items
    }
    
    // MARK: - Visual Effects
    
    private func getRotationAngle(for geometry: GeometryProxy, screenWidth: CGFloat) -> Angle {
        let midX = geometry.frame(in: .global).midX
        let screenMidX = screenWidth / 2
        let distance = midX - screenMidX
        
        return Angle(degrees: Double(distance) / -15.0)
    }
    
    private func getBlurRadius(for geometry: GeometryProxy, screenWidth: CGFloat) -> CGFloat {
        let midX = geometry.frame(in: .global).midX
        let screenMidX = screenWidth / 2
        let distance = abs(midX - screenMidX)
        
        let blurThreshold: CGFloat = 80
        let maxBlur: CGFloat = 8
        
        if distance < blurThreshold {
            return 0
        } else {
            let blurProgress = (distance - blurThreshold) / 120
            return min(maxBlur, blurProgress * maxBlur)
        }
    }
    
    private func getScale(for geometry: GeometryProxy, screenWidth: CGFloat) -> CGFloat {
        let midX = geometry.frame(in: .global).midX
        let screenMidX = screenWidth / 2
        let distance = abs(midX - screenMidX)
        
        let scaleThreshold: CGFloat = 60
        let minScale: CGFloat = 0.88
        
        if distance < scaleThreshold {
            return 1.0
        } else {
            let scaleProgress = (distance - scaleThreshold) / 180
            return max(minScale, 1.0 - (scaleProgress * (1.0 - minScale)))
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
            // Card with proper format
            ZStack {
                // Custom frame/border
                if let frameName = card.customFrame, frameName != "None" {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(frameName == "White" ? Color.white : Color.black, lineWidth: 6)
                        .frame(width: 280, height: 157.5)
                }
                
                // Card image
                cardImageView
                    .frame(width: 268, height: 150.75)
                    .clipped()
                
                // Card text overlay at bottom
                VStack {
                    Spacer()
                    Text("\(card.cardMake) \(card.cardModel)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.6))
                }
                .frame(width: 268, height: 150.75)
            }
            .frame(width: 280, height: 157.5)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
            )
            
            // Heat info below card
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("\(card.heatCount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("'\(String(card.cardYear.suffix(2)))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 280)
            .padding(.horizontal, 4)
        }
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
