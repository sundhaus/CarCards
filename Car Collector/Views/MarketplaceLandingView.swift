//
//  MarketplaceLandingView.swift
//  CarCardCollector
//
//  Marketplace landing page with navigation options
//

import SwiftUI

struct MarketplaceLandingView: View {
    var isLandscape: Bool = false
    var savedCards: [SavedCard]
    var onCardListed: ((SavedCard) -> Void)? = nil  // ✅ Updated to match Firebase version
    @State private var showBuySell = false
    @State private var showTransferList = false
    @State private var showTransferTargets = false
    @State private var showCompareResults = false
    @State private var compareListings: [CloudListing] = []
    @State private var compareSummary = ""
    @ObservedObject private var navigationController = NavigationController.shared
    @ObservedObject private var marketplaceService = MarketplaceService.shared
    
    var body: some View {
        NavigationStack(path: $navigationController.marketplaceNavigationPath) {
            ZStack {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("MARKETPLACE")
                            .font(.poppins(42))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Text("Trade & collect rare cards")
                            .font(.poppins(16))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Buttons stretch to fill
                    VStack(spacing: 16) {
                        // Search Marketplace
                        NavigationButton(
                            title: "SEARCH",
                            subtitle: "Find and buy cards",
                            icon: "magnifyingglass",
                            gradient: [Color.blue, Color.purple],
                            action: {
                                showBuySell = true
                            }
                        )
                        
                        // Transfer List
                        NavigationButton(
                            title: "TRANSFER LIST",
                            subtitle: "Cards you've listed for sale",
                            icon: "list.bullet.rectangle",
                            gradient: [Color.orange, Color.red],
                            action: {
                                showTransferList = true
                            }
                        )
                        
                        // Transfer Targets
                        NavigationButton(
                            title: "TRANSFER TARGETS",
                            subtitle: "Cards you're bidding on",
                            icon: "target",
                            gradient: [Color.green, Color.teal],
                            action: {
                                showTransferTargets = true
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.bottom, isLandscape ? 0 : 80)
                .padding(.trailing, isLandscape ? 100 : 0)
            }
            .background {
                Image("MarketBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(Color.black.opacity(0.45))
                    .drawingGroup()
                    .ignoresSafeArea()
            }
            .navigationDestination(isPresented: $showBuySell) {
                MarketplaceFilterView(isLandscape: isLandscape)
            }
            .navigationDestination(isPresented: $showTransferList) {
                TransferListView(isLandscape: isLandscape)
            }
            .navigationDestination(isPresented: $showTransferTargets) {
                TransferTargetsView(isLandscape: isLandscape)
            }
            .navigationDestination(isPresented: $showCompareResults) {
                MarketplaceSearchResultsView(
                    listings: compareListings,
                    hasUnfilteredListings: !marketplaceService.activeListings.isEmpty,
                    filterSummary: compareSummary
                )
            }
        }
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
            marketplaceService.listenToActiveListings()
            checkForComparePrice()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ComparePrice"))) { _ in
            checkForComparePrice()
        }
        .onDisappear {
            OrientationManager.unlockOrientation()
        }
        .onChange(of: navigationController.marketplaceNavigationPath) { oldValue, newValue in
            // When navigation path is cleared, reset all boolean states
            if newValue.isEmpty {
                showBuySell = false
                showTransferList = false
                showTransferTargets = false
                showCompareResults = false
            }
        }
        .onChange(of: showBuySell) { _, isBuySellOpen in
            // Preserve Market tab while in buy/sell (listings are deep)
            if isBuySellOpen {
                navigationController.preserveTab(3)
            } else {
                navigationController.unpreserveTab(3)
            }
        }
        .onChange(of: navigationController.popToRootTrigger) { oldValue, newValue in
            // Only reset if Market tab is not preserved
            guard !navigationController.preservedTabs.contains(3) else { return }
            showBuySell = false
            showTransferList = false
            showTransferTargets = false
            showCompareResults = false
            navigationController.unpreserveTab(3)
            print("🏪 MarketplaceLandingView: Reset all navigation booleans from trigger")
        }
    }
    
    private func checkForComparePrice() {
        guard let compare = NavigationController.shared.comparePriceCard else { return }
        NavigationController.shared.comparePriceCard = nil
        
        // Filter listings to match the card
        let filtered = marketplaceService.activeListings.filter { listing in
            if !compare.make.isEmpty && listing.make != compare.make { return false }
            if !compare.model.isEmpty && listing.model != compare.model { return false }
            // Only filter year if it's an actual year (not "Driver" or "Location")
            if !compare.year.isEmpty && compare.year != "Driver" && compare.year != "Location" {
                if listing.year != compare.year { return false }
            }
            return true
        }
        
        var parts: [String] = []
        if !compare.make.isEmpty { parts.append(compare.make) }
        if !compare.model.isEmpty { parts.append(compare.model) }
        if !compare.year.isEmpty && compare.year != "Driver" && compare.year != "Location" { parts.append(compare.year) }
        compareSummary = parts.isEmpty ? "All Listings" : parts.joined(separator: " ")
        compareListings = filtered
        
        print("📊 Compare Price: Found \(filtered.count) matching listings for \(compareSummary)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCompareResults = true
        }
    }
}

// Custom corner radius extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    MarketplaceLandingView(savedCards: [])
}
