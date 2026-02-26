//
//  ContentView.swift
//  CarCardCollector
//
//  Main view with bottom navigation hub
//

import SwiftUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var savedCards: [SavedCard] = []
    @State private var driverCards: [DriverCard] = []
    @State private var locationCards: [LocationCard] = []
    @State private var showCardDetail = false
    @State private var selectedCard: SavedCard?
    @State private var forceOrientationUpdate = false
    @StateObject private var levelSystem = LevelSystem()
    @State private var showProfile = false
    @State private var showDailyLoginPopup = false
    
    // Rarity reveal system
    @State private var showRarityReveal = false
    @State private var revealCard: SavedCard?
    
    // Track which tabs have been visited (for lazy loading)
    @State private var visitedTabs: Set<Int> = [1] // Home is pre-loaded
    @ObservedObject private var navigationController = NavigationController.shared
    @ObservedObject private var h2hService = HeadToHeadService.shared
    @ObservedObject private var dailyLoginService = DailyLoginService.shared
    @State private var showDuoInvite = false
    
    // Merge all card types for marketplace
    private var allSellableCards: [SavedCard] {
        var all = savedCards
        for dc in driverCards {
            all.append(SavedCard(
                id: dc.id,
                image: dc.thumbnail ?? dc.image ?? UIImage(),
                make: dc.firstName,
                model: dc.lastName,
                color: "Driver",
                year: dc.nickname.isEmpty ? "Driver" : dc.nickname,
                capturedBy: dc.capturedBy,
                capturedLocation: dc.capturedLocation,
                firebaseId: dc.firebaseId
            ))
        }
        for lc in locationCards {
            all.append(SavedCard(
                id: lc.id,
                image: lc.thumbnail ?? lc.image ?? UIImage(),
                make: lc.locationName,
                model: "",
                color: "Location",
                year: "Location",
                capturedBy: lc.capturedBy,
                capturedLocation: lc.capturedLocation,
                firebaseId: lc.firebaseId
            ))
        }
        return all
    }
    
    var body: some View {
        TabView(selection: $navigationController.selectedTab) {
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
                .padding(.top, DeviceScale.h(58))
            }
            
            // Capture Tab - pre-loaded for fast access
            Tab("Capture", systemImage: "camera.fill", value: 2) {
                if visitedTabs.contains(2) {
                    CaptureLandingView(
                        isLandscape: false,
                        levelSystem: levelSystem,
                        selectedTab: $navigationController.selectedTab,
                        onCardSaved: { card in
                            handleCardSaved(card)
                        }
                    )
                    .padding(.top, DeviceScale.h(58))
                } else {
                    Color.clear
                }
            }
            
            // Marketplace Tab - lazy
            Tab("Market", systemImage: "chart.line.uptrend.xyaxis", value: 3) {
                if visitedTabs.contains(3) {
                    MarketplaceLandingView(
                        isLandscape: false,
                        savedCards: allSellableCards,
                        onCardListed: { card in
                            if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                                savedCards.remove(at: index)
                                CardStorage.saveCards(savedCards)
                            }
                        }
                    )
                    .padding(.top, DeviceScale.h(58))
                } else {
                    Color.clear
                }
            }
            
            // Garage Tab - lazy
            Tab("Garage", systemImage: "wrench.and.screwdriver", value: 4) {
                if visitedTabs.contains(4) {
                    GarageView()
                        .padding(.top, DeviceScale.h(58))
                } else {
                    Color.clear
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.white)
        .environment(\.horizontalSizeClass, .compact)
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
        .overlay {
            // Daily login popup - appears automatically on first login
            if showDailyLoginPopup {
                DailyLoginPopup(isPresented: $showDailyLoginPopup)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(
                isPresented: $showCamera,
                onCardSaved: { card in
                    handleCardSaved(card)
                    showCamera = false
                    OrientationManager.lockToPortrait()
                    
                    // Trigger rarity reveal animation
                    revealCard = card
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showRarityReveal = true
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showRarityReveal) {
            if let card = revealCard {
                RarityRevealView(card: card.asAnyCard) {
                    showRarityReveal = false
                    revealCard = nil
                }
            }
        }
        .onChange(of: navigationController.selectedTab) { oldValue, newValue in
            OrientationManager.lockToPortrait()
            // Mark tab as visited for lazy loading
            if !visitedTabs.contains(newValue) {
                visitedTabs.insert(newValue)
            }
            // Reset destination tab to landing (skips preserved tabs)
            navigationController.resetToRoot(tab: newValue)
        }
        .onAppear {
            OrientationManager.lockToPortrait()
            // Defer card loading off the init path
            DispatchQueue.main.async {
                savedCards = CardStorage.loadCards()
                driverCards = CardStorage.loadDriverCards()
                locationCards = CardStorage.loadLocationCards()
                
                // One-time sync of locally modified images to Firebase
                // Skip if no local cards (fresh install / new device)
                if !UserDefaults.standard.bool(forKey: "hasCompletedImageSync_v1") {
                    let cardsToSync = savedCards
                    if !cardsToSync.isEmpty {
                        Task {
                            await CardService.shared.syncModifiedImages(localCards: cardsToSync)
                            UserDefaults.standard.set(true, forKey: "hasCompletedImageSync_v1")
                        }
                    } else {
                        // No local cards — mark as done so we don't check again
                        UserDefaults.standard.set(true, forKey: "hasCompletedImageSync_v1")
                    }
                }
                
                // One-time flatten migration for existing cards (v10: add rarity to activities)
                if !UserDefaults.standard.bool(forKey: "hasCompletedFlattenMigration_v10") {
                    let vehicles = savedCards
                    let drivers = driverCards
                    let locations = locationCards
                    Task {
                        await CardFlattener.shared.migrateExistingCards(
                            vehicles: vehicles,
                            drivers: drivers,
                            locations: locations
                        )
                        UserDefaults.standard.set(true, forKey: "hasCompletedFlattenMigration_v10")
                    }
                }
            }
            // Pre-warm Capture tab after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                visitedTabs.insert(2)
            }
            // Start listening for duo invites globally
            h2hService.startDuoInviteListener()
            
            // Load and check daily login (automatic popup)
            Task {
                guard let uid = FirebaseManager.shared.currentUserId else { return }
                
                // Load daily login data
                dailyLoginService.load(uid: uid)
                
                // Wait for data to load
                try? await Task.sleep(nanoseconds: 600_000_000) // 600ms
                
                await MainActor.run {
                    // Show popup if reward hasn't been claimed today
                    if !dailyLoginService.todayRewardClaimed {
                        // Delay popup slightly so user sees the app first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            showDailyLoginPopup = true
                        }
                    }
                }
            }
        }
        .onChange(of: h2hService.pendingDuoInvite?.id) { _, newId in
            showDuoInvite = newId != nil
        }
        .sheet(isPresented: $showDuoInvite) {
            if let invite = h2hService.pendingDuoInvite {
                DuoInvitePopupView(invite: invite)
            }
        }
    }
    
    // Indicator offset functions removed - native Liquid Glass handles tab bar
    
    /// Handle saving a newly captured card — local storage, cloud sync, XP, and specs pre-fetch
    private func handleCardSaved(_ card: SavedCard) {
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
                        year: card.year,
                        rarity: card.specs?.rarity
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
        
        let rarity = card.specs?.rarity ?? .common
        levelSystem.addXP(RewardConfig.captureXP(for: rarity))
        levelSystem.addCoins(RewardConfig.captureCoins(for: rarity))
        
        fetchSpecsForNewCard(card)
    }
    
    /// Fetch specs immediately after a card is saved to garage
    private func fetchSpecsForNewCard(_ card: SavedCard) {
        guard !card.make.isEmpty, !card.model.isEmpty, !card.year.isEmpty else { return }
        guard card.specs == nil else { return }
        
        Task {
            do {
                let vehicleService = VehicleIdentificationService()
                let specs = try await vehicleService.fetchSpecs(
                    make: card.make,
                    model: card.model,
                    year: card.year
                )
                
                await MainActor.run {
                    if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                        let existing = savedCards[index]
                        savedCards[index] = SavedCard(
                            id: existing.id,
                            image: existing.image ?? UIImage(),
                            make: existing.make,
                            model: existing.model,
                            color: existing.color,
                            year: existing.year,
                            specs: specs,
                            capturedBy: existing.capturedBy,
                            capturedLocation: existing.capturedLocation,
                            previousOwners: existing.previousOwners,
                            customFrame: specs.rarity?.borderAssetName,
                            firebaseId: existing.firebaseId
                        )
                        CardStorage.saveCards(savedCards)
                        CardRenderer.shared.clearCache(for: card.id)
                        print("✅ Pre-fetched specs for \(card.make) \(card.model) — rarity: \(specs.rarity?.rawValue ?? "none")")
                        
                        // Notify Garage to reload with updated rarity border
                        NotificationCenter.default.post(name: NSNotification.Name("CardSaved"), object: nil)
                        
                        // Re-flatten with rarity border and upload to Firebase
                        let updatedCard = savedCards[index]
                        Task {
                            do {
                                let flatURL = try await CardFlattener.shared.reflatten(updatedCard.asAnyCard)
                                if let firebaseId = updatedCard.firebaseId {
                                    try? await FriendsService.shared.updateActivityFlatImageURL(cardId: firebaseId, flatImageURL: flatURL)
                                    // Update customFrame and rarity on the activity feed
                                    let rarityBorder = specs.rarity?.borderAssetName ?? "Border_Common"
                                    try? await FriendsService.shared.updateActivityCustomFrame(cardId: firebaseId, customFrame: rarityBorder)
                                    if let rarity = specs.rarity {
                                        try? await FriendsService.shared.updateActivityRarity(cardId: firebaseId, rarity: rarity.rawValue)
                                    }
                                    // Update customFrame in Firebase card doc too
                                    try? await CardService.shared.updateCustomFrame(cardId: firebaseId, customFrame: rarityBorder)
                                }
                                print("✅ Re-flattened with rarity border: \(flatURL.prefix(60))...")
                            } catch {
                                print("⚠️ Re-flatten failed: \(error)")
                            }
                        }
                    }
                }
            } catch {
                print("⚠️ Pre-fetch specs failed: \(error)")
            }
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
                        .frame(width: DeviceScale.w(200))
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
            
            Button("Quick Sell - \(RewardConfig.quickSellCoins(for: card.specs?.rarity ?? .common)) coins") {
                quickSellCard(card)
            }
            
            Button("Cancel", role: .cancel) {}
        } message: { card in
            Text("\(card.make.uppercased()) \(card.model.uppercased())")
        }
        .fullScreenCover(isPresented: $showCustomize) {
            if let card = selectedCard {
                CustomizeCardView(card: .vehicle(card))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func quickSellCard(_ card: SavedCard) {
        // Award coins and XP scaled by card rarity
        let rarity = card.specs?.rarity ?? .common
        UserService.shared.addCoins(RewardConfig.quickSellCoins(for: rarity))
        UserService.shared.addXP(RewardConfig.quickSellXP(for: rarity))
        
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
                        .frame(width: DeviceScale.w(300))
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
                                .frame(width: DeviceScale.w(44), height: DeviceScale.w(44))
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
            
            // Create updated card with specs and rarity border
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
                previousOwners: currentCard.previousOwners,
                customFrame: currentCard.customFrame ?? specs.rarity?.borderAssetName
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
            if let flatImage = CardRenderer.shared.landscapeCard(for: (updatedCard ?? card).asAnyCard, height: cardHeight * 2) {
                Image(uiImage: flatImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            }
            
            // Card info overlay at bottom
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(card.make.uppercased()) \(card.model.uppercased())")
                            .font(.custom("Futura-Bold", fixedSize: 22))
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
        .rarityEffects(for: card.specs?.rarity)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .cardTilt(for: card.specs?.rarity)
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
                        .font(.custom("Futura-Bold", fixedSize: 24))
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
            if let borderImageName = CardBorderConfig.forFrame(card.customFrame, rarity: card.specs?.rarity).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
        .shadow(color: .black.opacity(0.5), radius: 20)
        .cardTilt(for: card.specs?.rarity)
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
