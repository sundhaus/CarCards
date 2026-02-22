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
    @Environment(\.dismiss) private var dismiss
    @State private var useDoubleColumn = false
    
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
    @State private var selectedListing: CloudListing?  // For viewing/bidding on a listing
    
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
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom glass header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.pTitle3)
                            .foregroundStyle(.primary)
                    }
                    
                    Text("MARKETPLACE")
                        .font(.pTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            useDoubleColumn.toggle()
                        }
                    }) {
                        Image(systemName: useDoubleColumn ? "square.grid.2x2" : "rectangle.grid.1x2")
                            .font(.pTitle3)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 18)
                .padding(.bottom, 10)
                .glassEffect(.regular, in: .rect)
                
                // Glass segmented tabs
                HStack(spacing: 6) {
                    ForEach(["BUY", "SELL"], id: \.self) { tab in
                        let index = tab == "BUY" ? 0 : 1
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMarketTab = index
                            }
                        }) {
                            Text(tab)
                                .font(.pSubheadline)
                                .fontWeight(selectedMarketTab == index ? .semibold : .regular)
                                .foregroundStyle(selectedMarketTab == index ? .white : .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background {
                                    if selectedMarketTab == index {
                                        Capsule()
                                            .fill(.white.opacity(0.15))
                                    }
                                }
                        }
                    }
                }
                .padding(4)
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                // Filter Panel
                if selectedMarketTab == 0 {
                    buyFiltersView
                } else {
                    sellFiltersView
                }
                
                // Tab Content — ScrollView fills remaining space
                if selectedMarketTab == 0 {
                    BuyView(
                        activeListings: filteredListings,
                        hasUnfilteredListings: !marketplaceService.activeListings.isEmpty,
                        useDoubleColumn: useDoubleColumn,
                        onListingSelected: { listing in
                            selectedListing = listing
                        }
                    )
                } else {
                    SellView(
                        savedCards: filteredCards,
                        filterMake: sellFilterMake,
                        filterModel: sellFilterModel,
                        filterYear: sellFilterYear,
                        useDoubleColumn: useDoubleColumn,
                        onCardSelected: { card in
                            selectedCard = card
                        }
                    )
                }
            }
        }
        .onAppear {
            marketplaceService.listenToActiveListings()
            print("📊 Listening to Firebase marketplace listings")
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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
        .sheet(item: $selectedListing) { listing in
            ListingDetailView(listing: listing)
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
                    Text("PRICE")
                        .font(.pCaption)
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
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
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
                
                Spacer()
            }
        }
        .padding()
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
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
                .font(.pCaption)
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
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
            }
            .disabled(disabled)
        }
    }
}

// MARK: - Buy Tab Content

struct BuyView: View {
    let activeListings: [CloudListing]
    let hasUnfilteredListings: Bool
    var useDoubleColumn: Bool = false
    var onListingSelected: (CloudListing) -> Void = { _ in }
    
    private var gridColumns: [GridItem] {
        if useDoubleColumn {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        } else {
            return [GridItem(.flexible())]
        }
    }
    
