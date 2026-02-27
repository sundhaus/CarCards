//
//  ShopView.swift
//  Car Collector
//
//  Shop page — coin shop with daily deals, cosmetic packs, and gem store (IAP).
//  Coins are the earnable currency with meaningful sinks:
//    • Daily Deals — rotating discounted cosmetics
//    • Cosmetic Packs — lootbox-style random bundles
//    • Full Catalog — browse & buy all cosmetics
//    • Gem Packs — premium IAP section
//

import SwiftUI
import StoreKit

struct ShopView: View {
    var isLandscape: Bool = false
    
    @ObservedObject private var gemStore = GemStoreService.shared
    @ObservedObject private var userService = UserService.shared
    @ObservedObject private var coinShop = CoinShopService.shared
    
    @State private var showRestoreAlert = false
    @State private var purchaseSuccessGems: Int? = nil
    @State private var showPurchaseSuccess = false
    @State private var purchasedItemName: String? = nil
    @State private var showCoinPurchaseSuccess = false
    @State private var showPackOpening = false
    @State private var packResults: [CosmeticItem] = []
    @State private var selectedTab: ShopTab = .featured
    
    enum ShopTab: String, CaseIterable {
        case featured = "Featured"
        case packs = "Packs"
        case catalog = "Catalog"
        case gems = "Gems"
    }
    
    var body: some View {
        ZStack {
            Image("ShopBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .overlay(Color.black.opacity(0.45))
                .drawingGroup()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Tab bar
                shopTabBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .featured:
                            // Currency balances
                            balanceCards
                            // Daily deals
                            dailyDealsSection
                            
                        case .packs:
                            cosmeticPacksSection
                            
                        case .catalog:
                            fullCatalogSection
                            
                        case .gems:
                            balanceCards
                            gemPacksSection
                            
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
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            
            // Gem purchase success overlay
            if showPurchaseSuccess, let gems = purchaseSuccessGems {
                purchaseSuccessOverlay(gems: gems)
            }
            
            // Coin purchase success overlay
            if showCoinPurchaseSuccess, let name = purchasedItemName {
                coinPurchaseSuccessOverlay(name: name)
            }
            
            // Pack opening overlay
            if showPackOpening {
                packOpeningOverlay
            }
        }
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
            Task {
                await gemStore.loadProducts()
                if let uid = FirebaseManager.shared.currentUserId {
                    await coinShop.load(uid: uid)
                }
            }
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
    
    // MARK: - Shop Tab Bar
    
    private var shopTabBar: some View {
        HStack(spacing: 0) {
            ForEach(ShopTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.poppins(13))
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.5))
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.orange : .clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("SHOP")
                .font(.pTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Coin balance pill
            HStack(spacing: 4) {
                HeatCheckCoin(size: 12)
                Text("\(userService.coins)")
                    .font(.poppins(13))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .solidGlassCapsule()
            
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
            .solidGlassCapsule()
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
            .solidGlass(cornerRadius: 14)
            
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
            .solidGlass(cornerRadius: 14)
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
                .solidGlass(cornerRadius: 14)
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
            .solidGlass(cornerRadius: 14)
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
        .solidGlass(cornerRadius: 20)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Daily Deals
    
    private var dailyDealsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.orange)
                Text("Daily Deals")
                    .font(.poppins(18))
                    .fontWeight(.semibold)
                Spacer()
                
                Text(dealTimeRemaining)
                    .font(.poppins(11))
                    .foregroundStyle(.secondary)
            }
            
            Text("Rotating discounts — new deals every day!")
                .font(.poppins(12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if coinShop.dailyDeals.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.orange)
                    Text("Loading deals...")
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .solidGlass(cornerRadius: 14)
            } else {
                ForEach(coinShop.dailyDeals) { deal in
                    dailyDealCard(deal)
                }
            }
        }
    }
    
