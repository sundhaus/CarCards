//
//  ContentView.swift
//  CarCardCollector
//
//  Main app view with navigation and card display
//  UPDATED: Fixed card back to show specs instead of basic info
//

import SwiftUI

struct ContentView: View {
    @State private var savedCards: [SavedCard] = []
    @State private var showingCamera = false
    @State private var selectedDetailCard: SavedCard?
    @State private var showingShare = false
    @State private var itemsToShare: [Any] = []
    @State private var forceOrientationUpdate = false
    
    // Services
    @ObservedObject private var userService = UserService.shared
    @ObservedObject private var friendsService = FriendsService.shared
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                
                ZStack {
                    // Background
                    Color(UIColor.systemGray6)
                        .ignoresSafeArea()
                    
                    if isLandscape {
                        // Landscape layout with side navigation
                        HStack(spacing: 0) {
                            // Main content
                            mainContent
                            
                            // Side navigation panel
                            sideNavigationPanel
                                .frame(width: 100)
                        }
                    } else {
                        // Portrait layout with bottom tabs
                        VStack(spacing: 0) {
                            // Main content
                            mainContent
                            
                            // Bottom tab bar
                            bottomTabBar
                                .frame(height: 70)
                        }
                    }
                }
            }
            .onAppear {
                loadCards()
            }
            .onChange(of: showingCamera) { oldValue, newValue in
                if !newValue {
                    loadCards()
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(
                    isPresented: $showingCamera,
                    onCardSaved: { card in
                        savedCards.append(card)
                        CardStorage.saveCards(savedCards)
                        showingCamera = false
                    }
                )
            }
            .sheet(item: $selectedDetailCard) { card in
                CardDetailView(
                    card: card,
                    isShowing: Binding(
                        get: { selectedDetailCard != nil },
                        set: { if !$0 { selectedDetailCard = nil } }
                    ),
                    forceOrientationUpdate: $forceOrientationUpdate,
                    onSpecsUpdated: { updatedCard in
                        // Update the card in the array
                        if let index = savedCards.firstIndex(where: { $0.id == updatedCard.id }) {
                            savedCards[index] = updatedCard
                            CardStorage.saveCards(savedCards)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingShare) {
                ShareSheet(items: itemsToShare)
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Cards grid
            if savedCards.isEmpty {
                emptyStateView
            } else {
                cardsGridView
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("Garage")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            // User stats
            HStack(spacing: 16) {
                // XP display
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("\(userService.currentProfile?.totalXP ?? 0)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // Card count
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text("\(savedCards.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("No cards yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap the camera to capture your first car")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Cards Grid
    
    private var cardsGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 280), spacing: 20)
            ], spacing: 20) {
                ForEach(savedCards) { card in
                    Button(action: {
                        selectedDetailCard = card
                    }) {
                        CardThumbnailView(card: card)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteCard(card)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Bottom Tab Bar
    
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            // Home
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 24))
                    Text("Home")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
            
            // Camera
            Button(action: { showingCamera = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                    Text("Capture")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
            
            // Marketplace
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 24))
                    Text("Market")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
            
            // Friends
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 24))
                    Text("Friends")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
        }
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
    }
    
    // MARK: - Side Navigation Panel
    
    private var sideNavigationPanel: some View {
        VStack(spacing: 20) {
            // Home
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 24))
                    Text("Home")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
            
            // Camera
            Button(action: { showingCamera = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                    Text("Capture")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
            
            // Marketplace
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 24))
                    Text("Market")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
            
            // Friends
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 24))
                    Text("Friends")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 20)
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 5, x: -2)
    }
    
    // MARK: - Helper Methods
    
    private func loadCards() {
        savedCards = CardStorage.loadCards()
    }
    
    private func deleteCard(_ card: SavedCard) {
        if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
            savedCards.remove(at: index)
            CardStorage.saveCards(savedCards)
        }
    }
}

// MARK: - Card Thumbnail View

