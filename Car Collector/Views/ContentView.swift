//
//  ContentView.swift
//  CarCardCollector
//
//  Main view with bottom navigation hub
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1 // Start on Home
    @State private var showCamera = false
    @State private var savedCards: [SavedCard] = []
    @State private var showCardDetail = false
    @State private var selectedCard: SavedCard?
    @State private var forceOrientationUpdate = false
    @StateObject private var levelSystem = LevelSystem()
    @State private var showProfile = false
    
    // Track which tabs have been visited (for lazy loading)
    @State private var visitedTabs: Set<Int> = [1] // Home is pre-loaded
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Shop Tab - lazy
            Tab("Shop", systemImage: "bag", value: 0) {
                if visitedTabs.contains(0) {
                    ShopView(isLandscape: false)
                } else {
                    Color.clear
                }
            }
            
            // Home Tab - always loaded (start tab)
            Tab("Home", systemImage: "house", value: 1) {
                HomeView(
                    isLandscape: false,
                    showProfile: $showProfile,
                    levelSystem: levelSystem,
                    totalCards: savedCards.count
                )
                .padding(.top, 50)
            }
            
            // Capture Tab - pre-loaded for fast access
            Tab("Capture", systemImage: "camera.fill", value: 2) {
                if visitedTabs.contains(2) {
                    CaptureLandingView(
                        isLandscape: false,
                        levelSystem: levelSystem,
                        selectedTab: $selectedTab,
                        onCardSaved: { card in
                            savedCards.append(card)
                            CardStorage.saveCards(savedCards)
                            
                            if let image = card.image {
                                Task {
                                    do {
                                        let cloudCard = try await CardService.shared.saveCard(
                                            image: image,
                                            make: card.make,
                                            model: card.model,
                                            color: card.color,
                                            year: card.year
                                        )
                                        
                                        if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                                            var updatedCard = savedCards[index]
                                            updatedCard.firebaseId = cloudCard.id
                                            savedCards[index] = updatedCard
                                            CardStorage.saveCards(savedCards)
                                            print("🔗 Linked local card to Firebase ID: \(cloudCard.id)")
                                        }
                                    } catch {
                                        print("❌ Cloud save failed: \(error)")
                                    }
                                }
                            }
                            
                            levelSystem.addXP(10)
                        }
                    )
                    .padding(.top, 50)
                } else {
                    Color.clear
                }
            }
            
            // Marketplace Tab - lazy
            Tab("Market", systemImage: "chart.line.uptrend.xyaxis", value: 3) {
                if visitedTabs.contains(3) {
                    MarketplaceLandingView(
                        isLandscape: false,
                        savedCards: savedCards,
                        onCardListed: { card in
                            if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                                savedCards.remove(at: index)
                                CardStorage.saveCards(savedCards)
                            }
                        }
                    )
                    .padding(.top, 50)
                } else {
                    Color.clear
                }
            }
            
            // Garage Tab - lazy
            Tab("Garage", systemImage: "wrench.and.screwdriver", value: 4) {
                if visitedTabs.contains(4) {
                    GarageView()
                        .padding(.top, 58)
                } else {
                    Color.clear
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay {
            // Level Header
            if !showCamera && !showCardDetail {
                VStack {
                    LevelHeader(
                        levelSystem: levelSystem,
                        isLandscape: false,
                        totalCards: savedCards.count,
                        showProfile: $showProfile
                    )
                    Spacer()
                }
            }
        }
        .overlay {
            // Card detail overlay
            if showCardDetail, let card = selectedCard {
                CardDetailView(
                    card: card,
                    isShowing: $showCardDetail,
                    forceOrientationUpdate: $forceOrientationUpdate,
                    onSpecsUpdated: { updatedCard in
                        if let index = savedCards.firstIndex(where: { $0.id == updatedCard.id }) {
                            savedCards[index] = updatedCard
                            CardStorage.saveCards(savedCards)
                        }
                    }
                )
            }
        }
        .overlay {
            // Profile popup
            if showProfile {
                ProfileView(
                    isShowing: $showProfile,
                    levelSystem: levelSystem,
                    totalCards: savedCards.count
                )
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(
                isPresented: $showCamera,
                onCardSaved: { card in
                    savedCards.append(card)
                    CardStorage.saveCards(savedCards)
                    
                    if let image = card.image {
                        Task {
                            do {
                                let cloudCard = try await CardService.shared.saveCard(
                                    image: image,
                                    make: card.make,
                                    model: card.model,
                                    color: card.color,
                                    year: card.year
                                )
                                
                                if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                                    var updatedCard = savedCards[index]
                                    updatedCard.firebaseId = cloudCard.id
                                    savedCards[index] = updatedCard
                                    CardStorage.saveCards(savedCards)
                                }
                            } catch {
                                print("❌ Cloud save failed: \(error)")
                            }
                        }
                    }
                    
                    levelSystem.addXP(10)
                    showCamera = false
                    OrientationManager.lockToPortrait()
                }
            )
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            OrientationManager.lockToPortrait()
            // Mark tab as visited for lazy loading
            if !visitedTabs.contains(newValue) {
                visitedTabs.insert(newValue)
            }
        }
        .onAppear {
            OrientationManager.lockToPortrait()
            // Defer card loading off the init path
            DispatchQueue.main.async {
                savedCards = CardStorage.loadCards()
            }
            // Pre-warm Capture tab after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                visitedTabs.insert(2)
            }
        }
    }
    
    // Indicator offset functions removed - native Liquid Glass handles tab bar
}