    private func dailyDealCard(_ deal: DailyDeal) -> some View {
        let owned = coinShop.isOwned(deal.item.id)
        let canAfford = userService.coins >= deal.salePrice
        
        return HStack(spacing: 14) {
            // Item icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: deal.item.rarity.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: deal.item.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(deal.item.name)
                        .font(.poppins(14))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(deal.item.rarity.rawValue.uppercased())
                        .font(.pCaption2)
                        .fontWeight(.bold)
                        .foregroundStyle(deal.item.rarity.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(deal.item.rarity.color.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Text(deal.item.description)
                    .font(.poppins(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // Type label
                Text(cosmeticTypeLabel(deal.item.type))
                    .font(.poppins(10))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
            
            if owned {
                if coinShop.isEquipped(deal.item.id) {
                    Button {
                        coinShop.unequipType(deal.item.type)
                    } label: {
                        Text("Equipped ✓")
                            .font(.poppins(11))
                            .foregroundStyle(.orange)
                    }
                } else if deal.item.type != .cardSticker {
                    Button {
                        coinShop.equipItem(deal.item)
                    } label: {
                        Text("Equip")
                            .font(.poppins(11))
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Owned")
                        .font(.poppins(12))
                        .foregroundStyle(.green)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    // Sale badge
                    if deal.discountPercent > 0 {
                        Text("-\(deal.discountPercent)%")
                            .font(.pCaption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    
                    Button {
                        purchaseDeal(deal)
                    } label: {
                        HStack(spacing: 4) {
                            HeatCheckCoin(size: 10)
                            Text("\(deal.salePrice)")
                                .font(.poppins(13))
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            canAfford
                            ? LinearGradient(colors: [.orange, .yellow.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray, .gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(!canAfford)
                    
                    if deal.originalPrice != deal.salePrice {
                        Text("\(deal.originalPrice)")
                            .font(.poppins(10))
                            .strikethrough()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .solidGlass(cornerRadius: 14)
    }
    
    // MARK: - Cosmetic Packs
    
    private var cosmeticPacksSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.purple)
                Text("Cosmetic Packs")
                    .font(.poppins(18))
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("Open packs for random cosmetics with guaranteed rarity")
                .font(.poppins(12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(CoinShopService.cosmeticPacks) { pack in
                cosmeticPackCard(pack)
            }
            
            // Re-roll card section
            rerollSection
        }
    }
    
    private func cosmeticPackCard(_ pack: CosmeticPack) -> some View {
        let canAfford = userService.coins >= pack.price
        
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: pack.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: pack.icon)
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.name)
                        .font(.poppins(16))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(pack.description)
                        .font(.poppins(12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    openPackAction(pack)
                } label: {
                    HStack(spacing: 4) {
                        HeatCheckCoin(size: 11)
                        Text("\(pack.price)")
                            .font(.poppins(14))
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        canAfford
                        ? LinearGradient(colors: pack.gradientColors, startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray, .gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }
                .disabled(!canAfford)
            }
        }
        .padding(14)
        .solidGlass(cornerRadius: 14)
    }
    
    // MARK: - Re-Roll Section
    
    private var rerollSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.cyan)
                Text("Card Re-Roll")
                    .font(.poppins(18))
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Re-Identify Card")
                        .font(.poppins(14))
                        .fontWeight(.semibold)
                    
                    Text("Re-run AI on any card — catch missed details, update stats")
                        .font(.poppins(11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    HeatCheckCoin(size: 11)
                    Text("\(CoinShopService.rerollPrice)")
                        .font(.poppins(14))
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }
            .padding(14)
            .solidGlass(cornerRadius: 14)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Full Catalog
    
    private var fullCatalogSection: some View {
        VStack(spacing: 16) {
            ForEach(catalogSections, id: \.0) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: section.1)
                            .foregroundStyle(.orange)
                        Text(section.0)
                            .font(.poppins(16))
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(coinShop.ownedItemsOfType(section.2).count)/\(coinShop.itemsOfType(section.2).count)")
                            .font(.poppins(12))
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(coinShop.itemsOfType(section.2)) { item in
                        catalogItemRow(item)
                    }
                }
            }
        }
    }
    
    private var catalogSections: [(String, String, CosmeticItem.CosmeticType)] {
        [
            ("Card Backgrounds", "square.fill.on.square.fill", .cardBackground),
            ("Profile Frames", "person.crop.circle", .profileFrame),
            ("Capture Effects", "sparkles", .captureEffect),
            ("Card Stickers", "star.circle.fill", .cardSticker),
        ]
    }
    
    private func catalogItemRow(_ item: CosmeticItem) -> some View {
        let owned = coinShop.isOwned(item.id)
        let canAfford = userService.coins >= item.price
        
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: item.rarity.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.poppins(13))
                    .foregroundStyle(owned ? .secondary : .primary)
                
                HStack(spacing: 6) {
                    Text(item.rarity.rawValue.capitalized)
                        .font(.poppins(10))
                        .foregroundStyle(item.rarity.color)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(item.description)
                        .font(.poppins(10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if owned {
                if coinShop.isEquipped(item.id) {
                    Button {
                        coinShop.unequipType(item.type)
                    } label: {
                        Text("Unequip")
                            .font(.poppins(11))
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .overlay(Capsule().stroke(Color.orange, lineWidth: 1))
                    }
                } else if item.type != .cardSticker {
                    Button {
                        coinShop.equipItem(item)
                    } label: {
                        Text("Equip")
                            .font(.poppins(11))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Button {
                    purchaseCatalogItem(item)
                } label: {
                    HStack(spacing: 3) {
                        HeatCheckCoin(size: 9)
                        Text("\(item.price)")
                            .font(.poppins(12))
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        canAfford
                        ? LinearGradient(colors: [.orange, .yellow.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray, .gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                }
                .disabled(!canAfford)
            }
        }
        .padding(10)
        .solidGlass(cornerRadius: 12)
    }
    
    // MARK: - Actions
    
    private func purchaseDeal(_ deal: DailyDeal) {
        Task {
            guard let uid = FirebaseManager.shared.currentUserId else { return }
            let success = await coinShop.purchaseItem(deal.item, atPrice: deal.salePrice, uid: uid)
            if success {
                purchasedItemName = deal.item.name
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation(.spring(response: 0.4)) { showCoinPurchaseSuccess = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showCoinPurchaseSuccess = false }
                }
            }
        }
    }
    
    private func purchaseCatalogItem(_ item: CosmeticItem) {
        Task {
            guard let uid = FirebaseManager.shared.currentUserId else { return }
            let success = await coinShop.purchaseItem(item, atPrice: item.price, uid: uid)
            if success {
                purchasedItemName = item.name
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation(.spring(response: 0.4)) { showCoinPurchaseSuccess = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showCoinPurchaseSuccess = false }
                }
            }
        }
    }
    
    private func openPackAction(_ pack: CosmeticPack) {
        Task {
            guard let uid = FirebaseManager.shared.currentUserId else { return }
            if let results = await coinShop.openPack(pack, uid: uid) {
                packResults = results
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation(.spring(response: 0.5)) { showPackOpening = true }
            }
        }
    }
    
    // MARK: - Coin Purchase Success Overlay
    
    private func coinPurchaseSuccessOverlay(name: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("Unlocked!")
                .font(.pTitle2)
                .fontWeight(.bold)
                .foregroundStyle(.orange)
            
            Text(name)
                .font(.poppins(14))
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .solidGlass(cornerRadius: 20)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Pack Opening Overlay
    
    private var packOpeningOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showPackOpening = false }
                }
            
            VStack(spacing: 20) {
                Text("PACK OPENED!")
                    .font(.pTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                ForEach(packResults) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: item.rarity.gradient,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: item.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.poppins(14))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            Text(item.rarity.rawValue.uppercased())
                                .font(.pCaption2)
                                .fontWeight(.bold)
                                .foregroundStyle(item.rarity.color)
                        }
                        
                        Spacer()
                        
                        Text(cosmeticTypeLabel(item.type))
                            .font(.poppins(11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(12)
                    .solidGlass(cornerRadius: 12)
                }
                
                Button {
                    withAnimation { showPackOpening = false }
                } label: {
                    Text("Awesome!")
                        .font(.poppins(16))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.orange, .yellow.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
        }
        .transition(.opacity)
    }
    
    // MARK: - Helpers
    
    private var dealTimeRemaining: String {
        let now = Date()
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let remaining = endOfDay.timeIntervalSince(now)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return "\(hours)h \(minutes)m left"
    }
    
    private func cosmeticTypeLabel(_ type: CosmeticItem.CosmeticType) -> String {
        switch type {
        case .cardBackground: return "Background"
        case .profileFrame:   return "Frame"
        case .captureEffect:  return "Effect"
        case .cardSticker:    return "Sticker"
        }
    }
    
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
