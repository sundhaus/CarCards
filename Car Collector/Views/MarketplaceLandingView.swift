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
    @ObservedObject private var navigationController = NavigationController.shared
    
    var body: some View {
        NavigationStack(path: $navigationController.marketplaceNavigationPath) {
            ZStack {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("MARKETPLACE")
                            .font(.poppins(42))
                            .foregroundStyle(.primary)
                        
                        Text("Trade & collect rare cards")
                            .font(.poppins(16))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 30)
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Buy & Sell Card
                            NavigationButton(
                                title: "Buy & Sell",
                                subtitle: "Browse marketplace listings",
                                icon: "cart.fill",
                                gradient: [Color.blue, Color.purple],
                                action: {
                                    showBuySell = true
                                }
                            )
                            
                            // Transfer List
                            NavigationButton(
                                title: "Transfer List",
                                subtitle: "Cards you've listed for sale",
                                icon: "list.bullet.rectangle",
                                gradient: [Color.orange, Color.red],
                                action: {
                                    showTransferList = true
                                }
                            )
                            
                            // Transfer Targets
                            NavigationButton(
                                title: "Transfer Targets",
                                subtitle: "Cards you're bidding on",
                                icon: "target",
                                gradient: [Color.green, Color.teal],
                                action: {
                                    showTransferTargets = true
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, isLandscape ? 0 : 80)
                .padding(.trailing, isLandscape ? 100 : 0)
            }
            .background { AppBackground() }
            .navigationDestination(isPresented: $showBuySell) {
                MarketplaceBuySellView(
                    isLandscape: isLandscape,
                    savedCards: savedCards,
                    onCardListed: onCardListed
                )
            }
            .navigationDestination(isPresented: $showTransferList) {
                TransferListView(isLandscape: isLandscape)
            }
            .navigationDestination(isPresented: $showTransferTargets) {
                TransferTargetsView(isLandscape: isLandscape)
            }
        }
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
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
            navigationController.unpreserveTab(3)
            print("🏪 MarketplaceLandingView: Reset all navigation booleans from trigger")
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
