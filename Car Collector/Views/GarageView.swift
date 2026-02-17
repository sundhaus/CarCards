//
//  GarageView.swift
//  CarCardCollector
//
//  Garage page with pagination and card interactions
//  Supports vehicles, drivers, and locations
//

import SwiftUI

struct GarageView: View {
    var isLandscape: Bool = false
    @State private var showCamera = false
    @State private var allCards: [AnyCard] = []
    @State private var cardsPerRow = 2 // 1 or 2
    @State private var currentPage = 0
    @State private var showActionSheet = false
    @State private var actionSheetCard: AnyCard?
    @State private var showCardDetail = false
    @State private var selectedCard: AnyCard?
    @State private var showCustomize = false
    @State private var forceOrientationUpdate = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark blue background
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                VStack {
                    if allCards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("Your collection will appear here")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 100)
                    } else {
                        if isLandscape {
                            // Landscape: Continuous horizontal scroll
                            landscapeScrollView
                        } else {
                            // Portrait: Paged vertical scroll
                            portraitPagedView
                        }
                    }
                }
                .blur(radius: showCardDetail ? 10 : 0)
                
                // Landscape blur gradient on right side
                if isLandscape {
                    HStack(spacing: 0) {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.7), .black, .black],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 200)
                        .allowsHitTesting(false)
                    }
                    .ignoresSafeArea()
                }
                
                // Full screen card detail overlay
                if showCardDetail, let card = selectedCard {
                    UnifiedCardDetailView(
                        card: card,
                        isShowing: $showCardDetail,
                        forceOrientationUpdate: $forceOrientationUpdate,
                        onCardUpdated: { updatedCard in
                            // Refresh cards after update
                            loadAllCards()
                        }
                    )
                }
            }
            .navigationTitle("GARAGE")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        cardsPerRow = cardsPerRow == 1 ? 2 : 1
                    }) {
                        Image(systemName: cardsPerRow == 1 ? "square.grid.2x2" : "rectangle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .onAppear {
                loadAllCards()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CardSaved"))) { _ in
                print("📬 Garage received card saved notification")
                loadAllCards()
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(
                    isPresented: $showCamera,
                    onCardSaved: { card in
                        showCamera = false
                        loadAllCards()
                    }
                )
            }
            .confirmationDialog("Card Options", isPresented: $showActionSheet, presenting: actionSheetCard) { card in
                Button("View Full Screen") {
                    selectedCard = card
                    withAnimation {
                        showCardDetail = true
                    }
                }
                
                // Customize only for vehicle cards
                if case .vehicle = card {
                    Button("Customize") {
                        selectedCard = card
                        showCustomize = true
                    }
                }
                
                Button("Quick Sell - 250 coins") {
                    quickSellCard(card)
                }
                
                Button("Cancel", role: .cancel) {}
            } message: { card in
                Text(card.displayTitle)
            }
            .fullScreenCover(isPresented: $showCustomize) {
                if let card = selectedCard, case .vehicle(let vehicleCard) = card {
                    CustomizeCardView(card: vehicleCard, savedCards: .constant([]))
                        .onDisappear {
                            loadAllCards() // Reload to show updates
                        }
                }
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAllCards() {
        var cards: [AnyCard] = []
        
        // Load vehicle cards
        let vehicleCards = CardStorage.loadCards()
        cards.append(contentsOf: vehicleCards.map { AnyCard.vehicle($0) })
        
        // Load driver cards
        let driverCards = CardStorage.loadDriverCards()
        cards.append(contentsOf: driverCards.map { AnyCard.driver($0) })
        
        // Load location cards
        let locationCards = CardStorage.loadLocationCards()
        cards.append(contentsOf: locationCards.map { AnyCard.location($0) })
        
        // Sort by date (newest first)
        allCards = cards.sorted { card1, card2 in
            card1.capturedDate > card2.capturedDate
        }
        
        print("📦 Loaded \(vehicleCards.count) vehicles, \(driverCards.count) drivers, \(locationCards.count) locations")
    }
    
    private func quickSellCard(_ card: AnyCard) {
        // Award 250 coins
        UserService.shared.addCoins(250)
        
        // Remove card from storage based on type
        switch card {
        case .vehicle(let vehicleCard):
            var cards = CardStorage.loadCards()
            cards.removeAll { $0.id == vehicleCard.id }
            CardStorage.saveCards(cards)
        case .driver(let driverCard):
            var cards = CardStorage.loadDriverCards()
            cards.removeAll { $0.id == driverCard.id }
            CardStorage.saveDriverCards(cards)
        case .location(let locationCard):
            var cards = CardStorage.loadLocationCards()
            cards.removeAll { $0.id == locationCard.id }
            CardStorage.saveLocationCards(cards)
        }
        
        // Reload cards
        loadAllCards()
        
        print("💰 Sold card for 250 coins")
    }
    
    // MARK: - Portrait Paged View
    
    private var portraitPagedView: some View {
        GeometryReader { geometry in
            let cardsPerPage = cardsPerRow == 1 ? 5 : 10 // 5 cards (5x1) or 10 cards (5x2)
            let totalPages = Int(ceil(Double(allCards.count) / Double(cardsPerPage)))
            
            TabView(selection: $currentPage) {
                ForEach(0..<max(1, totalPages), id: \.self) { pageIndex in
                    let startIndex = pageIndex * cardsPerPage
                    let endIndex = min(startIndex + cardsPerPage, allCards.count)
                    let pageCards = Array(allCards[startIndex..<endIndex])
                    
                    VStack {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: cardsPerRow), spacing: 15) {
                            ForEach(pageCards) { card in
                                UnifiedCardView(card: card, isLargeSize: cardsPerRow == 1)
                                    .onTapGesture {
                                        actionSheetCard = card
                                        showActionSheet = true
                                    }
                            }
                        }
                        .padding()
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                    .padding(.bottom, 50)
                    .tag(pageIndex)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Landscape Scroll View
    
    private var landscapeScrollView: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                ForEach(allCards) { card in
                    UnifiedCardView(card: card, isLargeSize: false)
                        .frame(width: 340)
                        .onTapGesture {
                            actionSheetCard = card
                            showActionSheet = true
                        }
                }
            }
            .padding()
            .padding(.top, 80)
            .padding(.trailing, 100)
        }
    }
}

// MARK: - Unified Card Detail View

struct UnifiedCardDetailView: View {
    let card: AnyCard
    @Binding var isShowing: Bool
    @Binding var forceOrientationUpdate: Bool
    let onCardUpdated: (AnyCard) -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0
    @State private var isFetchingSpecs = false
    
    var body: some View {
        GeometryReader { geometry in
            let isDeviceLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // Dimmed background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isShowing = false
                        }
                    }
                
                // Card container
                Group {
                    if isDeviceLandscape {
                        cardContent(geometry: geometry, rotated: false)
                    } else {
                        VStack {
                            Spacer()
                            cardContent(geometry: geometry, rotated: true)
                                .rotationEffect(.degrees(90))
                            Spacer()
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                
                // X button
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(20)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
        }
        .transition(.opacity)
    }
    
    private func cardContent(geometry: GeometryProxy, rotated: Bool) -> some View {
        let cardWidth: CGFloat = rotated ? geometry.size.height * 0.8 : geometry.size.width * 0.8
        let cardHeight: CGFloat = cardWidth / 16 * 9
        
        return VStack {
            if let image = card.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: cardWidth, height: cardHeight)
                    .cornerRadius(15)
                    .shadow(radius: 10)
            }
        }
    }
}

