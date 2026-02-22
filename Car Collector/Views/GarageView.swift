//
//  GarageView.swift
//  CarCardCollector
//
//  Garage page with pagination and card interactions
//  Supports vehicles, drivers, and locations
//

import SwiftUI

struct GarageView: View {
    @State private var showCamera = false
    @State private var allCards: [AnyCard] = []
    @State private var cardsPerRow = 2 // 1 or 2
    @State private var currentPage = 0
    @State private var showCardDetail = false
    @State private var selectedCard: AnyCard?
    @State private var showCustomize = false
    @State private var showContextMenu = false
    @State private var contextMenuCard: AnyCard?
    @State private var contextMenuCardFrame: CGRect = .zero
    @State private var cardFrames: [UUID: CGRect] = [:]
    @ObservedObject private var navigationController = NavigationController.shared
    
    var body: some View {
        NavigationStack(path: $navigationController.garageNavigationPath) {
            GeometryReader { screenGeo in
            ZStack {
                VStack(spacing: 0) {
                    // Custom header with title and toggle on same line
                    HStack {
                        Text("GARAGE")
                            .font(.pTitle2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        // Migration button (backfill categories to friend_activities)
                        Button(action: {
                            Task {
                                await runMigration()
                            }
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.pTitle3)
                                .foregroundStyle(.purple)
                        }
                        
                        // Refresh specs button (backfill categories)
                        Button(action: {
                            Task {
                                await refreshAllSpecs()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.pTitle3)
                                .foregroundStyle(.green)
                        }
                        
                        Button(action: {
                            cardsPerRow = cardsPerRow == 1 ? 2 : 1
                        }) {
                            Image(systemName: cardsPerRow == 1 ? "rectangle.grid.1x2" : "square.grid.2x2")
                                .font(.pTitle3)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .rect)
                    
                    // Content
                    if allCards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "car.fill")
                                .font(.poppins(60))
                                .foregroundStyle(.secondary)
                            Text("Your collection will appear here")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // Portrait: Paged vertical scroll
                        portraitPagedView
                    }
                }
                .blur(radius: (showCardDetail || showContextMenu) ? 10 : 0)
                
                // Context menu overlay
                if showContextMenu, let card = contextMenuCard {
                    CardContextMenuOverlay(
                        card: card,
                        cardFrame: contextMenuCardFrame,
                        screenWidth: screenGeo.size.width,
                        isShowing: $showContextMenu,
                        isCrowned: {
                            let cardId = card.firebaseId ?? card.id.uuidString
                            return cardId == UserService.shared.crownCardId
                        }(),
                        onCustomize: {
                            showContextMenu = false
                            selectedCard = card
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showCustomize = true
                            }
                        },
                        onQuickSell: {
                            showContextMenu = false
                            quickSellCard(card)
                        },
                        onCrownToggle: {
                            // If unstarring, just clear
                            let currentId = card.firebaseId ?? card.id.uuidString
                            let isCurrentlyCrowned = currentId == UserService.shared.crownCardId
                            if isCurrentlyCrowned {
                                UserService.shared.setCrownCard(nil)
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showContextMenu = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    loadAllCards()
                                    currentPage = 0
                                }
                                return
                            }
                            
                            // Starring: need firebaseId
                            if let fbId = card.firebaseId {
                                print("⭐ Star toggle: using firebaseId \(fbId)")
                                UserService.shared.setCrownCard(fbId)
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showContextMenu = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    loadAllCards()
                                    currentPage = 0
                                }
                            } else {
                                // Card not synced — upload to Firebase quietly (no activity post)
                                print("⭐ Star toggle: no firebaseId, syncing to Firebase...")
                                if case .vehicle(let savedCard) = card {
                                    Task {
                                        do {
                                            let image = savedCard.image ?? UIImage()
                                            let cloudCard = try await CardService.shared.syncCardQuietly(
                                                image: image,
                                                savedCard: savedCard
                                            )
                                            
                                            // Update local card with firebaseId
                                            var allSaved = CardStorage.loadCards()
                                            if let idx = allSaved.firstIndex(where: { $0.id == savedCard.id }) {
                                                allSaved[idx].firebaseId = cloudCard.id
                                                CardStorage.saveCards(allSaved)
                                            }
                                            
                                            print("⭐ Synced: \(cloudCard.id), setting as star")
                                            UserService.shared.setCrownCard(cloudCard.id)
                                            
                                            await MainActor.run {
                                                loadAllCards()
                                                currentPage = 0
                                            }
                                        } catch {
                                            print("❌ Failed to sync card for starring: \(error)")
                                        }
                                    }
                                }
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showContextMenu = false
                                }
                            }
                        }
                    )
                }
                
                // Full screen card detail overlay
                if showCardDetail, let card = selectedCard {
                    UnifiedCardDetailView(
                        card: card,
                        isShowing: $showCardDetail,
                        onCardUpdated: { updatedCard in
                            // Refresh cards after update
                            loadAllCards()
                        }
                    )
                }
            }
            .coordinateSpace(name: "garageStack")
            .background { AppBackground() }
            .onAppear {
                OrientationManager.lockOrientation(.portrait)
                loadAllCards()
            }
            .onDisappear {
                OrientationManager.unlockOrientation()
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
            .fullScreenCover(isPresented: $showCustomize) {
                if let card = selectedCard {
                    CustomizeCardView(card: card)
                        .onDisappear {
                            loadAllCards() // Reload to show updates
                        }
                }
            }
            } // GeometryReader
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
        
