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
                } else if exploreService.cardsByCategory.isEmpty {
                    emptyView
                } else {
                    categoryScrollView
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            exploreService.fetchCardsIfNeeded()
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
                
                VStack(spacing: 2) {
                    Text("Explore")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    // Countdown timer
                    if !exploreService.timeUntilNextRefresh.isEmpty {
                        Text("Next refresh: \(exploreService.timeUntilNextRefresh)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                
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
            VStack(spacing: 24) {
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

// MARK: - Category Row

struct CategoryRow: View {
    let category: VehicleCategory
    let cards: [FriendActivity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 8) {
                Text(category.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("\(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Horizontal scrolling cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cards) { card in
                        NavigationLink {
                            UserProfileView(userId: card.userId, username: card.username)
                        } label: {
                            ExploreCardItem(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Explore Card Item

struct ExploreCardItem: View {
    let card: FriendActivity
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Card image
            Group {
                if let image = cardImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoadingImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }
            }
            .frame(width: 200, height: 112.5)
            .clipped()
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Car info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(card.cardMake) \(card.cardModel)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    // Owner
                    Text("by \(card.username)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Spacer()
                    
                    // Heat
                    if card.heatCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(card.heatCount)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                    }
                }
            }
            .frame(width: 200)
        }
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
