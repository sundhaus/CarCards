//
//  CategoryDetailView.swift
//  CarCardCollector
//
//  Full-page view for browsing all cards in a specific category
//  Scrollable grid with load-more pagination
//

import SwiftUI
import FirebaseFirestore

struct CategoryDetailView: View {
    let category: VehicleCategory?  // nil for Featured
    let initialCards: [FriendActivity]  // Preloaded top 10 from Explore
    
    @StateObject private var exploreService = ExploreService()
    @Environment(\.dismiss) private var dismiss
    @State private var allCards: [FriendActivity] = []
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
                // Glass header
                header
                
                // Scrollable card grid
                if allCards.isEmpty {
                    emptyView
                } else {
                    cardGridView
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
            allCards = initialCards
            hasMorePages = initialCards.count >= cardsPerPage
        }
    }
    
    // MARK: - Header
    
    private var categoryTitle: String {
        category?.rawValue ?? "Featured"
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.pTitle3)
                    .foregroundStyle(.primary)
            }
            
            // Title + count
            HStack(spacing: 8) {
                Text(categoryTitle.uppercased())
                    .font(.pBody)
                    .fontWeight(.bold)
                
                Text("\(allCards.count)")
                    .font(.pCaption)
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
                    .font(.pTitle3)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 18)
        .padding(.bottom, 10)
        .glassEffect(.regular, in: .rect)
    }
    
    // MARK: - Card Grid View (continuous scroll with load-more)
    
    private var gridColumns: [GridItem] {
        if isDoubleColumn {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        } else {
            return [GridItem(.flexible())]
        }
    }
    
    private var cardGridView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(allCards) { card in
                    CategoryCardItem(card: card)
                        .onTapGesture {
                            fullScreenActivity = card
                        }
                        .onAppear {
                            // Load more when last few cards appear
                            if card.id == allCards.last?.id && hasMorePages && !isLoadingMore {
                                loadNextPage()
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
            
            if isLoadingMore {
                ProgressView()
                    .tint(.white)
                    .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Load Next Page
    
    private func loadNextPage() {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        print("📄 Loading next page for \(category?.rawValue ?? "Featured")")
        
        if let cat = category {
            exploreService.fetchCategoryCardsPaginated(
                category: cat,
                startAfter: lastDocument,
                limit: cardsPerPage
            ) { newCards, lastDoc in
                DispatchQueue.main.async {
                    if newCards.isEmpty {
                        hasMorePages = false
                    } else {
                        allCards.append(contentsOf: newCards)
                        lastDocument = lastDoc
                    }
                    isLoadingMore = false
                }
            }
        } else {
            exploreService.fetchFeaturedCardsPaginated(
                startAfter: lastDocument,
                limit: cardsPerPage
            ) { newCards, lastDoc in
                DispatchQueue.main.async {
                    if newCards.isEmpty {
                        hasMorePages = false
                    } else {
                        allCards.append(contentsOf: newCards)
                        lastDocument = lastDoc
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
            let height = width * (9.0 / 16.0)
            
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
