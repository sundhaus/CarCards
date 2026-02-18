//
//  ContentView.swift
//  CarCardCollector
//
//  Main view with bottom navigation hub
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showCamera = false
    @State private var showCaptureLanding = false // New capture landing
    @State private var savedCards: [SavedCard] = CardStorage.loadCards()
    @State private var showCardDetail = false
    @State private var selectedCard: SavedCard?
    @State private var orientationBeforeFullscreen: UIInterfaceOrientationMask = .all
    @State private var forceOrientationUpdate = false
    @StateObject private var levelSystem = LevelSystem()
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var showProfile = false
    @StateObject private var navigationController = NavigationController.shared
    
    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            
            ZStack {
                TabView(selection: $selectedTab) {
                    // Home Tab
                    HomeView(
                        isLandscape: landscape,
                        showProfile: $showProfile,
                        levelSystem: levelSystem,
                        totalCards: savedCards.count
                    )
                    .padding(.top, 60)
                    .transition(.identity) // No transition animation
                    .tag(0)
                    
                    // Garage Tab - Shows all card types (vehicles, drivers, locations)
                    GarageView(isLandscape: landscape)
                        .padding(.top, landscape ? 0 : 60)
                        .tag(1)
                    
                    // Marketplace Tab
                    MarketplaceLandingView(
                        isLandscape: landscape,
                        savedCards: savedCards,
                        onCardListed: { card in
                            // Remove card from local savedCards when listed
                            if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                                savedCards.remove(at: index)
                                CardStorage.saveCards(savedCards)
                            }
                        }
                    )
                        .padding(.top, 60)
                        .tag(2)
                    
                    // Shop Tab
                    ShopView(isLandscape: landscape)
                        .ignoresSafeArea(.all) // Extend to full screen
                        .tag(3)
                }
                .toolbar(.hidden, for: .tabBar) // Hide native iOS tab bar
                .animation(nil, value: selectedTab) // Disable tab transition animation
                
                // Level Header - show on main hub pages (not camera/detail views)
                if !showCamera && !showCardDetail && !showCaptureLanding {
                    VStack {
                        LevelHeader(
                            levelSystem: levelSystem,
                            isLandscape: landscape,
                            totalCards: savedCards.count,
                            showProfile: $showProfile
                        )
                        Spacer()
                    }
                }
                
                // Custom bottom/side navigation bar
                if landscape {
                    // Side navigation (right side in landscape)
                    ZStack {
                        // Animated background indicator
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.blue.opacity(0.2))
                            .frame(width: 60, height: 50)
                            .offset(y: getIndicatorOffsetLandscape())
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                        
                        VStack(spacing: 0) {
                            // Garage button (top in landscape)
                            Button(action: {
                                navigationController.resetToRoot(tab: 1)
                                selectedTab = 1
                                print("🔧 Garage button tapped, selectedTab = \(selectedTab)")
                            }) {
                                let isActive = selectedTab == 1
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.title2)
                                    .foregroundStyle(isActive ? Color.blue : Color.gray)
                                    .frame(maxHeight: .infinity)
                                    .padding(.horizontal, 8)
                            }
                            .onChange(of: selectedTab) { oldValue, newValue in
                                print("🔧 Garage button saw tab change: \(oldValue) → \(newValue), should be \(newValue == 1 ? "blue" : "gray")")
                            }
                            
                            // Marketplace button
                            Button(action: {
                                navigationController.resetToRoot(tab: 2)
                                selectedTab = 2
                            }) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title2)
                                    .foregroundStyle(selectedTab == 2 ? .blue : .gray)
                                    .frame(maxHeight: .infinity)
                                    .padding(.horizontal, 8)
                            }
                            
                            // Spacer for camera button
                            Spacer()
                                .frame(maxHeight: .infinity)
                            
                            // Home button
                            Button(action: {
                                navigationController.resetToRoot(tab: 0)
                                selectedTab = 0
                            }) {
                                Image(systemName: "house")
                                    .font(.title2)
                                    .foregroundStyle(selectedTab == 0 ? .blue : .gray)
                                    .frame(maxHeight: .infinity)
                                    .padding(.horizontal, 8)
                            }
                            
                            // Shop button (bottom in landscape)
                            Button(action: {
                                navigationController.resetToRoot(tab: 3)
                                selectedTab = 3
                            }) {
                                Image(systemName: "bag")
                                    .font(.title2)
                                    .foregroundStyle(selectedTab == 3 ? .blue : .gray)
                                    .frame(maxHeight: .infinity)
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .background(Color.headerBackground)
                    .cornerRadius(20)
                    .frame(width: 80)
                    .blur(radius: showCardDetail ? 10 : 0)
                    .zIndex(1) // Ensure proper layering
                    .overlay(
                        // Capture button overlaid on center
                        Button(action: {
                            showCaptureLanding = true
                        }) {
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 70)
                                .background(.blue)
                                .clipShape(Circle())
                        }
                    )
                    .edgesIgnoringSafeArea([.bottom, .trailing])
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, -35)
                } else {
                    // Bottom navigation (portrait)
                    VStack {
                        Spacer()
                        
                        // Hub bar with camera button overlay
                        ZStack {
                            // Animated background indicator
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue.opacity(0.2))
                                .frame(width: 60, height: 40)
                                .offset(x: getIndicatorOffsetPortrait())
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                            
                            HStack(spacing: 0) {
                                // Shop button (left in portrait)
                                Button(action: {
                                    navigationController.resetToRoot(tab: 3)
                                    selectedTab = 3
                                }) {
                                    Image(systemName: "bag")
                                        .font(.title2)
                                        .foregroundStyle(selectedTab == 3 ? .blue : .gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                                
                                // Home button
                                Button(action: {
                                    navigationController.resetToRoot(tab: 0)
                                    selectedTab = 0
                                }) {
                                    Image(systemName: "house")
                                        .font(.title2)
                                        .foregroundStyle(selectedTab == 0 ? .blue : .gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                                
                                // Spacer for camera button
                                Spacer()
                                    .frame(maxWidth: .infinity)
                                
                                // Marketplace button
                                Button(action: {
                                    navigationController.resetToRoot(tab: 2)
                                    selectedTab = 2
                                }) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.title2)
                                        .foregroundStyle(selectedTab == 2 ? .blue : .gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                                
                                // Garage button (right in portrait)
                                Button(action: {
                                    navigationController.resetToRoot(tab: 1)
                                    selectedTab = 1
                                }) {
                                    Image(systemName: "wrench.and.screwdriver")
                                        .font(.title2)
                                        .foregroundStyle(selectedTab == 1 ? .blue : .gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                        .background(Color.headerBackground)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        .blur(radius: showCardDetail ? 10 : 0)
                        .overlay(
                            // Capture button overlaid on center
                            Button(action: {
                                showCaptureLanding = true
                            }) {
                                Image(systemName: "camera.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .frame(width: 70, height: 70)
                                    .background(.blue)
                                    .clipShape(Circle())
                            }
                        )
                        .padding(.bottom, 10)
                    }
                }
                
                // Card detail overlay - appears above everything
                if showCardDetail, let card = selectedCard {
                    CardDetailView(
                        card: card,
                        isShowing: $showCardDetail,
                        forceOrientationUpdate: $forceOrientationUpdate,
                        onSpecsUpdated: { updatedCard in
                            // Update the card in savedCards array
                            if let index = savedCards.firstIndex(where: { $0.id == updatedCard.id }) {
                                savedCards[index] = updatedCard
                                CardStorage.saveCards(savedCards)
                            }
                        }
                    )
                }
                
                // Profile popup - appears when level icon tapped
                if showProfile {
                    ProfileView(
                        isShowing: $showProfile,
                        levelSystem: levelSystem,
                        totalCards: savedCards.count
                    )
                }
            }
            .fullScreenCover(isPresented: $showCaptureLanding) {
                CaptureLandingView(
                    isLandscape: geometry.size.width > geometry.size.height,
                    levelSystem: levelSystem,
                    onCardSaved: { card in
                        // Save locally
                        savedCards.append(card)
                        CardStorage.saveCards(savedCards)
                        
                        // Save to cloud
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
                                    
                                    print("☁️ CloudCard created with ID: \(cloudCard.id)")
                                    
                                    // Update local card with Firebase ID
                                    if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                                        var updatedCard = savedCards[index]
                                        updatedCard.firebaseId = cloudCard.id
                                        savedCards[index] = updatedCard
                                        CardStorage.saveCards(savedCards)
                                        print("🔗 Linked local card \(card.id) to Firebase ID: \(cloudCard.id)")
                                        print("✅ Card now has firebaseId - frame sync will work!")
                                    } else {
                                        print("❌ ERROR: Could not find card in savedCards array!")
                                    }
                                    
                                    print("✅ Card saved to cloud with ID: \(cloudCard.id)")
                                } catch {
                                    print("❌ Cloud save failed: \(error)")
                                }
                            }
                        }
                        
                        // Award XP for capturing a card
                        levelSystem.addXP(10)
                    }
                )
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(
                    isPresented: $showCamera,
                    onCardSaved: { card in
                        // Save locally
                        savedCards.append(card)
                        CardStorage.saveCards(savedCards)
                        
                        // Save to cloud
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
                                    
                                    print("☁️ CloudCard created with ID: \(cloudCard.id)")
                                    
                                    // Update local card with Firebase ID
                                    if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                                        var updatedCard = savedCards[index]
                                        updatedCard.firebaseId = cloudCard.id
                                        savedCards[index] = updatedCard
                                        CardStorage.saveCards(savedCards)
                                        print("🔗 Linked local card \(card.id) to Firebase ID: \(cloudCard.id)")
                                        print("✅ Card now has firebaseId - frame sync will work!")
                                    } else {
                                        print("❌ ERROR: Could not find card in savedCards array!")
                                    }
                                    
                                    print("✅ Card saved to cloud with ID: \(cloudCard.id)")
                                } catch {
                                    print("❌ Cloud save failed: \(error)")
                                }
                            }
                        }
                        
                        // Award XP for capturing a card
                        levelSystem.addXP(10)
                        
                        showCamera = false
                        
                        // Return to appropriate orientation for current tab
                        if selectedTab == 1 {
                            OrientationManager.unlockOrientation()
                        } else {
                            OrientationManager.lockToPortrait()
                        }
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                deviceOrientation = UIDevice.current.orientation
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // All tabs are locked to portrait now
                OrientationManager.lockToPortrait()
            }
            .onAppear {
                // Set initial orientation based on starting tab
                if selectedTab == 1 {
                    OrientationManager.unlockOrientation()
                } else {
                    OrientationManager.lockToPortrait()
                }
            }
        }
    }
    
    // MARK: - Helper Functions for Animated Indicator
    
    private func getIndicatorOffsetPortrait() -> CGFloat {
        // Calculate horizontal offset for portrait bottom nav
        // Layout: Shop(3) | Home(0) | [Camera] | Market(2) | Garage(1)
        let screenWidth = UIScreen.main.bounds.width
        let buttonWidth = (screenWidth - 32 - 70) / 4 // Subtract padding and camera space, divide by 4 buttons
        
        switch selectedTab {
        case 3: // Shop (far left)
            return -buttonWidth * 1.5 - 35
        case 0: // Home (left of center)
            return -buttonWidth * 0.5 - 35
        case 2: // Marketplace (right of center)
            return buttonWidth * 0.5 + 35
        case 1: // Garage (far right)
            return buttonWidth * 1.5 + 35
        default:
            return 0
        }
    }
    
    private func getIndicatorOffsetLandscape() -> CGFloat {
        // Calculate vertical offset for landscape side nav
        // Layout (top to bottom): Garage(1) | Market(2) | [Camera] | Home(0) | Shop(3)
        let buttonHeight: CGFloat = 60 // Approximate height per button
        
        switch selectedTab {
        case 1: // Garage (top)
            return -buttonHeight * 1.5
        case 2: // Marketplace (second from top)
            return -buttonHeight * 0.5
        case 0: // Home (second from bottom)
            return buttonHeight * 0.5
        case 3: // Shop (bottom)
            return buttonHeight * 1.5
        default:
            return 0
        }
    }
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
                            .font(.subheadline)
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
                        .font(.caption)
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
    }
    
    // Back view of the card
    private func cardBackView(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let currentCard = updatedCard ?? card
        
        return ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("\(currentCard.make.uppercased()) \(currentCard.model.uppercased())")
                        .font(.custom("Futura-Bold", size: 24))
                        .foregroundStyle(.white)
                    
                    Text(currentCard.year)
                        .font(.system(size: 16, weight: .semibold))
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
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        // Summary/Description
                        if let description = currentCard.specs?.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 13, weight: .medium))
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
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Text("Tap to flip back")
                        .font(.caption)
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
    }
    
    // MARK: - Stat Item View
    
    private func statItem(label: String, value: String, highlight: Bool, compact: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: compact ? 14 : 24, weight: .bold))
                .foregroundStyle(highlight ? .white : .white.opacity(0.4))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text(label)
                .font(.system(size: 10, weight: .semibold))
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 50, alignment: .leading)
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
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
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline)
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
