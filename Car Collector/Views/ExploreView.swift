//
//  ExploreView.swift
//  CarCardCollector
//
//  Explore page showing cards grouped by category
//  Refreshes every 3 hours at 12am, 3am, 6am, 9am, 12pm, 3pm, 6pm, 9pm EST
//

import SwiftUI

struct ExploreView: View {
    @StateObject private var exploreService = ExploreService()
    @Environment(\.dismiss) private var dismiss
    @State private var fullScreenActivity: FriendActivity? = nil
    var isLandscape: Bool = false
    
    var body: some View {
        ZStack {
            // Background
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                if exploreService.isLoading {
                    loadingView
                } else if exploreService.featuredCards.isEmpty && exploreService.cardsByCategory.isEmpty {
                    emptyView
                } else {
                    categoryScrollView
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if let activity = fullScreenActivity {
                FullScreenFriendCardView(
                    activity: activity,
                    isShowing: Binding(
                        get: { fullScreenActivity != nil },
                        set: { if !$0 { fullScreenActivity = nil } }
                    )
                )
            }
        }
        .onAppear {
            print("\n📱 EXPLORE VIEW: onAppear triggered")
            print("   isLoading: \(exploreService.isLoading)")
            print("   featuredCards.count: \(exploreService.featuredCards.count)")
            print("   cardsByCategory.count: \(exploreService.cardsByCategory.count)")
            exploreService.fetchAllCategories()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.pTitle3)
                    .foregroundStyle(.primary)
            }
            
            Text("EXPLORE")
                .font(.pTitle2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 18)
        .padding(.bottom, 10)
        .glassEffect(.regular, in: .rect)
    }
    
    // MARK: - Content Views
    
    private var categoryScrollView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // Featured row first (if we have featured cards)
                if !exploreService.featuredCards.isEmpty {
                    FeaturedRow(cards: exploreService.featuredCards) { card in
                        fullScreenActivity = card
                    }
                }
                
                // Show each category that has cards
                ForEach(sortedCategories, id: \.self) { category in
                    if let cards = exploreService.cardsByCategory[category], !cards.isEmpty {
                        CategoryRow(category: category, cards: cards) { card in
                            fullScreenActivity = card
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, isLandscape ? 20 : 100)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
            Text("Loading cars...")
                .font(.pCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.poppins(60))
                .foregroundStyle(.gray)
            Text("No cars with specs yet")
                .font(.pSubheadline)
                .foregroundStyle(.secondary)
            Text("Cards need specs to appear in Explore")
                .font(.pCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Sort categories by priority (performance categories first)
    private var sortedCategories: [VehicleCategory] {
        let priorityOrder: [VehicleCategory] = [
            .hypercar, .supercar, .track, .sportsCar, .muscle,
            .rally, .offRoad, .electric, .hybrid,
            .luxury, .suv, .truck, .coupe, .convertible,
            .sedan, .wagon, .hatchback, .van, .classic, .concept
        ]
        
        return priorityOrder.filter { exploreService.cardsByCategory[$0] != nil }
    }
}

// MARK: - Featured Row

struct FeaturedRow: View {
    let cards: [FriendActivity]
    var onCardTap: (FriendActivity) -> Void
    
    var body: some View {
        NavigationLink {
            CategoryDetailView(category: nil, initialCards: cards)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Banner header
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FEATURED")
                            .font(.pHeadline)
                            .foregroundStyle(.primary)
                        
                        Text("Top picks from the community")
                            .font(.pCaption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.pCaption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Full-width dark card container
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cards) { card in
                            ExploreCardItem(card: card, height: 140)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color.white.opacity(0.04))
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            print("🌟 FEATURED ROW: Rendering with \(cards.count) cards")
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: VehicleCategory
    let cards: [FriendActivity]
    var onCardTap: (FriendActivity) -> Void
    
    var body: some View {
        NavigationLink {
            CategoryDetailView(category: category, initialCards: cards)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Banner header
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue.uppercased())
                            .font(.pHeadline)
                            .foregroundStyle(.primary)
                        
                        Text(category.description)
                            .font(.pCaption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.pCaption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Full-width dark card container
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cards) { card in
                            ExploreCardItem(card: card, height: 140)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color.white.opacity(0.04))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Explore Card Item (Landscape FIFA-style)

struct ExploreCardItem: View {
    let card: FriendActivity
    let height: CGFloat
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    
    private var cardWidth: CGFloat { height * (16/9) }
    
    var body: some View {
        ZStack {
            // Card background with gradient
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
            
            // Car image - full bleed
            cardImageView
                .frame(width: cardWidth, height: height)
                .clipped()
            
            // Border PNG overlay based on customFrame
            if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: height)
                    .allowsHitTesting(false)
            }
            
            // Car name overlay - top left, horizontal
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        let config = CardBorderConfig.forFrame(card.customFrame)
                        Text(card.cardMake.uppercased())
                            .font(.custom("Futura-Light", size: height * 0.08))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        
                        Text(card.cardModel.uppercased())
                            .font(.custom("Futura-Bold", size: height * 0.08))
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
            
            // Heat indicator - bottom right if has heat
            if card.heatCount > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: height * 0.09))
                            Text("\(card.heatCount)")
                                .font(.system(size: height * 0.09, weight: .bold))
                        }
                        .foregroundStyle(.orange)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .padding(.bottom, height * 0.08)
                        .padding(.trailing, height * 0.08)
                    }
                }
            }
        }
        .frame(width: cardWidth, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.09))
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        .onAppear {
            loadImage()
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
                    Image(systemName: "car.fill")
                        .font(.system(size: height * 0.3))
                        .foregroundStyle(.gray.opacity(0.4))
                )
        }
    }
    
    private func loadImage() {
        guard !isLoadingImage, cardImage == nil else { return }
        
        isLoadingImage = true
        
        guard let url = URL(string: card.imageURL) else {
            isLoadingImage = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    isLoadingImage = false
                }
                return
            }
            
            DispatchQueue.main.async {
                cardImage = image
                isLoadingImage = false
            }
        }.resume()
    }
}

#Preview {
    NavigationStack {
        ExploreView()
    }
}