    var body: some View {
        ScrollView {
            if activeListings.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: hasUnfilteredListings ? "line.3.horizontal.decrease.circle" : "cart")
                        .font(.poppins(60))
                        .foregroundStyle(.gray)
                    Text(hasUnfilteredListings ? "No listings match filters" : "No listings available")
                        .font(.pTitle2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    if hasUnfilteredListings {
                        Text("Try adjusting your filters")
                            .font(.pCaption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Be the first to list a card!")
                            .font(.pCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(minHeight: 300)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(activeListings) { listing in
                        Group {
                            if useDoubleColumn {
                                CompactListingCard(listing: listing)
                            } else {
                                ListingCardRow(listing: listing)
                            }
                        }
                        .onTapGesture {
                            onListingSelected(listing)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 80)
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
    var useDoubleColumn: Bool = false
    let onCardSelected: (SavedCard) -> Void
    
    private var gridColumns: [GridItem] {
        if useDoubleColumn {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        } else {
            return [GridItem(.flexible())]
        }
    }
    
    var body: some View {
        ScrollView {
            if savedCards.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.poppins(60))
                        .foregroundStyle(.gray)
                    Text("No cards in your garage")
                        .font(.pTitle2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Text("Capture some cars to list them!")
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(minHeight: 300)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(savedCards) { card in
                        Group {
                            if useDoubleColumn {
                                CompactGarageCard(card: card)
                            } else {
                                GarageCardRow(card: card)
                            }
                        }
                        .onTapGesture {
                            onCardSelected(card)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
        }
    }
}

// MARK: - Listing Card Row (Marketplace)

struct ListingCardRow: View {
    let listing: CloudListing
    
    private let cardHeight: CGFloat = 202.5
    private var cardWidth: CGFloat { cardHeight * (16/9) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Card on top
            MarketplaceFIFACard(listing: listing)
            
            // Price bar below, same width as card
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("CURRENT BID")
                        .font(.pCaption2)
                        .foregroundStyle(.secondary)
                    Text(listing.currentBid > 0 ? "$\(Int(listing.currentBid))" : "None")
                        .font(.pTitle3)
                        .fontWeight(.bold)
                        .foregroundStyle(listing.currentBid > 0 ? .orange : .secondary)
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 36)
                
                VStack(spacing: 4) {
                    Text("BUY NOW")
                        .font(.pCaption2)
                        .foregroundStyle(.secondary)
                    Text("$\(Int(listing.buyNowPrice))")
                        .font(.pTitle3)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
        }
        .frame(width: cardWidth)
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: cardHeight * 0.09))
    }
}

// MARK: - Garage Card Row (Your Cards)

struct GarageCardRow: View {
    let card: SavedCard
    
    private let cardHeight: CGFloat = 202.5
    private var cardWidth: CGFloat { cardHeight * (16/9) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Card on top
            SellTabCardView(card: card)
            
            // Info bar below, same width as card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(card.make.uppercased()) \(card.model.uppercased())")
                        .font(.custom("Futura-Bold", size: 17))
                    Text(card.year)
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: cardWidth)
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: cardHeight * 0.09))
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
            
            // Car image - full bleed
            Group {
                if let image = card.thumbnail ?? card.image {
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
                            .font(.custom("Futura-Light", size: cardHeight * 0.08))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        
                        Text(card.model.uppercased())
                            .font(.custom("Futura-Bold", size: cardHeight * 0.08))
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
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
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
                            .font(.custom("Futura-Light", size: cardHeight * 0.08))
                            .foregroundStyle(config.textColor)
                            .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        
                        Text(listing.model.uppercased())
                            .font(.custom("Futura-Bold", size: cardHeight * 0.08))
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
                            .font(.poppins(7))
                            .foregroundStyle(.black.opacity(0.6))
                        Text("SALE")
                            .font(.poppins(9))
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
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
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

// MARK: - Compact Listing Card (Double Column - Buy Tab)

struct CompactListingCard: View {
    let listing: CloudListing
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Card image
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.85, green: 0.85, blue: 0.88))
                
                if let image = cardImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoadingImage {
                    ProgressView().tint(.gray)
                } else {
                    Image(systemName: "car.fill")
                        .font(.poppins(24))
                        .foregroundStyle(.gray.opacity(0.4))
                }
                
                // Border overlay
                if let borderImageName = CardBorderConfig.forFrame(listing.customFrame).borderImageName {
                    Image(borderImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                
                // Name overlay
                VStack {
                    HStack {
                        let config = CardBorderConfig.forFrame(listing.customFrame)
                        HStack(spacing: 3) {
                            Text(listing.make.uppercased())
                                .font(.custom("Futura-Light", size: 9))
                                .foregroundStyle(config.textColor)
                            Text(listing.model.uppercased())
                                .font(.custom("Futura-Bold", size: 9))
                                .foregroundStyle(config.textColor)
                                .lineLimit(1)
                        }
                        .padding(.top, 8)
                        .padding(.leading, 8)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Info bar — split bid/buy
            HStack(spacing: 0) {
                VStack(spacing: 1) {
                    Text("BID")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(listing.currentBid > 0 ? "$\(Int(listing.currentBid))" : "None")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(listing.currentBid > 0 ? .orange : .secondary)
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 22)
                
                VStack(spacing: 1) {
                    Text("BUY")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text("$\(Int(listing.buyNowPrice))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)
        }
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .onAppear { loadImage() }
    }
    
    private func loadImage() {
        guard !isLoadingImage, cardImage == nil, let url = URL(string: listing.imageURL) else { return }
        isLoadingImage = true
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { isLoadingImage = false }
                return
            }
            DispatchQueue.main.async {
                cardImage = image
                isLoadingImage = false
            }
        }.resume()
    }
}

// MARK: - Compact Garage Card (Double Column - Sell Tab)

struct CompactGarageCard: View {
    let card: SavedCard
    
    var body: some View {
        VStack(spacing: 0) {
            // Card image
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.85, green: 0.85, blue: 0.88))
                
                if let image = card.thumbnail ?? card.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "car.fill")
                        .font(.poppins(24))
                        .foregroundStyle(.gray.opacity(0.4))
                }
                
                // Border overlay
                if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                    Image(borderImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                
                // Name overlay
                VStack {
                    HStack {
                        let config = CardBorderConfig.forFrame(card.customFrame)
                        HStack(spacing: 3) {
                            Text(card.make.uppercased())
                                .font(.custom("Futura-Light", size: 9))
                                .foregroundStyle(config.textColor)
                            Text(card.model.uppercased())
                                .font(.custom("Futura-Bold", size: 9))
                                .foregroundStyle(config.textColor)
                                .lineLimit(1)
                        }
                        .padding(.top, 8)
                        .padding(.leading, 8)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Info bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(card.make) \(card.model)")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(card.year)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    MarketplaceBuySellView(savedCards: [])
}
