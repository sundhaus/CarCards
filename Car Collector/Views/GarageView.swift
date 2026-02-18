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
                
                VStack(spacing: 0) {
                    // Custom header with title and toggle on same line
                    HStack {
                        Text("GARAGE")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // Migration button (backfill categories to friend_activities)
                        Button(action: {
                            Task {
                                await runMigration()
                            }
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title3)
                                .foregroundStyle(.purple)
                        }
                        
                        // Refresh specs button (backfill categories)
                        Button(action: {
                            Task {
                                await refreshAllSpecs()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .foregroundStyle(.green)
                        }
                        
                        Button(action: {
                            cardsPerRow = cardsPerRow == 1 ? 2 : 1
                        }) {
                            Image(systemName: cardsPerRow == 1 ? "square.grid.2x2" : "rectangle")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, isLandscape ? 20 : 8)
                    .padding(.bottom, 8)
                    .background(.ultraThinMaterial)
                    
                    // Content
                    if allCards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("Your collection will appear here")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxHeight: .infinity)
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
    
    // Refresh specs and categories for all vehicle cards
    private func refreshAllSpecs() async {
        print("🔄 Starting bulk specs refresh for all cards")
        
        var vehicleCards = CardStorage.loadCards()
        let vehicleService = VehicleIdentificationService()
        var updatedCount = 0
        var categoryUpdates = 0
        
        for (index, card) in vehicleCards.enumerated() {
            print("\n📋 Card \(index + 1)/\(vehicleCards.count): \(card.make) \(card.model)")
            print("   Has firebaseId: \(card.firebaseId != nil ? "✅" : "❌")")
            print("   Has specs: \(card.specs != nil ? "✅" : "❌")")
            print("   Has category: \(card.specs?.category != nil ? "✅ \(card.specs!.category!.rawValue)" : "❌")")
            
            // Fetch specs if missing or missing category
            let needsSpecsFetch = card.specs == nil || card.specs?.category == nil
            
            if needsSpecsFetch {
                print("📥 Fetching specs for \(card.make) \(card.model)")
                
                do {
                    let specs = try await vehicleService.fetchSpecs(
                        make: card.make,
                        model: card.model,
                        year: card.year
                    )
                    
                    print("   ✅ Got specs with category: \(specs.category?.rawValue ?? "NONE!")")
                    
                    // Update card with specs
                    let updatedCard = SavedCard(
                        id: card.id,
                        image: card.image ?? UIImage(),
                        make: card.make,
                        model: card.model,
                        color: card.color,
                        year: card.year,
                        specs: specs,
                        capturedBy: card.capturedBy,
                        capturedLocation: card.capturedLocation,
                        previousOwners: card.previousOwners,
                        customFrame: card.customFrame,
                        firebaseId: card.firebaseId
                    )
                    
                    vehicleCards[index] = updatedCard
                    updatedCount += 1
                    
                    // Update category in friend_activities if we have both firebaseId and category
                    if let firebaseId = card.firebaseId {
                        if let category = specs.category {
                            print("   📤 Updating friend_activities with category: \(category.rawValue)")
                            do {
                                try await FriendsService.shared.updateActivityCategory(
                                    cardId: firebaseId,
                                    category: category
                                )
                                categoryUpdates += 1
                                print("   ✅ Updated category in friend_activities")
                            } catch {
                                print("   ❌ Failed to update friend_activities: \(error)")
                            }
                        } else {
                            print("   ⚠️ Specs returned but no category!")
                        }
                    } else {
                        print("   ⚠️ Card has no firebaseId - can't update friend_activities")
                        print("   💡 This card was saved before cloud sync was enabled")
                    }
                    
                    // Small delay to avoid rate limiting
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                } catch {
                    print("   ❌ Failed to fetch specs: \(error)")
                }
            } else {
                print("   ⏭️ Skipping - already has specs with category")
                
                // Even if we skip fetching, check if friend_activities needs updating
                if let firebaseId = card.firebaseId, let category = card.specs?.category {
                    print("   🔍 Checking if friend_activities has category...")
                    do {
                        try await FriendsService.shared.updateActivityCategory(
                            cardId: firebaseId,
                            category: category
                        )
                        categoryUpdates += 1
                        print("   ✅ Ensured category in friend_activities")
                    } catch {
                        print("   ⚠️ Friend_activities update skipped or failed: \(error)")
                    }
                }
            }
        }
        
        // Save all updated cards
        CardStorage.saveCards(vehicleCards)
        
        // Reload garage
        await MainActor.run {
            loadAllCards()
        }
        
        print("\n✅ Bulk refresh complete!")
        print("   📊 Specs fetched: \(updatedCount) cards")
        print("   🔥 friend_activities updated: \(categoryUpdates) cards")
    }
    
    // Run migration to backfill ALL friend_activities with categories from vehicleSpecs
    private func runMigration() async {
        print("\n🚀 MIGRATION: Starting full friend_activities category backfill")
        
        let migrationService = CategoryMigrationService()
        await migrationService.migrateMissingCategories()
        
        print("✅ MIGRATION: Complete! Check Explore page now.")
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
                        .padding(.top, 8) // Reduced padding since header is compact now
                        
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
            .padding(.top, 60) // Adjusted for compact header
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
    @State private var cardSpecs: VehicleSpecs?
    
    // Helper to check if specs are complete
    private func specsAreComplete(_ specs: VehicleSpecs?) -> Bool {
        guard let specs = specs else { return false }
        return specs.horsepower != "N/A" && specs.torque != "N/A"
    }
    
    // Fetch specs if vehicle card doesn't have them, then auto-flip
    private func fetchSpecsIfNeeded() async {
        // Only fetch for vehicle cards
        guard case .vehicle(let vehicleCard) = card else { return }
        
        // Don't fetch if we already have specs
        guard vehicleCard.specs == nil else {
            print("✅ Specs already exist for \(vehicleCard.make) \(vehicleCard.model)")
            cardSpecs = vehicleCard.specs
            return
        }
        
        await MainActor.run {
            isFetchingSpecs = true
        }
        
        print("🔍 Fetching specs for \(vehicleCard.make) \(vehicleCard.model) \(vehicleCard.year)")
        
        do {
            // Use VehicleIDService - it handles Firestore caching
            let vehicleService = VehicleIdentificationService()
            let specs = try await vehicleService.fetchSpecs(
                make: vehicleCard.make,
                model: vehicleCard.model,
                year: vehicleCard.year
            )
            
            // Create updated card with specs
            let updatedVehicleCard = SavedCard(
                id: vehicleCard.id,
                image: vehicleCard.image ?? UIImage(),
                make: vehicleCard.make,
                model: vehicleCard.model,
                color: vehicleCard.color,
                year: vehicleCard.year,
                specs: specs,
                capturedBy: vehicleCard.capturedBy,
                capturedLocation: vehicleCard.capturedLocation,
                previousOwners: vehicleCard.previousOwners,
                customFrame: vehicleCard.customFrame,
                firebaseId: vehicleCard.firebaseId
            )
            
            // Save updated card to storage
            var allCards = CardStorage.loadCards()
            if let index = allCards.firstIndex(where: { $0.id == vehicleCard.id }) {
                allCards[index] = updatedVehicleCard
                CardStorage.saveCards(allCards)
                print("💾 Saved specs to card storage")
            }
            
            // Update category in friend_activities if card has firebaseId and specs have category
            if let firebaseId = vehicleCard.firebaseId, let category = specs.category {
                print("📤 Updating category in friend_activities")
                do {
                    try await FriendsService.shared.updateActivityCategory(
                        cardId: firebaseId,
                        category: category
                    )
                    print("✅ Updated category in friend_activities")
                } catch {
                    print("⚠️ Failed to update category in friend_activities: \(error)")
                }
            }
            
            await MainActor.run {
                cardSpecs = specs
                isFetchingSpecs = false
                // Notify parent to reload
                onCardUpdated(.vehicle(updatedVehicleCard))
                
                // Auto-flip to show the specs
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    flipDegrees += 180
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isFlipped.toggle()
                    }
                }
            }
            
            print("✅ Successfully fetched and saved specs, auto-flipping card")
            
        } catch {
            print("❌ Failed to fetch specs: \(error)")
            await MainActor.run {
                isFetchingSpecs = false
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isDeviceLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // Dimmed background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Don't dismiss on tap - only X button dismisses
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
                        
                        // Flip hint (only for vehicles)
                        if case .vehicle = card, !isFetchingSpecs {
                            if specsAreComplete(cardSpecs) {
                                Text("Tap card to flip")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.6))
                                    .cornerRadius(20)
                                    .padding(.trailing, 20)
                            } else {
                                Text("Tap to load stats")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.6))
                                    .cornerRadius(20)
                                    .padding(.trailing, 20)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Loading overlay - just spinner
                if isFetchingSpecs {
                    ProgressView()
                        .scaleEffect(2.0)
                        .tint(.white)
                }
            }
        }
        .transition(.opacity)
        .onAppear {
            // Load existing specs if vehicle card has them
            if case .vehicle(let vehicleCard) = card {
                cardSpecs = vehicleCard.specs
            }
        }
    }
    
    private func cardContent(geometry: GeometryProxy, rotated: Bool) -> some View {
        let cardWidth: CGFloat = rotated ? geometry.size.height * 0.8 : geometry.size.width * 0.8
        let cardHeight: CGFloat = cardWidth / 16 * 9
        
        return ZStack {
            // Front side - FIFA-style card
            if !isFlipped {
                if case .vehicle(let vehicleCard) = card {
                    CardDetailsFrontView(card: vehicleCard)
                        .frame(width: cardWidth, height: cardHeight)
                        .rotation3DEffect(
                            .degrees(flipDegrees),
                            axis: (x: 0, y: 1, z: 0)
                        )
                } else if let image = card.image {
                    // Driver/Location cards - just show image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: cardWidth, height: cardHeight)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                        .rotation3DEffect(
                            .degrees(flipDegrees),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }
            }
            
            // Back side - stats (only for vehicles)
            if isFlipped {
                if case .vehicle(let vehicleCard) = card, let specs = cardSpecs {
                    CardBackView(
                        make: vehicleCard.make,
                        model: vehicleCard.model,
                        year: vehicleCard.year,
                        specs: specs
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .rotation3DEffect(
                        .degrees(flipDegrees),
                        axis: (x: 0, y: 1, z: 0)
                    )
                }
            }
        }
        .onTapGesture {
            // Ignore taps while fetching
            guard !isFetchingSpecs else { return }
            
            // Only handle taps for vehicle cards
            guard case .vehicle = card else { return }
            
            // If specs already loaded - flip immediately
            if specsAreComplete(cardSpecs) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    flipDegrees += 180
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isFlipped.toggle()
                    }
                }
            } else {
                // No specs yet - fetch them (will auto-flip when done)
                Task {
                    await fetchSpecsIfNeeded()
                }
            }
        }
    }
}