        // Sort: crowned card first, then newest first
        let crownId = UserService.shared.crownCardId
        allCards = cards.sorted { card1, card2 in
            let id1 = card1.firebaseId ?? card1.id.uuidString
            let id2 = card2.firebaseId ?? card2.id.uuidString
            let card1Crowned = id1 == crownId
            let card2Crowned = id2 == crownId
            if card1Crowned != card2Crowned { return card1Crowned }
            return card1.capturedDate > card2.capturedDate
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
            let cardsPerPage = cardsPerRow == 1 ? 5 : 10
            let totalPages = Int(ceil(Double(allCards.count) / Double(cardsPerPage)))
            
            ZStack(alignment: .bottom) {
                TabView(selection: $currentPage) {
                    ForEach(0..<max(1, totalPages), id: \.self) { pageIndex in
                        let startIndex = pageIndex * cardsPerPage
                        let endIndex = min(startIndex + cardsPerPage, allCards.count)
                        let pageCards = Array(allCards[startIndex..<endIndex])
                        
                        VStack {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: cardsPerRow), spacing: 12) {
                                ForEach(pageCards) { card in
                                    garageCardCell(card: card)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            
                            Spacer()
                        }
                        .padding(.bottom, 40)
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Liquid Glass page indicator overlaid at bottom
                if totalPages > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.primary : Color.primary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 12)
                }
            }
        }
    }
    
    @ViewBuilder
    private func garageCardCell(card: AnyCard) -> some View {
        let isCrowned = (card.firebaseId ?? card.id.uuidString) == UserService.shared.crownCardId
        
        ZStack(alignment: .topTrailing) {
            UnifiedCardView(card: card, isLargeSize: cardsPerRow == 1)
            
            // Crown badge — top-right
            if isCrowned {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.yellow)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    .padding(5)
            }
        }
            .opacity(showContextMenu && contextMenuCard?.id == card.id ? 0 : 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            cardFrames[card.id] = geo.frame(in: .global)
                        }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            cardFrames[card.id] = newFrame
                        }
                }
            )
            .gesture(
                ExclusiveGesture(
                    LongPressGesture(minimumDuration: 0.2)
                        .onEnded { _ in
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            contextMenuCard = card
                            contextMenuCardFrame = cardFrames[card.id] ?? .zero
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                showContextMenu = true
                            }
                        },
                    TapGesture()
                        .onEnded {
                            selectedCard = card
                            withAnimation {
                                showCardDetail = true
                            }
                        }
                )
            )
    }
}

// MARK: - Card Context Menu Overlay

struct CardContextMenuOverlay: View {
    let card: AnyCard
    let cardFrame: CGRect
    let screenWidth: CGFloat
    @Binding var isShowing: Bool
    let isCrowned: Bool
    let onCustomize: () -> Void
    let onQuickSell: () -> Void
    let onCrownToggle: () -> Void
    
    @State private var appeared = false
    
    private var cardIsOnLeft: Bool {
        cardFrame.midX < screenWidth / 2
    }
    
