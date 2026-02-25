//
//  ShopView.swift
//  Car Collector
//
//  Shop page — gem store (IAP) and currency balances.
//  Two sections: Gem Packs (StoreKit 2) and coin balance overview.
//

import SwiftUI
import StoreKit

struct ShopView: View {
    var isLandscape: Bool = false
    
    @ObservedObject private var gemStore = GemStoreService.shared
    @ObservedObject private var userService = UserService.shared
    
    @State private var showRestoreAlert = false
    @State private var purchaseSuccessGems: Int? = nil
    @State private var showPurchaseSuccess = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Currency balances
                        balanceCards
                        
                        // Gem packs
                        gemPacksSection
                        
                        // Restore purchases
                        Button(action: {
                            Task {
                                await gemStore.restorePurchases()
                                showRestoreAlert = true
                            }
                        }) {
                            Text("Restore Purchases")
                                .font(.poppins(13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            
            // Purchase success overlay
            if showPurchaseSuccess, let gems = purchaseSuccessGems {
                purchaseSuccessOverlay(gems: gems)
            }
        }
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
            Task { await gemStore.loadProducts() }
        }
        .onDisappear {
            OrientationManager.unlockOrientation()
        }
        .alert("Purchases Restored", isPresented: $showRestoreAlert) {
            Button("OK") {}
        } message: {
            Text("Any previous gem purchases have been restored to your account.")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("SHOP")
                .font(.pTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Gem balance pill
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text("\(userService.gems)")
                    .font(.poppins(13))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
    
    // MARK: - Balance Cards
    
    private var balanceCards: some View {
        HStack(spacing: 12) {
            // Coins
            VStack(spacing: 8) {
                HeatCheckCoin(size: 32)
                Text("\(userService.coins)")
                    .font(.pTitle2)
                    .fontWeight(.bold)
                Text("Coins")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            
            // Gems
            VStack(spacing: 8) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("\(userService.gems)")
                    .font(.pTitle2)
                    .fontWeight(.bold)
                Text("Gems")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
    }
    
    // MARK: - Gem Packs Section
    
    private var gemPacksSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "diamond.fill")
                    .foregroundStyle(.cyan)
                Text("Gem Packs")
                    .font(.poppins(18))
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("Use gems for instant rarity upgrades")
                .font(.poppins(12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if gemStore.products.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.cyan)
                    Text("Loading store...")
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            } else {
                ForEach(gemStore.products, id: \.id) { product in
                    gemPackCard(product: product)
                }
            }
            
            if let error = gemStore.purchaseError {
                Text(error)
                    .font(.pCaption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Gem Pack Card
    
    private func gemPackCard(product: Product) -> some View {
        let gemAmount = RarityUpgradeConfig.gemAmounts[product.id] ?? 0
        let bonus = bonusPercent(for: product.id)
        let isBestValue = product.id == "com.carcollector.gems.6500"
        let isPopular = product.id == "com.carcollector.gems.2500"
        
        return Button(action: {
            Task {
                do {
                    try await gemStore.purchase(product)
                    purchaseSuccessGems = gemAmount
                    withAnimation(.spring(response: 0.4)) {
                        showPurchaseSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { showPurchaseSuccess = false }
                    }
                } catch {
                    gemStore.purchaseError = error.localizedDescription
                }
            }
        }) {
            HStack(spacing: 14) {
                // Gem icon
                gemIcon(for: gemAmount)
                    .frame(width: 52, height: 52)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(gemAmount)")
                            .font(.poppins(18))
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Text("Gems")
                            .font(.poppins(14))
                            .foregroundStyle(.secondary)
                        
                        if bonus > 0 {
                            Text("+\(bonus)%")
                                .font(.pCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    
                    if isBestValue {
                        Text("Best Value")
                            .font(.pCaption2)
                            .foregroundStyle(.yellow)
                    } else if isPopular {
                        Text("Most Popular")
                            .font(.pCaption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.poppins(15))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .overlay {
                if isBestValue {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [.yellow.opacity(0.6), .orange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
        }
        .disabled(gemStore.isPurchasing)
        .opacity(gemStore.isPurchasing ? 0.6 : 1)
    }
    
    // MARK: - Gem Icon
    
    private func gemIcon(for amount: Int) -> some View {
        let colors: [Color] = {
            if amount >= 6000 { return [.yellow, .orange] }
            if amount >= 2000 { return [.purple, .pink] }
            if amount >= 1000 { return [.blue, .cyan] }
            if amount >= 500  { return [.cyan, .teal] }
            return [.cyan.opacity(0.7), .blue.opacity(0.7)]
        }()
        
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
            
            Image(systemName: "diamond.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            
            if amount >= 2000 {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .offset(x: 12, y: -12)
            }
            if amount >= 6000 {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.4))
                    .offset(x: -10, y: -14)
            }
        }
    }
    
    // MARK: - Purchase Success Overlay
    
    private func purchaseSuccessOverlay(gems: Int) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("+\(gems) Gems")
                .font(.pTitle2)
                .fontWeight(.bold)
                .foregroundStyle(.cyan)
            
            Text("Added to your account")
                .font(.poppins(14))
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Helpers
    
    private func bonusPercent(for productId: String) -> Int {
        switch productId {
        case "com.carcollector.gems.550":  return 10
        case "com.carcollector.gems.1200": return 20
        case "com.carcollector.gems.2500": return 25
        case "com.carcollector.gems.6500": return 30
        default: return 0
        }
    }
}

#Preview {
    ShopView()
}