// Card back view with specs
struct CardBackView: View {
    let make: String
    let model: String
    let year: String
    let specs: VehicleSpecs
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Text("\(make) \(model)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(year)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Specs grid
                VStack(spacing: 12) {
                    // Row 1: Power stats
                    HStack(spacing: 20) {
                        statItem(
                            label: "HP",
                            value: specs.horsepower,
                            highlight: specs.horsepower != "N/A"
                        )
                        statItem(
                            label: "TORQUE",
                            value: specs.torque,
                            highlight: specs.torque != "N/A"
                        )
                    }
                    
                    // Row 2: Performance stats
                    HStack(spacing: 20) {
                        statItem(
                            label: "0-60",
                            value: specs.zeroToSixty,
                            highlight: specs.zeroToSixty != "N/A"
                        )
                        statItem(
                            label: "TOP SPEED",
                            value: specs.topSpeed,
                            highlight: specs.topSpeed != "N/A"
                        )
                    }
                    
                    // Row 3: Details
                    HStack(spacing: 20) {
                        statItem(
                            label: "ENGINE",
                            value: specs.engine,
                            highlight: specs.engine != "N/A"
                        )
                        statItem(
                            label: "DRIVE",
                            value: specs.drivetrain,
                            highlight: specs.drivetrain != "N/A"
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            
            // Black border overlay (matching front)
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(Color.black, lineWidth: 3)
        }
        .cornerRadius(15)
        .shadow(radius: 10)
        .rotation3DEffect(
            .degrees(180),
            axis: (x: 0, y: 1, z: 0)
        )
    }
    
    // Helper view for stat items
    private func statItem(label: String, value: String, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(highlight ? .white : .white.opacity(0.4))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(highlight ? Color.white.opacity(0.15) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Unified Card View

struct UnifiedCardView: View {
    let card: AnyCard
    let isLargeSize: Bool
    
    var body: some View {
        // Use FIFA-style for vehicle cards, simple for others
        if case .vehicle(let vehicleCard) = card {
            VehicleCardView(card: vehicleCard, isLargeSize: isLargeSize)
        } else {
            SimpleCardView(card: card, isLargeSize: isLargeSize)
        }
    }
}

// FIFA-style card for vehicles
struct VehicleCardView: View {
    let card: SavedCard
    let isLargeSize: Bool
    
    private var cardHeight: CGFloat { isLargeSize ? 195.75 : 100 }
    private var cardWidth: CGFloat { cardHeight * (16/9) }
    
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
                HStack(spacing: isLargeSize ? 8 : 4) {
                    // GEN badge
                    VStack(spacing: isLargeSize ? 2 : 1) {
                        Text("GEN")
                            .font(.system(size: isLargeSize ? 8 : 6, weight: .bold))
                            .foregroundStyle(.black.opacity(0.6))
                        Text("\(cardLevel)")
                            .font(.system(size: isLargeSize ? 14 : 10, weight: .black))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, isLargeSize ? 10 : 6)
                    .padding(.vertical, isLargeSize ? 4 : 3)
                    .background(
                        RoundedRectangle(cornerRadius: isLargeSize ? 6 : 4)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    )
                    
                    // Car name
                    VStack(alignment: .leading, spacing: isLargeSize ? 2 : 1) {
                        Text(card.make.uppercased())
                            .font(.system(size: isLargeSize ? 10 : 7, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.7))
                            .lineLimit(1)
                        
                        Text(card.model)
                            .font(.system(size: isLargeSize ? 13 : 9, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, isLargeSize ? 12 : 8)
                .padding(.top, isLargeSize ? 10 : 6)
                .padding(.bottom, isLargeSize ? 6 : 4)
                
                // Car image area (center)
                GeometryReader { geo in
                    Group {
                        if let image = card.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                        } else {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .overlay(
                                    Image(systemName: "car.fill")
                                        .font(.system(size: isLargeSize ? 30 : 20))
                                        .foregroundStyle(.gray.opacity(0.4))
                                )
                        }
                    }
                    .clipped()
                }
                
                // Bottom bar - Year
                HStack {
                    Spacer()
                    
                    Text(card.year)
                        .font(.system(size: isLargeSize ? 9 : 7, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.6))
                }
                .padding(.horizontal, isLargeSize ? 12 : 8)
                .padding(.vertical, isLargeSize ? 6 : 4)
                .background(Color.white.opacity(0.4))
            }
            
            // Black border overlay
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.black, lineWidth: 3)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipped()
        .shadow(color: Color.black.opacity(0.3), radius: isLargeSize ? 6 : 4, x: 0, y: 3)
    }
}

// Simple card for drivers/locations
struct SimpleCardView: View {
    let card: AnyCard
    let isLargeSize: Bool
    
    var body: some View {
        ZStack {
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
            
            // Black border overlay
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.black, lineWidth: 3)
        }
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.3), radius: isLargeSize ? 6 : 4, x: 0, y: 3)
    }
    
    private var typeColor: Color {
        switch card {
        case .driver: return .purple
        case .location: return .green
        default: return .blue
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