struct CardThumbnailView: View {
    let card: SavedCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card image
            if let image = card.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 280, height: 157.5)
                    .clipped()
                    .cornerRadius(12)
            }
            
            // Card info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(card.make) \(card.model)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(card.year)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Card Detail View with Flip

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
                
                // Card container
                Group {
                    if isDeviceLandscape {
                        // Device is landscape - show card normally
                        cardContent(geometry: geometry, rotated: false)
                    } else {
                        // Device is portrait - rotate card to landscape
                        cardContent(geometry: geometry, rotated: true)
                            .rotationEffect(.degrees(90))
                            .frame(width: geometry.size.height, height: geometry.size.width)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
            }
        }
        .onAppear {
            updatedCard = card
        }
    }
    
    private func cardContent(geometry: GeometryProxy, rotated: Bool) -> some View {
        let cardWidth: CGFloat = rotated ? geometry.size.height * 0.8 : geometry.size.width * 0.8
        let cardHeight: CGFloat = cardWidth * (9.0 / 16.0)
        
        return ZStack {
            if !isFlipped {
                cardFrontView(cardWidth: cardWidth, cardHeight: cardHeight)
            } else {
                cardBackView(cardWidth: cardWidth, cardHeight: cardHeight)
            }
        }
        .rotation3DEffect(
            .degrees(flipDegrees),
            axis: (x: 0, y: 1, z: 0)
        )
        .onTapGesture {
            handleCardFlip()
        }
    }
    
    private func handleCardFlip() {
        // If flipping to back for the first time and specs are empty, fetch them
        if !isFlipped && (updatedCard?.specs.horsepower == nil || updatedCard?.specs.torque == nil) {
            Task {
                await fetchSpecsIfNeeded()
            }
        }
        
        // Perform flip animation
        withAnimation(.easeInOut(duration: 0.6)) {
            flipDegrees += 180
            isFlipped.toggle()
        }
    }
    
    private func fetchSpecsIfNeeded() async {
        guard let currentCard = updatedCard ?? card as SavedCard? else { return }
        
        // Don't fetch if we already have specs
        if currentCard.specs.horsepower != nil && currentCard.specs.torque != nil {
            return
        }
        
        print("🔄 Fetching specs for \(currentCard.make) \(currentCard.model) \(currentCard.year)")
        isFetchingSpecs = true
        
        // Fetch specs using CarSpecsService
        let specs = await CarSpecsService.shared.getSpecs(
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
            print("✅ Specs updated and saved")
        }
    }
    
    // MARK: - Card Front View
    
    private func cardFrontView(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        ZStack {
            // Card image
            if let image = (updatedCard ?? card).image {
                Image(uiImage: image)
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
                        Text("\((updatedCard ?? card).make) \((updatedCard ?? card).model)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text((updatedCard ?? card).year)
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
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.5), radius: 20)
    }
    
    // MARK: - Card Back View (FIFA-style Stats)
    
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
                    Text("\(currentCard.make) \(currentCard.model)")
                        .font(.system(size: 24, weight: .bold))
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
                    // Stats Grid (FIFA-style)
                    VStack(spacing: 12) {
                        // Row 1: Power
                        HStack(spacing: 20) {
                            statItem(
                                label: "HP",
                                value: currentCard.specs.horsepower.map { "\($0)" } ?? "???",
                                highlight: currentCard.specs.horsepower != nil
                            )
                            statItem(
                                label: "TRQ",
                                value: currentCard.specs.torque.map { "\($0)" } ?? "???",
                                highlight: currentCard.specs.torque != nil
                            )
                        }
                        
                        // Row 2: Performance
                        HStack(spacing: 20) {
                            statItem(
                                label: "0-60",
                                value: currentCard.specs.zeroToSixty.map { String(format: "%.1f", $0) } ?? "???",
                                highlight: currentCard.specs.zeroToSixty != nil
                            )
                            statItem(
                                label: "TOP",
                                value: currentCard.specs.topSpeed.map { "\($0)" } ?? "???",
                                highlight: currentCard.specs.topSpeed != nil
                            )
                        }
                        
                        // Row 3: Details
                        HStack(spacing: 20) {
                            statItem(
                                label: "ENGINE",
                                value: currentCard.specs.engineType ?? "???",
                                highlight: currentCard.specs.engineType != nil,
                                compact: true
                            )
                            statItem(
                                label: "DRIVE",
                                value: currentCard.specs.drivetrain ?? "???",
                                highlight: currentCard.specs.drivetrain != nil,
                                compact: true
                            )
                        }
                    }
                    .padding(.horizontal, 30)
                    .frame(maxHeight: .infinity)
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 4) {
                    if !currentCard.specs.isComplete && !isFetchingSpecs {
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
        }
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .rotation3DEffect(
            .degrees(180),
            axis: (x: 0, y: 1, z: 0)
        )
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
}

// MARK: - Share Sheet

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