// Wrapper to pass savedCards to GarageView
struct GarageViewWrapper: View {
    @Binding var savedCards: [SavedCard]
    let isLandscape: Bool
    @Binding var showCardDetail: Bool
    @Binding var selectedCard: SavedCard?
    @Binding var forceOrientationUpdate: Bool
    
    var body: some View {
        GarageViewContent(
            savedCards: $savedCards,
            isLandscape: isLandscape,
            showCardDetail: $showCardDetail,
            selectedCard: $selectedCard
        )
        .id(forceOrientationUpdate) // Force view refresh when this changes
        .onAppear {
            // Lock to portrait for garage
            OrientationManager.lockOrientation(.portrait)
        }
        .onDisappear {
            OrientationManager.lockOrientation(.portrait)
        }
    }
}

// Modified GarageView content
struct GarageViewContent: View {
    @Binding var savedCards: [SavedCard]
    let isLandscape: Bool
    @Binding var showCardDetail: Bool
    @Binding var selectedCard: SavedCard?
    @State private var cardsPerRow = 2
    @State private var currentPage = 0
    @State private var showActionSheet = false
    @State private var actionSheetCard: SavedCard?
    @State private var showCustomize = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark blue background
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                VStack {
                    if savedCards.isEmpty {
                        Text("Your collection will appear here")
                            .foregroundStyle(.secondary)
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
                    .ignoresSafeArea() // Extend to all edges including top/bottom
                }
            }
        }
        .confirmationDialog("Card Options", isPresented: $showActionSheet, presenting: actionSheetCard) { card in
            Button("View Full Screen") {
                selectedCard = card
                withAnimation {
                    showCardDetail = true
                }
            }
            
            Button("Customize") {
                selectedCard = card
                showCustomize = true
            }
            
            Button("Quick Sell - 250 coins") {
                quickSellCard(card)
            }
            
            Button("Cancel", role: .cancel) {}
        } message: { card in
            Text("\(card.make.uppercased()) \(card.model.uppercased())")
        }
        .fullScreenCover(isPresented: $showCustomize) {
            if let card = selectedCard {
                CustomizeCardView(card: card)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func quickSellCard(_ card: SavedCard) {
        // Award 250 coins
        UserService.shared.addCoins(250)
        
        // Remove card from collection
        if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
            savedCards.remove(at: index)
            CardStorage.saveCards(savedCards)
        }
    }
    
    // Portrait: Paged view (swipe left/right for pages)
    private var portraitPagedView: some View {
        GeometryReader { geometry in
            let cardsPerPage = cardsPerRow == 1 ? 5 : 10 // 5 cards (5x1) or 10 cards (5x2)
            let totalPages = Int(ceil(Double(savedCards.count) / Double(cardsPerPage)))
            
            TabView(selection: $currentPage) {
                ForEach(0..<max(1, totalPages), id: \.self) { pageIndex in
                    let startIndex = pageIndex * cardsPerPage
                    let endIndex = min(startIndex + cardsPerPage, savedCards.count)
                    let pageCards = Array(savedCards[startIndex..<endIndex])
                    
                    VStack {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: cardsPerRow), spacing: 15) {
                            ForEach(pageCards) { card in
                                SavedCardView(card: card, isLargeSize: cardsPerRow == 1)
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
                    .padding(.bottom, 50) // Reduced from 80 to move cards down
                    .tag(pageIndex)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .padding(.bottom, 20) // Space between page indicators and capture button
        }
    }
    
    // Landscape: Continuous horizontal scroll (2 rows)
    private var landscapeScrollView: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyHGrid(rows: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                ForEach(savedCards) { card in
                    SavedCardView(card: card, isLargeSize: false)
                        .frame(width: 340) // Bigger than 260px - fills page better
                        .onTapGesture {
                            actionSheetCard = card
                            showActionSheet = true
                        }
                }
            }
            .padding()
            .padding(.top, 80) // Space for level header in landscape
            .padding(.trailing, 100) // Space for side nav
        }
    }
}

// Card detail overlay view with flip animation
struct CardDetailView: View {
    let card: SavedCard
    @Binding var isShowing: Bool
    @Binding var forceOrientationUpdate: Bool
    let onSpecsUpdated: (SavedCard) -> Void
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0
    @State private var isFetchingSpecs = false
    @State private var updatedCard: SavedCard?
    
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
                
                // Card container - rotates to landscape if device is portrait
                Group {
                    if isDeviceLandscape {
                        // Device is landscape - show card normally
                        cardContent(geometry: geometry, rotated: false)
                    } else {
                        // Device is portrait - rotate card to landscape
                        VStack {
                            Spacer()
                            cardContent(geometry: geometry, rotated: true)
                                .rotationEffect(.degrees(90))
                            Spacer()
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                
                // X button - always in top left of screen (not rotated)
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.pTitle2)
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
        
        return ZStack {
            // Front of card
            if !isFlipped {
                cardFrontView(cardWidth: cardWidth, cardHeight: cardHeight)
                    .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
            }
            
            // Back of card
            if isFlipped {
                cardBackView(cardWidth: cardWidth, cardHeight: cardHeight)
                    .rotation3DEffect(.degrees(flipDegrees + 180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .onTapGesture {
            // If flipping to back for the first time and no specs, fetch them
            if !isFlipped && (updatedCard ?? card).specs == nil {
                Task {
                    await fetchSpecsIfNeeded()
                }
            }
            
            withAnimation(.easeInOut(duration: 0.6)) {
                if isFlipped {
                    flipDegrees = 0
                } else {
                    flipDegrees = 180
                }
                isFlipped.toggle()
            }
        }
    }
    
    // MARK: - Fetch Specs
    
    private func fetchSpecsIfNeeded() async {
        let currentCard = updatedCard ?? card
        
        // Don't fetch if we already have specs
        guard currentCard.specs == nil else {
            print("✅ Specs already exist, skipping fetch")
            return
        }
        
        await MainActor.run {
            isFetchingSpecs = true
        }
        
        print("🔍 Fetching specs for \(currentCard.make) \(currentCard.model) \(currentCard.year)")
        
        do {
            // Use VehicleIDService directly - it handles Firestore caching
            let vehicleService = VehicleIdentificationService()
            let specs = try await vehicleService.fetchSpecs(
                make: currentCard.make,
                model: currentCard.model,
                year: currentCard.year
            )
            
            // Create updated card with specs
            let newCard = SavedCard(
                id: currentCard.id,
                image: currentCard.image ?? UIImage(),
                make: currentCard.make,
                model: currentCard.model,
                color: currentCard.color,
                year: currentCard.year,
                specs: specs,
                capturedBy: currentCard.capturedBy,
                capturedLocation: currentCard.capturedLocation,
                previousOwners: currentCard.previousOwners
            )
            
            await MainActor.run {
                updatedCard = newCard
                onSpecsUpdated(newCard)
                isFetchingSpecs = false
                print("✅ Specs fetched and saved")
            }
        } catch {
            print("❌ Failed to fetch specs: \(error)")
            await MainActor.run {
                isFetchingSpecs = false
            }
        }
    }
    
    // Front view of the card
    private func cardFrontView(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        ZStack {
            if let image = card.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            }
            
            // PNG border overlay based on customFrame (on top of image)
            if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .allowsHitTesting(false)
            }
            
            // Card info overlay at bottom
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(card.make.uppercased()) \(card.model.uppercased())")
                            .font(.custom("Futura-Bold", size: 22))
                            .foregroundStyle(.white)
                        Text(card.year)
                            .font(.pSubheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding()
                .background(.black.opacity(0.6))
            }
            .frame(width: cardWidth, height: cardHeight)
            
            // Tap hint at top right
            VStack {
                HStack {
                    Spacer()
                    Text("Tap to flip")
                        .font(.pCaption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5))
                        .cornerRadius(12)
                        .padding()
                }
                Spacer()
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
        .shadow(color: .black.opacity(0.5), radius: 20)
        .cardTilt()
    }
    
    // Back view of the card
    private func cardBackView(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let currentCard = updatedCard ?? card
        
        return ZStack {
            // Carbon fiber background
            Image("CardBackTexture")
                .resizable()
                .aspectRatio(contentMode: .fill)
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("\(currentCard.make.uppercased()) \(currentCard.model.uppercased())")
                        .font(.custom("Futura-Bold", size: 24))
                        .foregroundStyle(.white)
                    
                    Text(currentCard.year)
                        .font(.poppins(16))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Loading indicator or stats
                if isFetchingSpecs {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading specs...")
                            .font(.pCaption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        // Summary/Description
                        if let description = currentCard.specs?.description, !description.isEmpty {
                            Text(description)
                                .font(.poppins(13))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal, 24)
                        }
                        
                        // Stats in 2 columns
                        HStack(alignment: .top, spacing: 16) {
                            // Left column
                            VStack(spacing: 8) {
                                compactStatItem(label: "HP", value: currentCard.parseHP().map { "\($0)" } ?? "???")
                                compactStatItem(label: "0-60", value: currentCard.parseZeroToSixty().map { String(format: "%.1f", $0) + "s" } ?? "???")
                                compactStatItem(label: "ENGINE", value: currentCard.getEngine() ?? "???")
                            }
                            
                            // Right column
                            VStack(spacing: 8) {
                                compactStatItem(label: "TRQ", value: currentCard.parseTorque().map { "\($0)" } ?? "???")
                                compactStatItem(label: "TOP", value: currentCard.parseTopSpeed().map { "\($0)" } ?? "???")
                                compactStatItem(label: "DRIVE", value: currentCard.getDrivetrain() ?? "???")
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 4) {
                    if (currentCard.parseHP() == nil || currentCard.parseTorque() == nil) && !isFetchingSpecs {
                        Text("Some specs unavailable")
                            .font(.poppins(11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Text("Tap to flip back")
                        .font(.pCaption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 20)
            }
            .frame(width: cardWidth, height: cardHeight)
            
            // PNG border overlay based on customFrame
            if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
        .shadow(color: .black.opacity(0.5), radius: 20)
        .cardTilt()
    }
    
    // MARK: - Stat Item View
    
    private func statItem(label: String, value: String, highlight: Bool, compact: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.poppins(compact ? 14 : 24))
                .foregroundStyle(highlight ? .white : .white.opacity(0.4))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text(label)
                .font(.poppins(10))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 6 : 10)
        .background(
            highlight ?
            Color.white.opacity(0.15) :
            Color.white.opacity(0.05)
        )
        .cornerRadius(8)
    }
    
    // Compact stat item without background container
    private func compactStatItem(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.poppins(11))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 50, alignment: .leading)
            
            Text(value)
                .font(.poppins(15))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// Helper view for detail rows on card back
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.pSubheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.pSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }
}

// Share Sheet for exporting files
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