    var body: some View {
        GeometryReader { overlayGeo in
            let overlayOrigin = overlayGeo.frame(in: .global).origin
            let localX = cardFrame.minX - overlayOrigin.x
            let localY = cardFrame.minY - overlayOrigin.y
            let panelWidth: CGFloat = cardFrame.width * 0.75
            
            ZStack(alignment: .topLeading) {
                // Dimmed background - tap to dismiss
                Color.black.opacity(appeared ? 0.5 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { dismissMenu() }
                
                // Crown tab — rendered FIRST so it's BEHIND the card
                let crownTabWidth: CGFloat = 36
                let crownTabHeight: CGFloat = 28
                let crownX: CGFloat = cardIsOnLeft
                    ? localX + 8
                    : localX + cardFrame.width - crownTabWidth - 8
                let crownY: CGFloat = localY - (appeared ? crownTabHeight : 0)
                
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onCrownToggle()
                }) {
                    Image(systemName: isCrowned ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isCrowned ? Color.yellow : Color.white.opacity(0.5))
                        .frame(width: crownTabWidth, height: crownTabHeight)
                        .background(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 8,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 8
                            )
                            .fill(Color(.systemBackground))
                        )
                }
                .buttonStyle(.plain)
                .offset(x: crownX, y: crownY)
                .opacity(appeared ? 1 : 0)
                
                // Side panel + card — rendered AFTER crown so card sits on top
                ZStack(alignment: cardIsOnLeft ? .leading : .trailing) {
                    // Action panel - sits behind and extends out
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .frame(
                            width: appeared ? cardFrame.width + panelWidth : cardFrame.width,
                            height: cardFrame.height
                        )
                        .overlay(alignment: cardIsOnLeft ? .trailing : .leading) {
                            VStack(spacing: 0) {
                                Spacer()
                                actionRow(label: "Customize", action: onCustomize)
                                Divider().padding(.horizontal, 12)
                                actionRow(label: "Quick Sell", action: onQuickSell)
                                Spacer()
                            }
                            .frame(width: panelWidth)
                        }
                    
                    // Card on top
                    cardPreview
                }
                .offset(
                    x: cardIsOnLeft ? localX : (appeared ? localX - panelWidth : localX),
                    y: localY
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }
    
    private var cardPreview: some View {
        UnifiedCardView(card: card, isLargeSize: false)
            .frame(width: cardFrame.width, height: cardFrame.height)
    }
    
    private func actionRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.poppins(16))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func dismissMenu() {
        withAnimation(.easeOut(duration: 0.2)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowing = false
        }
    }
}

// MARK: - Unified Card Detail View

struct UnifiedCardDetailView: View {
    let card: AnyCard
    @Binding var isShowing: Bool
    let onCardUpdated: (AnyCard) -> Void
    
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
            ZStack {
                // Dimmed background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Don't dismiss on tap - only X button dismisses
                    }
                
