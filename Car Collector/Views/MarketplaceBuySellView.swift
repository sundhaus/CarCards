//
//  MarketplaceView.swift
//  CarCardCollector
//
//  Marketplace for trading/viewing cards - Firebase powered with split Buy/Sell filters
//

import SwiftUI

struct MarketplaceBuySellView: View {
    var isLandscape: Bool = false
    var savedCards: [SavedCard]
    var onCardListed: ((SavedCard) -> Void)? = nil
    @State private var selectedMarketTab = 0
    
    // Buy tab filters (for marketplace listings)
    @State private var buyFilterMake = "Any"
    @State private var buyFilterModel = "Any"
    @State private var buyFilterYear = "Any"
    @State private var buyMinPrice = ""
    @State private var buyMaxPrice = ""
    
    // Sell tab filters (for your garage cards)
    @State private var sellFilterMake = "Any"
    @State private var sellFilterModel = "Any"
    @State private var sellFilterYear = "Any"
    
    @State private var selectedCard: SavedCard?
    @State private var comparePriceCard: SavedCard?  // For Compare Price navigation
    
    // Firebase MarketplaceService for real-time listings
    @ObservedObject private var marketplaceService = MarketplaceService.shared
    
    // MARK: - Buy Tab Filters (Marketplace Listings)
    
    private var buyAvailableMakes: [String] {
        let makes = Set(marketplaceService.activeListings.map { $0.make })
        return ["Any"] + makes.sorted()
    }
    
    private var buyAvailableModels: [String] {
        if buyFilterMake == "Any" {
            let models = Set(marketplaceService.activeListings.map { $0.model })
            return ["Any"] + models.sorted()
        } else {
            let models = Set(marketplaceService.activeListings.filter { $0.make == buyFilterMake }.map { $0.model })
            return ["Any"] + models.sorted()
        }
    }
    
    private var buyAvailableYears: [String] {
        var filtered = marketplaceService.activeListings
        if buyFilterMake != "Any" {
            filtered = filtered.filter { $0.make == buyFilterMake }
        }
        if buyFilterModel != "Any" {
            filtered = filtered.filter { $0.model == buyFilterModel }
        }
        let years = Set(filtered.map { $0.year })
        return ["Any"] + years.sorted()
    }
    
    private var filteredListings: [CloudListing] {
        marketplaceService.activeListings.filter { listing in
            if buyFilterMake != "Any" && listing.make != buyFilterMake { return false }
            if buyFilterModel != "Any" && listing.model != buyFilterModel { return false }
            if buyFilterYear != "Any" && listing.year != buyFilterYear { return false }
            if let min = Double(buyMinPrice), listing.buyNowPrice < min { return false }
            if let max = Double(buyMaxPrice), listing.buyNowPrice > max { return false }
            return true
        }
    }
    
    // MARK: - Sell Tab Filters (Your Garage Cards)
    
    private var sellAvailableMakes: [String] {
        let makes = Set(savedCards.map { $0.make })
        return ["Any"] + makes.sorted()
    }
    
    private var sellAvailableModels: [String] {
        if sellFilterMake == "Any" {
            let models = Set(savedCards.map { $0.model })
            return ["Any"] + models.sorted()
        } else {
            let models = Set(savedCards.filter { $0.make == sellFilterMake }.map { $0.model })
            return ["Any"] + models.sorted()
        }
    }
    
    private var sellAvailableYears: [String] {
        var filtered = savedCards
        if sellFilterMake != "Any" {
            filtered = filtered.filter { $0.make == sellFilterMake }
        }
        if sellFilterModel != "Any" {
            filtered = filtered.filter { $0.model == sellFilterModel }
        }
        let years = Set(filtered.map { $0.year })
        return ["Any"] + years.sorted()
    }
    
