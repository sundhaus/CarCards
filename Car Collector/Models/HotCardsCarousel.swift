//
//  HotCardsCarousel.swift
//  CarCardCollector
//
//  3D horizontal carousel with free scrolling, snap on release, infinite loop, and blur
//

import SwiftUI

struct HotCardsCarousel: View {
    @ObservedObject private var hotCardsService = HotCardsService.shared
    @State private var currentIndex = 0
    @State private var isDragging = false
    @StateObject private var imageCache = CarouselImageCache()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Carousel content only - header is now in FeaturedCollectionsContainer
            if hotCardsService.isLoading {
                loadingView
            } else if hotCardsService.hotCards.isEmpty {
                emptyView
            } else {
                carouselView
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            hotCardsService.fetchHotCardsIfNeeded()
            imageCache.preloadImages(from: hotCardsService.hotCards)
        }
        .onChange(of: hotCardsService.hotCards.count) { _, _ in
            imageCache.preloadImages(from: hotCardsService.hotCards)
        }
    }
    
    // MARK: - Carousel View (One Card at a Time - Direction Only)
    
    private var carouselView: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {
                        // Create infinite loop by repeating cards
                        ForEach(createInfiniteArray(), id: \.id) { item in
                            GeometryReader { cardGeometry in
                                HotCardItem(card: item.card, imageCache: imageCache)
                                    .rotation3DEffect(
                                        getRotationAngle(for: cardGeometry, screenWidth: geometry.size.width),
                                        axis: (x: 0, y: 1, z: 0),
                                        anchor: .center,
                                        anchorZ: 0.0,
                                        perspective: 1.0
                                    )
                                    .blur(radius: getBlurRadius(for: cardGeometry, screenWidth: geometry.size.width))
                                    .scaleEffect(getScale(for: cardGeometry, screenWidth: geometry.size.width))
                                    .cardTilt(intensity: 0.8, perspective: 0.6)
                            }
                            .frame(width: DeviceScale.w(320), height: DeviceScale.h(180))
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, (geometry.size.width - DeviceScale.w(320)) / 2)
                }
                .frame(height: DeviceScale.h(180))
                .padding(.top, DeviceScale.h(12))
                .scrollDisabled(true)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            isDragging = true
                            // Visual preview only - no actual scrolling
                        }
                        .onEnded { value in
                            isDragging = false
                            handleSwipeDirection(translation: value.translation.width, proxy: proxy)
                        }
                )
                .onAppear {
                    // Start in the middle of infinite array
                    let startIndex = hotCardsService.hotCards.count * 50
                    DispatchQueue.main.async {
                        proxy.scrollTo(startIndex, anchor: .center)
                        currentIndex = startIndex
                    }
                }
            }
        }
        .frame(height: DeviceScale.h(220))
    }
    
    // MARK: - Swipe Direction Handler
    
    private func handleSwipeDirection(translation: CGFloat, proxy: ScrollViewProxy) {
        let totalCards = hotCardsService.hotCards.count
        guard totalCards > 0 else { return }
        
        let threshold: CGFloat = 30
        
        if translation < -threshold {
            // Swiped left - next card only
            currentIndex = (currentIndex + 1) % (totalCards * 100)
        } else if translation > threshold {
            // Swiped right - previous card only
            currentIndex = (currentIndex - 1 + totalCards * 100) % (totalCards * 100)
        }
        // If less than threshold, stay on current card (do nothing, already centered)
        
        // Snap to the card with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            proxy.scrollTo(currentIndex, anchor: .center)
        }
        
        // Reset to middle if we're getting near edges
        let middlePosition = totalCards * 50
        if currentIndex < totalCards * 10 || currentIndex > totalCards * 90 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let offset = currentIndex % totalCards
                let newIndex = middlePosition + offset
                currentIndex = newIndex
                proxy.scrollTo(newIndex, anchor: .center)
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
            Text("Loading hot cards...")
                .font(.pCaption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DeviceScale.h(170))
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.poppins(50))
                .foregroundStyle(.orange)
            
            Text("No hot cards yet")
                .font(.pSubheadline)
                .foregroundStyle(.primary.opacity(0.8))
            
            Text("Be the first to get some heat!")
                .font(.pCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DeviceScale.h(170))
    }
}

// MARK: - Image Cache for Carousel

class CarouselImageCache: ObservableObject {
    @Published var images: [String: UIImage] = [:]
    private var loadingURLs: Set<String> = []
    
    func preloadImages(from cards: [FriendActivity]) {
        for card in cards {
            let urlString = card.imageURL
            guard !urlString.isEmpty,
                  images[urlString] == nil,
                  !loadingURLs.contains(urlString),
                  let url = URL(string: urlString) else { continue }
            
            loadingURLs.insert(urlString)
            
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data, let image = UIImage(data: data) else {
                    DispatchQueue.main.async { self?.loadingURLs.remove(urlString) }
                    return
                }
                DispatchQueue.main.async {
                    self?.images[urlString] = image
                    self?.loadingURLs.remove(urlString)
                }
            }.resume()
        }
    }
    
    func image(for urlString: String) -> UIImage? {
        return images[urlString]
    }
}

// MARK: - Hot Card Item

struct HotCardItem: View {
    let card: FriendActivity
    @ObservedObject var imageCache: CarouselImageCache
    
    // Responsive dimensions for carousel
    private let cardHeight: CGFloat = DeviceScale.h(180)
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
            
            // Car image - full bleed, from cache
            cardImageView
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
            
            // Car name overlay - top left, horizontal
            VStack {
                HStack {
                    HStack(spacing: 4) {
                        let config = CardBorderConfig.forFrame(card.customFrame)
                        Text(card.cardMake.uppercased())
                            .font(.custom("Futura-Light", fixedSize: cardHeight * 0.08))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        
                        Text(card.cardModel.uppercased())
                            .font(.custom("Futura-Bold", fixedSize: cardHeight * 0.08))
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
            
            // Heat indicator - bottom right if has heat
            if card.heatCount > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: cardHeight * 0.09))
                            Text("\(card.heatCount)")
                                .font(.system(size: cardHeight * 0.09, weight: .bold))
                        }
                        .foregroundColor(.orange)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .padding(.bottom, cardHeight * 0.08)
                        .padding(.trailing, cardHeight * 0.08)
                    }
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
    }
    
    @ViewBuilder
    private var cardImageView: some View {
        if let cachedImage = imageCache.image(for: card.imageURL) {
            // Use cached image — instant, no flicker
            Image(uiImage: cachedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let url = URL(string: card.imageURL) {
            // Fallback to AsyncImage while cache loads
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
            .fill(Color.white.opacity(0.3))
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.gray)
                    } else {
                        Image(systemName: "car.fill")
                            .font(.poppins(30))
                            .foregroundStyle(.gray.opacity(0.4))
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
