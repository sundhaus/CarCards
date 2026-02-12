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
    @State private var savedCards: [SavedCard] = CardStorage.loadCards()
    @State private var showCardDetail = false
    @State private var selectedCard: SavedCard?
    @State private var orientationBeforeFullscreen: UIInterfaceOrientationMask = .all
    @State private var forceOrientationUpdate = false
    @StateObject private var levelSystem = LevelSystem()
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var showProfile = false
    
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
                    .tag(0)
                    
                    // Garage Tab
                    GarageViewWrapper(
                        savedCards: $savedCards,
                        isLandscape: landscape,
                        showCardDetail: $showCardDetail,
                        selectedCard: $selectedCard,
                        forceOrientationUpdate: $forceOrientationUpdate
                    )
                    .padding(.top, 60)
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
                        .padding(.top, 60)
                        .tag(3)
                }
                .toolbar(.hidden, for: .tabBar) // Hide native iOS tab bar
                
                // Level Header - show on main hub pages (not camera/detail views)
                if !showCamera && !showCardDetail {
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
                    VStack(spacing: 0) {
                        // Shop button (top in landscape)
                        Button(action: {
                            selectedTab = 3
                        }) {
                            Image(systemName: "bag")
                                .font(.title2)
                                .foregroundStyle(selectedTab == 3 ? .blue : .gray)
                                .frame(maxHeight: .infinity)
                                .padding(.horizontal, 8)
                        }
                        
                        // Marketplace button
                        Button(action: {
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
                            selectedTab = 0
                        }) {
                            Image(systemName: "house")
                                .font(.title2)
                                .foregroundStyle(selectedTab == 0 ? .blue : .gray)
                                .frame(maxHeight: .infinity)
                                .padding(.horizontal, 8)
                        }
                        
                        // Garage button (bottom in landscape)
                        Button(action: {
                            selectedTab = 1
                        }) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.title2)
                                .foregroundStyle(selectedTab == 1 ? .blue : .gray)
                                .frame(maxHeight: .infinity)
                                .padding(.horizontal, 8)
                        }
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .frame(width: 80)
                    .blur(radius: showCardDetail ? 10 : 0)
                    .overlay(
                        // Camera button overlaid on center
                        Button(action: {
                            // Lock to portrait before opening camera
                            OrientationManager.lockOrientation(.portrait)
                            // Small delay to allow rotation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showCamera = true
                            }
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
                        HStack(spacing: 0) {
                            // Garage button (left in portrait)
                            Button(action: {
                                selectedTab = 1
                            }) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.title2)
                                    .foregroundStyle(selectedTab == 1 ? .blue : .gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            
                            // Home button
                            Button(action: {
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
                                selectedTab = 2
                            }) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title2)
                                    .foregroundStyle(selectedTab == 2 ? .blue : .gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            
                            // Shop button (right in portrait)
                            Button(action: {
                                selectedTab = 3
                            }) {
                                Image(systemName: "bag")
                                    .font(.title2)
                                    .foregroundStyle(selectedTab == 3 ? .blue : .gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        .blur(radius: showCardDetail ? 10 : 0)
                        .overlay(
                            // Camera button overlaid on center
                            Button(action: {
                                // Lock to portrait before opening camera
                                OrientationManager.lockOrientation(.portrait)
                                // Small delay to allow rotation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    showCamera = true
                                }
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
                        forceOrientationUpdate: $forceOrientationUpdate
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
                                    let _ = try await CardService.shared.saveCard(
                                        image: image,
                                        make: card.make,
                                        model: card.model,
                                        color: card.color,
                                        year: card.year
                                    )
                                    print("Ã¢Å“â€¦ Card saved to cloud")
                                } catch {
                                    print("Ã¢Å¡Â Ã¯Â¸Â Cloud save failed: \(error)")
                                }
                            }
                        }
                        
                        // Award XP for capturing a card
                        levelSystem.addXP(10)
                        
                        showCamera = false
                        OrientationManager.unlockOrientation()
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                deviceOrientation = UIDevice.current.orientation
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
            // Force portrait first
            OrientationManager.lockOrientation(.portrait)
            // Small delay then unlock for live orientation detection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                OrientationManager.unlockOrientation()
                // Force orientation check
                forceOrientationUpdate.toggle()
            }
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
    
    var body: some View {
        NavigationStack {
            ZStack {
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
                    .ignoresSafeArea(edges: .trailing)
                }
            }
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
                                        selectedCard = card
                                        withAnimation {
                                            showCardDetail = true
                                        }
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                                                savedCards.remove(at: index)
                                                CardStorage.saveCards(savedCards)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
                        .frame(width: 200) // Fixed width for horizontal scrolling
                        .onTapGesture {
                            selectedCard = card
                            withAnimation {
                                showCardDetail = true
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
                                    savedCards.remove(at: index)
                                    CardStorage.saveCards(savedCards)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
            .padding(.trailing, 100) // Space for side nav
        }
    }
}

// Card detail overlay view with flip animation
struct CardDetailView: View {
    let card: SavedCard
    @Binding var isShowing: Bool
    @Binding var forceOrientationUpdate: Bool
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0
    
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
            
            // Card info overlay at bottom
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(card.make) \(card.model)")
                            .font(.title2)
                            .fontWeight(.bold)
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
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.5), radius: 20)
    }
    
    // Back view of the card
    private func cardBackView(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.2, blue: 0.3), Color(red: 0.1, green: 0.15, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 20) {
                // Title
                Text("\(card.make) \(card.model)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Divider()
                    .background(.white.opacity(0.3))
                
                // Card details
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Make", value: card.make)
                    DetailRow(label: "Model", value: card.model)
                    DetailRow(label: "Year", value: card.year)
                    DetailRow(label: "Color", value: card.color.isEmpty ? "Unknown" : card.color)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Tap hint at bottom
                Text("Tap to flip back")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 20)
            }
            .padding(.top, 30)
            .frame(width: cardWidth, height: cardHeight)
        }
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.5), radius: 20)
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