                // Card container - portrait mode: rotate card landscape
                VStack {
                    Spacer()
                    cardContent(screenSize: geometry.size)
                        .rotationEffect(.degrees(90))
                        .cardTilt()
                    Spacer()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // X button
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
                        
                        // Flip hint (only for vehicles)
                        if case .vehicle = card, !isFetchingSpecs {
                            if specsAreComplete(cardSpecs) {
                                Text("Tap card to flip")
                                    .font(.pCaption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.6))
                                    .cornerRadius(20)
                                    .padding(.trailing, 20)
                            } else {
                                Text("Tap to load stats")
                                    .font(.pCaption)
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
    
    private func cardContent(screenSize: CGSize) -> some View {
        // Portrait: use screen height for width (card is rotated 90°)
        let cardWidth: CGFloat = screenSize.height * 0.8
        let cardHeight: CGFloat = cardWidth / 16 * 9
        
        return ZStack {
            // Front side
            if !isFlipped {
                AnyCardDetailsFrontView(card: card)
                    .frame(width: cardWidth, height: cardHeight)
                    .rotation3DEffect(
                        .degrees(flipDegrees),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            
            // Back side - stats (only for vehicles)
            if isFlipped {
                if case .vehicle(let vehicleCard) = card, let specs = cardSpecs {
                    CardBackView(
                        make: vehicleCard.make,
                        model: vehicleCard.model,
                        year: vehicleCard.year,
                        specs: specs,
                        customFrame: vehicleCard.customFrame,
                        cardHeight: cardHeight
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

// MARK: - Unified front view for all card types (fullscreen detail)

struct AnyCardDetailsFrontView: View {
    let card: AnyCard
    
    private var cardTypeIcon: String {
        switch card {
        case .vehicle: return "car.fill"
        case .driver: return "person.fill"
        case .location: return "mappin.circle.fill"
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cardHeight = geometry.size.width / (16/9)
            
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
                
                // Card image - full bleed
                Group {
                    if let image = card.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .overlay(
                                Image(systemName: cardTypeIcon)
                                    .font(.system(size: cardHeight * 0.3))
                                    .foregroundStyle(.gray.opacity(0.4))
                            )
                    }
                }
                .frame(width: geometry.size.width, height: cardHeight)
                .clipped()
                
                // Border overlay
                if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                    Image(borderImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: cardHeight)
                        .allowsHitTesting(false)
                }
                
                // Title overlay
                if case .driver(let driverCard) = card {
                    let config = CardBorderConfig.forFrame(card.customFrame)
                    let fontSize = cardHeight * 0.08
                    let nickSize = cardHeight * 0.05
                    let inset = cardHeight * 0.08
                    
                    ZStack(alignment: .bottomLeading) {
                        Color.clear
                        VStack(alignment: .leading, spacing: cardHeight * 0.005) {
                            Text(driverCard.firstName.uppercased())
                                .font(.custom("Futura-Bold", size: fontSize))
                            
                            if !driverCard.nickname.isEmpty {
                                Text("\"\(driverCard.nickname.uppercased())\"")
                                    .font(.custom("Futura-Light", size: nickSize))
                                    .opacity(0.8)
                            }
                            
                            Text(driverCard.lastName.uppercased())
                                .font(.custom("Futura-Bold", size: fontSize))
                        }
                        .foregroundStyle(config.textColor)
                        .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                        .fixedSize()
                        .rotationEffect(.degrees(-90), anchor: .bottomLeading)
                        .padding(.leading, inset)
                        .padding(.bottom, inset)
                    }
                    .clipped()
                } else {
                    // Vehicle / Location: existing horizontal layout
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                let config = CardBorderConfig.forFrame(card.customFrame)
                                Text(card.titleLine1.uppercased())
                                    .font(.custom("Futura-Light", size: cardHeight * 0.08))
                                    .foregroundStyle(config.textColor)
                                    .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                                
                                if !card.titleLine2.isEmpty {
                                    Text(card.titleLine2.uppercased())
                                        .font(.custom("Futura-Bold", size: cardHeight * 0.08))
                                        .foregroundStyle(config.textColor)
                                        .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.top, cardHeight * 0.08)
                            .padding(.leading, cardHeight * 0.08)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: geometry.size.width, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
            .shadow(radius: 10)
        }
    }
}

// Card back view with specs
struct CardBackView: View {
    let make: String
    let model: String
    let year: String
    let specs: VehicleSpecs
    var customFrame: String? = nil
    var cardHeight: CGFloat = 200
    
    // Card is 16:9 landscape
    private var cardWidth: CGFloat { cardHeight * (16.0 / 9.0) }
    private var scale: CGFloat { cardHeight / 200 }
    
    var body: some View {
        ZStack {
            // Carbon fiber texture — explicit frame to prevent overflow
            Image("CardBackTexture")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
            
            // Content overlay
            VStack(spacing: 4 * scale) {
                // Header
                VStack(spacing: 2 * scale) {
                    Text("\(make.uppercased()) \(model.uppercased())")
                        .font(.custom("Futura-Bold", size: 12 * scale))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text(year)
                        .font(.poppins(9 * scale))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 12 * scale)
                
                // Description
                if !specs.description.isEmpty {
                    Text(specs.description)
                        .font(.poppins(6 * scale))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 20 * scale)
                }
                
                Spacer(minLength: 2 * scale)
                
                // Specs 3x2 grid
                VStack(spacing: 4 * scale) {
                    HStack(spacing: 8 * scale) {
                        statItem(label: "HP", value: specs.horsepower, highlight: specs.horsepower != "N/A")
                        statItem(label: "TORQUE", value: specs.torque, highlight: specs.torque != "N/A")
                    }
                    HStack(spacing: 8 * scale) {
                        statItem(label: "0-60", value: specs.zeroToSixty, highlight: specs.zeroToSixty != "N/A")
                        statItem(label: "TOP SPEED", value: specs.topSpeed, highlight: specs.topSpeed != "N/A")
                    }
                    HStack(spacing: 8 * scale) {
                        statItem(label: "ENGINE", value: specs.engine, highlight: specs.engine != "N/A")
                        statItem(label: "DRIVE", value: specs.drivetrain, highlight: specs.drivetrain != "N/A")
                    }
                }
                .padding(.horizontal, 18 * scale)
                .padding(.bottom, 18 * scale)
            }
            .frame(width: cardWidth, height: cardHeight)
            
            // Border overlay — always on top
            if let borderImageName = CardBorderConfig.forFrame(customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
        .shadow(radius: 10)
        .rotation3DEffect(
            .degrees(180),
            axis: (x: 0, y: 1, z: 0)
        )
    }
    
    private func statItem(label: String, value: String, highlight: Bool) -> some View {
        VStack(spacing: 1 * scale) {
            Text(value)
                .font(.poppins(12 * scale))
                .foregroundStyle(highlight ? .white : .white.opacity(0.4))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(label)
                .font(.poppins(6 * scale))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4 * scale)
        .background(highlight ? Color.white.opacity(0.15) : Color.clear)
        .cornerRadius(5 * scale)
    }
}

// MARK: - Unified Card View

struct UnifiedCardView: View {
    let card: AnyCard
    let isLargeSize: Bool
    
    private var cardHeight: CGFloat { isLargeSize ? 195.75 : 100 }
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
            
            // Card image - full bleed
            Group {
                if let image = card.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .overlay(
                            Image(systemName: cardTypeIcon)
                                .font(.system(size: isLargeSize ? 30 : 20))
                                .foregroundStyle(.gray.opacity(0.4))
                        )
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            
            // Border overlay based on customFrame
            if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .allowsHitTesting(false)
            }
            
            // Title overlay
            if case .driver(let driverCard) = card {
                let config = CardBorderConfig.forFrame(card.customFrame)
                let inset = cardHeight * 0.08
                
                ZStack(alignment: .bottomLeading) {
                    Color.clear
                    VStack(alignment: .leading, spacing: 1) {
                        Text(driverCard.firstName.uppercased())
                            .font(.custom("Futura-Bold", size: cardHeight * 0.09))
                        
                        if !driverCard.nickname.isEmpty {
                            Text("\"\(driverCard.nickname.uppercased())\"")
                                .font(.custom("Futura-Light", size: cardHeight * 0.06))
                        }
                        
                        Text(driverCard.lastName.uppercased())
                            .font(.custom("Futura-Bold", size: cardHeight * 0.09))
                    }
                    .foregroundStyle(config.textColor)
                    .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                    .fixedSize()
                    .rotationEffect(.degrees(-90), anchor: .bottomLeading)
                    .padding(.leading, inset)
                    .padding(.bottom, inset)
                }
            } else {
                // Vehicle / Location: existing top-left layout
                VStack {
                    HStack {
                        HStack(spacing: isLargeSize ? 6 : 3) {
                            let config = CardBorderConfig.forFrame(card.customFrame)
                            Text(card.titleLine1.uppercased())
                                .font(.custom("Futura-Light", size: cardHeight * 0.08))
                                .foregroundStyle(config.textColor)
                                .shadow(
                                    color: config.textShadow.color,
                                    radius: config.textShadow.radius,
                                    x: config.textShadow.x,
                                    y: config.textShadow.y
                                )
                            
                            if !card.titleLine2.isEmpty {
                                Text(card.titleLine2.uppercased())
                                    .font(.custom("Futura-Bold", size: cardHeight * 0.08))
                                    .foregroundStyle(config.textColor)
                                    .shadow(
                                        color: config.textShadow.color,
                                        radius: config.textShadow.radius,
                                        x: config.textShadow.x,
                                        y: config.textShadow.y
                                    )
                                    .lineLimit(1)
                            }
                        }
                        .padding(.top, cardHeight * 0.08)
                        .padding(.leading, cardHeight * 0.08)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
        .shadow(color: Color.black.opacity(0.3), radius: isLargeSize ? 6 : 4, x: 0, y: 3)
    }
    
    private var cardTypeIcon: String {
        switch card {
        case .vehicle: return "car.fill"
        case .driver: return "person.fill"
        case .location: return "mappin.circle.fill"
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