    private var filteredCards: [SavedCard] {
        savedCards.filter { card in
            if sellFilterMake != "Any" && card.make != sellFilterMake { return false }
            if sellFilterModel != "Any" && card.model != sellFilterModel { return false }
            if sellFilterYear != "Any" && card.year != sellFilterYear { return false }
            return true
        }
    }
    
    var body: some View {
        ZStack {
            // Dark blue background
            Color.appBackgroundSolid
                .ignoresSafeArea(edges: .all)
            
            VStack(spacing: 0) {
                // File folder-style tabs
                ZStack(alignment: .bottom) {
                    Color.clear
                        .frame(height: 60)
                    
                    HStack(spacing: 0) {
                        // Buy Tab
                        Button(action: {
                            selectedMarketTab = 0  // Instant switch, no animation
                        }) {
                            Text("Buy")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(selectedMarketTab == 0 ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    GeometryReader { geo in
                                        VStack(spacing: 0) {
                                            if selectedMarketTab == 0 {
                                                UnevenRoundedRectangle(
                                                    topLeadingRadius: 12,
                                                    topTrailingRadius: 12
                                                )
                                                .fill(.white)
                                            } else {
                                                UnevenRoundedRectangle(
                                                    topLeadingRadius: 12,
                                                    topTrailingRadius: 12
                                                )
                                                .fill(Color(.systemGray5))
                                            }
                                        }
                                    }
                                )
                        }
                        .overlay(alignment: .trailing) {
                            if selectedMarketTab != 0 {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 1)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // Sell Tab
                        Button(action: {
                            selectedMarketTab = 1  // Instant switch, no animation
                        }) {
                            Text("Sell")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(selectedMarketTab == 1 ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    GeometryReader { geo in
                                        VStack(spacing: 0) {
                                            if selectedMarketTab == 1 {
                                                UnevenRoundedRectangle(
                                                    topLeadingRadius: 12,
                                                    topTrailingRadius: 12
                                                )
                                                .fill(.white)
                                            } else {
                                                UnevenRoundedRectangle(
                                                    topLeadingRadius: 12,
                                                    topTrailingRadius: 12
                                                )
                                                .fill(Color(.systemGray5))
                                            }
                                        }
                                    }
                                )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Content area - white background extending to bottom
                ZStack(alignment: .top) {
                    Color.white
                        .ignoresSafeArea(edges: .bottom)
                    
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 16)
                        
                        // Filter Panel - Conditional based on selected tab
                        if selectedMarketTab == 0 {
                            buyFiltersView
                        } else {
                            sellFiltersView
                        }
                        
                        // Tab Content - Direct switching, no TabView
                        if selectedMarketTab == 0 {
                            // Buy Tab
                            BuyView(
                                activeListings: filteredListings,
                                hasUnfilteredListings: !marketplaceService.activeListings.isEmpty
                            )
                            .tag(0)
                        } else {
                            // Sell Tab
                            SellView(
                                savedCards: filteredCards,
                                filterMake: sellFilterMake,
                                filterModel: sellFilterModel,
                                filterYear: sellFilterYear,
                                onCardSelected: { card in
                                    selectedCard = card  // fullScreenCover auto-presents
                                }
                            )
                            .tag(1)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .padding(.bottom, isLandscape ? 0 : 100)
                    .padding(.trailing, isLandscape ? 100 : 0)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            marketplaceService.listenToActiveListings()
            print("📊 Listening to Firebase marketplace listings")
        }
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailsView(
                card: card,
                onDismiss: {
                    selectedCard = nil
                },
                onListed: {
                    onCardListed?(card)
                    selectedCard = nil
                    print("✅ Listing created, marketplace will auto-update")
                },
                onComparePrice: {
                    // Save card for filter setting
                    let cardToCompare = card
                    
                    // Close card details
                    selectedCard = nil
                    
                    // Small delay to ensure smooth transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Switch to BUY tab and set filters
                        selectedMarketTab = 0  // Buy tab
                        buyFilterMake = cardToCompare.make
                        buyFilterModel = cardToCompare.model
                        buyFilterYear = cardToCompare.year
                        
                        print("📊 Compare Price: Showing similar \(cardToCompare.make) \(cardToCompare.model) \(cardToCompare.year) in marketplace")
                    }
                }
            )
        }
    }
    
    // MARK: - Buy Filters View
    
    private var buyFiltersView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                filterDropdown(
                    label: "Make",
                    selection: $buyFilterMake,
                    options: buyAvailableMakes,
                    disabled: false,
                    onSelect: { make in
                        buyFilterMake = make
                        buyFilterModel = "Any"
                        buyFilterYear = "Any"
                    }
                )
                
                filterDropdown(
                    label: "Model",
                    selection: $buyFilterModel,
                    options: buyAvailableModels,
                    disabled: buyFilterMake == "Any",
                    onSelect: { model in
                        buyFilterModel = model
                        buyFilterYear = "Any"
                    }
                )
            }
            
            HStack(spacing: 12) {
                filterDropdown(
                    label: "Year",
                    selection: $buyFilterYear,
                    options: buyAvailableYears,
                    disabled: buyFilterModel == "Any",
                    onSelect: { year in
                        buyFilterYear = year
                    }
                )
                
                // Price range
                VStack(alignment: .leading, spacing: 4) {
                    Text("Price")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("Min", text: $buyMinPrice)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        Text("-")
                            .foregroundStyle(.secondary)
                        TextField("Max", text: $buyMaxPrice)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Sell Filters View
    
    private var sellFiltersView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                filterDropdown(
                    label: "Make",
                    selection: $sellFilterMake,
                    options: sellAvailableMakes,
                    disabled: false,
                    onSelect: { make in
                        sellFilterMake = make
                        sellFilterModel = "Any"
                        sellFilterYear = "Any"
                    }
                )
                
                filterDropdown(
                    label: "Model",
                    selection: $sellFilterModel,
                    options: sellAvailableModels,
                    disabled: sellFilterMake == "Any",
                    onSelect: { model in
                        sellFilterModel = model
                        sellFilterYear = "Any"
                    }
                )
            }
            
            HStack(spacing: 12) {
                filterDropdown(
                    label: "Year",
                    selection: $sellFilterYear,
                    options: sellAvailableYears,
                    disabled: sellFilterModel == "Any",
                    onSelect: { year in
                        sellFilterYear = year
                    }
                )
                
                Spacer()  // No price filter for Sell tab
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Reusable Filter Dropdown
    
    private func filterDropdown(
        label: String,
        selection: Binding<String>,
        options: [String],
        disabled: Bool,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Menu {
                Button("Any") { onSelect("Any") }
                Divider()
                ForEach(options.filter { $0 != "Any" }, id: \.self) { option in
                    Button(option) { onSelect(option) }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue)
                        .foregroundStyle(selection.wrappedValue == "Any" ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .disabled(disabled)
        }
    }
}

// MARK: - Buy Tab Content

struct BuyView: View {
    let activeListings: [CloudListing]
    let hasUnfilteredListings: Bool
    
    var body: some View {
        ScrollView {
            if activeListings.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: hasUnfilteredListings ? "line.3.horizontal.decrease.circle" : "cart")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text(hasUnfilteredListings ? "No listings match filters" : "No listings available")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    if hasUnfilteredListings {
                        Text("Try adjusting your filters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Be the first to list a card!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(minHeight: 300)
            } else {
                VStack(spacing: 12) {
                    ForEach(activeListings) { listing in
                        ListingCardRow(listing: listing)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Sell Tab Content

struct SellView: View {
    let savedCards: [SavedCard]
    let filterMake: String
    let filterModel: String
    let filterYear: String
    let onCardSelected: (SavedCard) -> Void
    
    var body: some View {
        ScrollView {
            if savedCards.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("No cards in your garage")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Text("Capture some cars to list them!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(minHeight: 300)
            } else {
                VStack(spacing: 12) {
                    ForEach(savedCards) { card in
                        GarageCardRow(card: card)
                            .onTapGesture {
                                onCardSelected(card)
                            }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Listing Card Row (Marketplace)

struct ListingCardRow: View {
    let listing: CloudListing
    
    var body: some View {
        VStack(spacing: 8) {
            // FIFA-style card
            MarketplaceFIFACard(listing: listing)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Bid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(Int(listing.currentBid))")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Buy Now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(Int(listing.buyNowPrice))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.white)
        .cornerRadius(12)
    }
}

// MARK: - Garage Card Row (Your Cards)

struct GarageCardRow: View {
    let card: SavedCard
    
    var body: some View {
        VStack(spacing: 8) {
            // FIFA-style card
            SellTabCardView(card: card)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(card.make) \(card.model)")
                        .font(.headline)
                    Text(card.year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.white)
        .cornerRadius(12)
    }
}

// MARK: - Sell Tab Card View

struct SellTabCardView: View {
    let card: SavedCard
    
    private let cardHeight: CGFloat = 202.5
    private var cardWidth: CGFloat { cardHeight * (16/9) }
    
    var body: some View {
        ZStack {
            // Card background with gradient
            RoundedRectangle(cornerRadius: cardHeight * 0.06)
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
            Group {
                if let image = card.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .overlay(
                            Image(systemName: "car.fill")
                                .font(.system(size: cardHeight * 0.3))
                                .foregroundStyle(.gray.opacity(0.4))
                        )
                }
            }
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
                    HStack(spacing: 6) {
                        let config = CardBorderConfig.forFrame(card.customFrame)
                        Text(card.make.uppercased())
                            .font(.system(size: cardHeight * 0.08, weight: .semibold))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        
                        Text(card.model)
                            .font(.system(size: cardHeight * 0.08, weight: .bold))
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
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.06))
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
    
    // Calculate card level based on category rarity
    private var cardLevel: Int {
        guard let category = card.specs?.category else { return 1 }
        
        switch category {
        case .hypercar: return 10
        case .supercar: return 9
        case .track: return 8
        case .sportsCar: return 7
        case .muscle: return 6
        case .rally: return 5
        case .electric, .hybrid: return 5
        case .luxury: return 4
        case .classic, .concept: return 6
        case .coupe, .convertible: return 4
        case .offRoad, .suv, .truck: return 3
        case .sedan, .wagon, .hatchback, .van: return 2
        }
    }
}


// MARK: - Marketplace FIFA Card

struct MarketplaceFIFACard: View {
    let listing: CloudListing
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    
    private let cardHeight: CGFloat = 202.5
    private var cardWidth: CGFloat { cardHeight * (16/9) }
    
    var body: some View {
        ZStack {
            // Card background with gradient
            RoundedRectangle(cornerRadius: cardHeight * 0.06)
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
                                .font(.system(size: cardHeight * 0.3))
                                .foregroundStyle(.gray.opacity(0.4))
                        )
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            
            // PNG border overlay based on customFrame
            if let borderImageName = CardBorderConfig.forFrame(listing.customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .allowsHitTesting(false)
            }
            
            // Car name overlay - top left, horizontal
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        let config = CardBorderConfig.forFrame(listing.customFrame)
                        Text(listing.make.uppercased())
                            .font(.system(size: cardHeight * 0.08, weight: .semibold))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        
                        Text(listing.model)
                            .font(.system(size: cardHeight * 0.08, weight: .bold))
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
            
            // "FOR SALE" badge - bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text("FOR")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.black.opacity(0.6))
                        Text("SALE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.yellow)
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    )
                    .padding(.bottom, cardHeight * 0.08)
                    .padding(.trailing, cardHeight * 0.08)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.06))
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard !isLoadingImage, cardImage == nil else { return }
        
        isLoadingImage = true
        
        guard let url = URL(string: listing.imageURL) else {
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
    MarketplaceBuySellView(savedCards: [])
}
