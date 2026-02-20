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
            VStack(spacing: 2) {
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
        VStack(alignment: .leading, spacing: 0) {
            // Floating glass header — taps navigate to category
            NavigationLink {
                CategoryDetailView(category: nil, initialCards: cards)
            } label: {
                HStack(spacing: 8) {
                    Text("FEATURED")
                        .font(.pHeadline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text("\(cards.count)")
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)
            
            // Card container — individual cards handle taps
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cards) { card in
                        FIFACardView(card: card, height: 140, onSingleTap: {
                            onCardTap(card)
                        })
                            .frame(width: 140 * (16/9), height: 140)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color.white.opacity(0.03))
        }
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
        VStack(alignment: .leading, spacing: 0) {
            // Floating glass header — taps navigate to category
            NavigationLink {
                CategoryDetailView(category: category, initialCards: cards)
            } label: {
                HStack(spacing: 8) {
                    Text(category.rawValue.uppercased())
                        .font(.pHeadline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text("\(cards.count)")
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)
            
            // Card container — individual cards handle taps
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cards) { card in
                        FIFACardView(card: card, height: 140, onSingleTap: {
                            onCardTap(card)
                        })
                            .frame(width: 140 * (16/9), height: 140)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color.white.opacity(0.03))
        }
    }
}

// MARK: - Explore Card Item (Landscape FIFA-style)

struct ExploreCardItem: View {
    let card: FriendActivity
    let height: CGFloat
    
    var body: some View {
        FIFACardView(card: card, height: height)
            .frame(width: height * (16/9), height: height)
    }
}

#Preview {
    NavigationStack {
        ExploreView()
    }
}