// MARK: - Unified Card View

struct UnifiedCardView: View {
    let card: AnyCard
    let isLargeSize: Bool
    
    var body: some View {
        ZStack {
            // Custom frame/border (only for vehicle cards)
            if let frameName = card.customFrame, frameName != "None" {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(frameName == "White" ? Color.white : Color.black, lineWidth: isLargeSize ? 6 : 3)
                    .frame(width: isLargeSize ? 360 : 175, height: isLargeSize ? 202.5 : 98.4)
            }
            
            // Card image
            if let image = card.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: isLargeSize ? 348 : 169, height: isLargeSize ? 195.75 : 92.4)
                    .clipped()
            }
            
            // Card overlay with title and type badge
            VStack {
                // Type badge in top-left
                HStack {
                    Text(card.cardType)
                        .font(.system(size: isLargeSize ? 10 : 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, isLargeSize ? 8 : 6)
                        .padding(.vertical, isLargeSize ? 4 : 3)
                        .background(typeColor.opacity(0.9))
                        .cornerRadius(isLargeSize ? 6 : 4)
                    Spacer()
                }
                .padding(isLargeSize ? 8 : 6)
                
                Spacer()
                
                // Title and subtitle at bottom
                VStack(spacing: 2) {
                    Text(card.displayTitle)
                        .font(isLargeSize ? .headline : .caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    if let subtitle = card.displaySubtitle {
                        Text(subtitle)
                            .font(isLargeSize ? .caption : .caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(isLargeSize ? 10 : 6)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.6))
            }
            .frame(width: isLargeSize ? 348 : 169, height: isLargeSize ? 195.75 : 92.4)
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var typeColor: Color {
        switch card.cardType {
        case "Vehicle": return .blue
        case "Driver": return .purple
        case "Location": return .green
        default: return .gray
        }
    }
}

// Keep old SavedCardView for backward compatibility
struct SavedCardView: View {
    let card: SavedCard
    let isLargeSize: Bool
    
    var body: some View {
        UnifiedCardView(card: .vehicle(card), isLargeSize: isLargeSize)
    }
}

#Preview {
    GarageView()
}
