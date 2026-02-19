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
    @State private var fullScreenActivity: FriendActivity? = nil
    @State private var isDoubleColumn = true
    
    private let cardsPerPage = 10
    
    var body: some View {
        ZStack {
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Glass header with padding
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
            // Start with preloaded cards from Explore
            allCards = initialCards
            currentPage = 0
            
            // If we have exactly 10 cards, there might be more
            hasMorePages = initialCards.count >= cardsPerPage
        }
    }
    
    // MARK: - Header
    
    private var categoryTitle: String {
        category?.rawValue ?? "Featured"
    }
    
    private var categoryEmoji: String {
        category?.emoji ?? "🌟"
    }
    
    private var header: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
            
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                HStack(spacing: 12) {
                    // Back button
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.pBody)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    // Title
                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Text(categoryEmoji)
                                .font(.pBody)
                            Text(categoryTitle)
                                .font(.pBody)
                                .fontWeight(.bold)
                        }
                        
                        Text("\(allCards.count) cards")
                            .font(.pCaption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Grid toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDoubleColumn.toggle()
                        }
                    }) {
                        Image(systemName: isDoubleColumn ? "square.grid.2x2" : "rectangle.grid.1x2")
                            .font(.pBody)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        .frame(height: 52)
        .glassEffect(.regular, in: .rect)
    }
    
    // MARK: - Card Pages View
    
    private var cardPagesView: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<totalPages, id: \.self) { pageIndex in
                let startIndex = pageIndex * cardsPerPage
                let endIndex = min(startIndex + cardsPerPage, allCards.count)
                let pageCards = Array(allCards[startIndex..<endIndex])
                
                ScrollView(.vertical, showsIndicators: true) {
                    if isDoubleColumn {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                            ForEach(pageCards) { card in
                                CategoryCardItem(card: card)
                                    .onTapGesture {
                                        fullScreenActivity = card
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                            ForEach(pageCards) { card in
                                CategoryCardItem(card: card)
                                    .onTapGesture {
                                        fullScreenActivity = card
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
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
                .font(.poppins(60))
                .foregroundStyle(.gray)
            Text("No cards in this category yet")
                .font(.pSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Category Card Item

struct CategoryCardItem: View {
    let card: FriendActivity
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = width * (9.0 / 16.0)  // Maintain 16:9 aspect ratio
            
            FIFACardView(card: card, height: height)
                .frame(width: width, height: height)
        }
        .aspectRatio(16/9, contentMode: .fit)
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
