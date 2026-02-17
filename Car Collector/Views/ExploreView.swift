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
        .toolbar(.hidden, for: .tabBar)
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
        ZStack {
            // Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
            
            HStack {
                // Back button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Text("Explore")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Invisible spacer for centering
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .opacity(0)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(height: 60)
    }
    
    // MARK: - Content Views
    
    private var categoryScrollView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // Featured row first (if we have featured cards)
                if !exploreService.featuredCards.isEmpty {
                    FeaturedRow(cards: exploreService.featuredCards)
                }
                
                // Show each category that has cards
                ForEach(sortedCategories, id: \.self) { category in
                    if let cards = exploreService.cardsByCategory[category], !cards.isEmpty {
                        CategoryRow(category: category, cards: cards)
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
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("No cars with specs yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Cards need specs to appear in Explore")
                .font(.caption)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Featured header (tappable to open full view)
            NavigationLink {
                CategoryDetailView(category: nil, initialCards: cards)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Featured")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Top picks from the community")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
            .onAppear {
                print("🌟 FEATURED ROW: Rendering with \(cards.count) cards")
            }
            
            // Horizontal scrolling cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cards) { card in
                        NavigationLink {
                            UserProfileView(userId: card.userId, username: card.username)
                        } label: {
                            ExploreCardItem(card: card, height: 140)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: VehicleCategory
    let cards: [FriendActivity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header (tappable to open full view)
            NavigationLink {
                CategoryDetailView(category: category, initialCards: cards)
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(category.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
            
            // Horizontal scrolling cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cards) { card in
                        NavigationLink {
                            UserProfileView(userId: card.userId, username: card.username)
                        } label: {
                            ExploreCardItem(card: card, height: 140)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Explore Card Item (Landscape FIFA-style)

struct ExploreCardItem: View {
    let card: FriendActivity
    let height: CGFloat
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    
    // Card is landscape: width is 16:9 ratio
    private var cardWidth: CGFloat { height * (16/9) }
    
    var body: some View {
        ZStack {
            // Card background with gradient
            RoundedRectangle(cornerRadius: 8)
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
            
            VStack(spacing: 0) {
                // Top bar - GEN badge + Car name
                HStack(spacing: 8) {
                    // GEN badge (top-left)
                    VStack(spacing: 2) {
                        Text("GEN")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black.opacity(0.6))
                        Text("\(card.level)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    )
                    
                    // Car name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.cardMake.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.7))
                        
                        Text(card.cardModel)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Heat indicator (if any)
                    if card.heatCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("\(card.heatCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.9))
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                // Car image area (center)
                Group {
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
                                    .font(.system(size: 30))
                                    .foregroundStyle(.gray.opacity(0.4))
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                
                // Bottom bar - Username
                HStack {
                    Text("@\(card.username)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.black.opacity(0.5))
                    
                    Spacer()
                    
                    Text(card.cardYear)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.4))
            }
            
            // Black border (like your sketch)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.black, lineWidth: 3)
        }
        .frame(width: cardWidth, height: height)
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        .onAppear {
            loadImage()
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
