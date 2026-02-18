//
//  CategoryDetailView.swift
//  CarCardCollector
//
//  Full-page view for browsing all cards in a specific category
//  Shows 10 cards per page, loads more on next page
//

import SwiftUI
import FirebaseFirestore

struct CategoryDetailView: View {
    let category: VehicleCategory?  // nil for Featured
    let initialCards: [FriendActivity]  // Preloaded top 10 from Explore
    
    @StateObject private var exploreService = ExploreService()
    @Environment(\.dismiss) private var dismiss
    @State private var allCards: [FriendActivity] = []
    @State private var currentPage = 0
    @State private var lastDocument: DocumentSnapshot?
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    
    private let cardsPerPage = 10
    
    var body: some View {
        ZStack {
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Paginated card grid
                if allCards.isEmpty {
                    emptyView
                } else {
                    cardPagesView
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Start with preloaded cards from Explore
            allCards = initialCards
            currentPage = 0
            
            // If we have exactly 10 cards, there might be more
            hasMorePages = initialCards.count >= cardsPerPage
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
            
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        if let cat = category {
                            Text(cat.emoji)
                                .font(.title3)
                            Text(cat.rawValue)
                                .font(.title3)
                                .fontWeight(.bold)
                        } else {
                            Text("🌟")
                                .font(.title3)
                            Text("Featured")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    
                    Text("\(allCards.count) cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .opacity(0)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(height: 60)
    }
    
    // MARK: - Card Pages View
    
    private var cardPagesView: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<totalPages, id: \.self) { pageIndex in
                let startIndex = pageIndex * cardsPerPage
                let endIndex = min(startIndex + cardsPerPage, allCards.count)
                let pageCards = Array(allCards[startIndex..<endIndex])
                
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(pageCards) { card in
                            NavigationLink {
                                UserProfileView(userId: card.userId, username: card.username)
                            } label: {
                                CategoryCardItem(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .tag(pageIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .onChange(of: currentPage) { oldValue, newValue in
            // If we're on the last page and have more to load
            if newValue == totalPages - 1 && hasMorePages && !isLoadingMore {
                loadNextPage()
            }
        }
    }
    
    private var totalPages: Int {
        Int(ceil(Double(allCards.count) / Double(cardsPerPage)))
    }
    
    // MARK: - Load Next Page
    
    private func loadNextPage() {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        print("📄 Loading next page for \(category?.rawValue ?? "Featured")")
        
        if let cat = category {
            // Load category cards
            exploreService.fetchCategoryCardsPaginated(
                category: cat,
                startAfter: lastDocument,
                limit: cardsPerPage
            ) { newCards, lastDoc in
                DispatchQueue.main.async {
                    if newCards.isEmpty {
                        hasMorePages = false
                        print("✅ No more pages for \(cat.rawValue)")
                    } else {
                        allCards.append(contentsOf: newCards)
                        lastDocument = lastDoc
                        print("✅ Loaded \(newCards.count) more cards for \(cat.rawValue)")
                    }
                    isLoadingMore = false
                }
            }
        } else {
            // Load featured cards
            exploreService.fetchFeaturedCardsPaginated(
                startAfter: lastDocument,
                limit: cardsPerPage
            ) { newCards, lastDoc in
                DispatchQueue.main.async {
                    if newCards.isEmpty {
                        hasMorePages = false
                        print("✅ No more featured pages")
                    } else {
                        allCards.append(contentsOf: newCards)
                        lastDocument = lastDoc
                        print("✅ Loaded \(newCards.count) more featured cards")
                    }
                    isLoadingMore = false
                }
            }
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("No cards in this category yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Category Card Item

struct CategoryCardItem: View {
    let card: FriendActivity
    
    var body: some View {
        FIFACardView(card: card, height: 140)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(
            category: .sportsCar,
            initialCards: []
        )
    }
}
