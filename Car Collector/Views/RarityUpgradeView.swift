//
//  RarityUpgradeView.swift
//  Car Collector
//
//  Card rarity upgrade screen — shows evolution progress, unlock gates,
//  and two upgrade paths: Free (evolution points) or Paid (gems).
//

import SwiftUI
import StoreKit

struct RarityUpgradeView: View {
    let card: SavedCard
    let cloudCard: CloudCard?
    let onDismiss: () -> Void
    let onUpgraded: (CardRarity) -> Void
    
    @ObservedObject private var userService = UserService.shared
    @StateObject private var gemStore = GemStoreService.shared
    
    @State private var evolutionPoints: Int = 0
    @State private var battleWins: Int = 0
    @State private var isLoading = true
    @State private var isUpgrading = false
    @State private var showUpgradeAnimation = false
    @State private var newRarity: CardRarity?
    @State private var errorMessage: String?
    @State private var showGemStore = false
    
    private var currentRarity: CardRarity {
        card.specs?.rarity ?? .common
    }
    
    private var targetRarity: CardRarity? {
        RarityUpgradeConfig.nextRarity(from: currentRarity)
    }
    
    private var requiredPoints: Int {
        RarityUpgradeConfig.evolutionPointsRequired(from: currentRarity)
    }
    
    private var gemCost: Int {
        RarityUpgradeConfig.gemCost(from: currentRarity)
    }
    
    private var userLevel: Int {
        userService.currentProfile?.level ?? 1
    }
    
    private var totalCards: Int {
        userService.currentProfile?.totalCardsCollected ?? 0
    }
    
    private var userGems: Int {
        userService.currentProfile?.gems ?? 0
    }
    
    private var unlockGate: UnlockGateResult {
        guard let target = targetRarity else {
            return UnlockGateResult(
                isUnlocked: false, levelMet: true, requiredLevel: 0,
                cardsMet: true, requiredCards: 0, winsMet: true, requiredWins: 0
            )
        }
        return RarityUpgradeService.shared.checkUnlockGate(
            targetRarity: target,
            userLevel: userLevel,
            totalCardsOwned: totalCards,
            battleWins: battleWins
        )
    }
    
    private var canUpgradeFree: Bool {
        unlockGate.isUnlocked && evolutionPoints >= requiredPoints && !isUpgrading
    }
    
    private var canUpgradeGems: Bool {
        unlockGate.isUnlocked && userGems >= gemCost && !isUpgrading
    }
    
    var body: some View {
        ZStack {
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            if showUpgradeAnimation, let newRarity {
                upgradeAnimationOverlay(newRarity: newRarity)
            } else {
                VStack(spacing: 0) {
                    headerView
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                rarityBadge
                                evolutionProgressSection
                                
                                if !unlockGate.isUnlocked {
                                    unlockGateSection
                                }
                                
                                upgradeButtonsSection
                                
                                if let error = errorMessage {
                                    Text(error)
                                        .font(.pCaption)
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .task { await loadData() }
        .sheet(isPresented: $showGemStore) {
            GemStoreView()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular, in: .circle)
            }
            
            Spacer()
            
            Text("UPGRADE RARITY")
                .font(.pTitle3)
                .fontWeight(.bold)
            
            Spacer()
            
            // Gem counter
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text("\(userGems)")
                    .font(.poppins(13))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
    
    // MARK: - Rarity Badge
    
    private var rarityBadge: some View {
        VStack(spacing: 8) {
            // Current → Next rarity display
            HStack(spacing: 16) {
                rarityPill(currentRarity, active: true)
                
                if let target = targetRarity {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    rarityPill(target, active: false)
                }
            }
            
            Text("\(card.make) \(card.model)")
                .font(.poppins(14))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
    
    private func rarityPill(_ rarity: CardRarity, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: rarity.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(rarity.color)
            Text(rarity.rawValue)
                .font(.poppins(14))
                .foregroundStyle(active ? .primary : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            active
                ? AnyShapeStyle(rarity.gradient)
                : AnyShapeStyle(Color.gray.opacity(0.2))
        )
        .clipShape(Capsule())
    }
    
    // MARK: - Evolution Progress
    
    private var evolutionProgressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Evolution Points")
                    .font(.poppins(16))
                    .fontWeight(.semibold)
                Spacer()
                Text("\(evolutionPoints) / \(requiredPoints)")
                    .font(.poppins(14))
                    .foregroundStyle(.secondary)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, geo.size.width * evolutionProgress),
                            height: 12
                        )
                        .animation(.spring(response: 0.5), value: evolutionPoints)
                }
            }
            .frame(height: 12)
            
            // Battle point breakdown
            HStack(spacing: 16) {
                pointInfo(label: "1v1 Win", value: "+\(RarityUpgradeConfig.solo1v1Win)")
                pointInfo(label: "1v1 Loss", value: "+\(RarityUpgradeConfig.solo1v1Loss)")
                pointInfo(label: "2v2 Win", value: "+\(RarityUpgradeConfig.duo2v2Win)")
                pointInfo(label: "MVP", value: "+\(RarityUpgradeConfig.solo1v1MVP)")
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 20)
    }
    
    private var evolutionProgress: CGFloat {
        guard requiredPoints > 0 else { return 0 }
        return min(1.0, CGFloat(evolutionPoints) / CGFloat(requiredPoints))
    }
    
    private func pointInfo(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.poppins(13))
                .foregroundStyle(.orange)
            Text(label)
                .font(.pCaption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Unlock Gate Section
    
    private var unlockGateSection: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.yellow)
                Text("Unlock Requirements")
                    .font(.poppins(15))
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let target = targetRarity {
                gateRow(
                    label: "Level \(RarityUpgradeConfig.requiredLevel(for: target))",
                    met: unlockGate.levelMet,
                    current: "Lv. \(userLevel)"
                )
                gateRow(
                    label: "\(RarityUpgradeConfig.requiredCardsOwned(for: target)) Cards Owned",
                    met: unlockGate.cardsMet,
                    current: "\(totalCards)"
                )
                if RarityUpgradeConfig.requiredBattleWins(for: target) > 0 {
                    gateRow(
                        label: "\(RarityUpgradeConfig.requiredBattleWins(for: target)) Battle Wins",
                        met: unlockGate.winsMet,
                        current: "\(battleWins)"
                    )
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 20)
    }
    
    private func gateRow(label: String, met: Bool, current: String) -> some View {
        HStack {
            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(met ? .green : .red)
                .font(.system(size: 16))
            
            Text(label)
                .font(.poppins(13))
                .foregroundStyle(met ? .primary : .secondary)
            
            Spacer()
            
            Text(current)
                .font(.poppins(12))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Upgrade Buttons
    
    private var upgradeButtonsSection: some View {
        VStack(spacing: 12) {
            // Free upgrade button
            Button(action: { Task { await upgradeFree() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: canUpgradeFree ? [.orange, .red] : [.gray.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Evolve (Free)")
                            .font(.poppins(16))
                            .fontWeight(.semibold)
                            .foregroundStyle(canUpgradeFree ? .primary : .secondary)
                        
                        Text("\(evolutionPoints)/\(requiredPoints) points earned")
                            .font(.poppins(12))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isUpgrading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: canUpgradeFree ? "arrow.up.circle.fill" : "lock.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(canUpgradeFree ? .orange : .secondary)
                    }
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            }
            .disabled(!canUpgradeFree)
            .opacity(canUpgradeFree ? 1 : 0.6)
            
            // Gem upgrade button
            Button(action: { Task { await upgradeWithGems() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: canUpgradeGems ? [.cyan, .blue] : [.gray.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Instant Upgrade")
                            .font(.poppins(16))
                            .fontWeight(.semibold)
                            .foregroundStyle(canUpgradeGems ? .primary : .secondary)
                        
                        Text("\(gemCost) gems")
                            .font(.poppins(12))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isUpgrading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: canUpgradeGems ? "diamond.fill" : "lock.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(canUpgradeGems ? .cyan : .secondary)
                    }
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            }
            .disabled(!canUpgradeGems)
            .opacity(canUpgradeGems ? 1 : 0.6)
            
            // Buy Gems link
            if !canUpgradeGems && unlockGate.isUnlocked {
                Button(action: { showGemStore = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 13))
                        Text("Buy Gems")
                            .font(.poppins(13))
                    }
                    .foregroundStyle(.cyan)
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Upgrade Animation Overlay
    
    private func upgradeAnimationOverlay(newRarity: CardRarity) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Rarity badge with glow
            Text(newRarity.emoji)
                .font(.system(size: 80))
                .shadow(color: newRarity.color.opacity(0.8), radius: 30)
                .scaleEffect(showUpgradeAnimation ? 1.0 : 0.3)
                .opacity(showUpgradeAnimation ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showUpgradeAnimation)
            
            Text("UPGRADED!")
                .font(.pLargeTitle)
                .foregroundStyle(newRarity.gradient)
                .opacity(showUpgradeAnimation ? 1 : 0)
                .animation(.easeIn(duration: 0.4).delay(0.3), value: showUpgradeAnimation)
            
            Text("\(card.make) \(card.model)")
                .font(.poppins(16))
                .foregroundStyle(.secondary)
                .opacity(showUpgradeAnimation ? 1 : 0)
                .animation(.easeIn(duration: 0.4).delay(0.5), value: showUpgradeAnimation)
            
            HStack(spacing: 12) {
                Text(currentRarity.rawValue)
                    .font(.poppins(14))
                    .foregroundStyle(.secondary)
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                Text(newRarity.rawValue)
                    .font(.poppins(16))
                    .fontWeight(.bold)
                    .foregroundStyle(newRarity.color)
            }
            .opacity(showUpgradeAnimation ? 1 : 0)
            .animation(.easeIn(duration: 0.4).delay(0.7), value: showUpgradeAnimation)
            
            Spacer()
            
            Button(action: {
                onUpgraded(newRarity)
                onDismiss()
            }) {
                Text("Continue")
                    .font(.poppins(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [newRarity.color, newRarity.color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .opacity(showUpgradeAnimation ? 1 : 0)
            .animation(.easeIn(duration: 0.4).delay(1.0), value: showUpgradeAnimation)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        guard let firebaseId = cloudCard?.id ?? card.firebaseId else {
            isLoading = false
            return
        }
        
        do {
            evolutionPoints = try await RarityUpgradeService.shared.fetchEvolutionPoints(cardId: firebaseId)
            
            if let uid = FirebaseManager.shared.currentUserId {
                battleWins = try await RarityUpgradeService.shared.fetchUserBattleWins(uid: uid)
            }
        } catch {
            print("⚠️ Failed to load upgrade data: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Upgrade Actions
    
    private func upgradeFree() async {
        guard let firebaseId = cloudCard?.id ?? card.firebaseId else { return }
        
        isUpgrading = true
        errorMessage = nil
        
        do {
            let result = try await RarityUpgradeService.shared.upgradeWithEvolutionPoints(
                cardId: firebaseId,
                currentRarity: currentRarity
            )
            newRarity = result
            withAnimation { showUpgradeAnimation = true }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isUpgrading = false
    }
    
    private func upgradeWithGems() async {
        guard let firebaseId = cloudCard?.id ?? card.firebaseId else { return }
        
        isUpgrading = true
        errorMessage = nil
        
        do {
            let result = try await RarityUpgradeService.shared.upgradeWithGems(
                cardId: firebaseId,
                currentRarity: currentRarity
            )
            newRarity = result
            withAnimation { showUpgradeAnimation = true }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isUpgrading = false
    }
}

// MARK: - Gem Store Sheet

struct GemStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var gemStore = GemStoreService.shared
    @ObservedObject private var userService = UserService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Current balance
                        HStack {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.cyan)
                            Text("\(userService.currentProfile?.gems ?? 0)")
                                .font(.pTitle2)
                            Text("gems")
                                .font(.poppins(16))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                        
                        // Gem packs
                        if gemStore.products.isEmpty {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Loading store...")
                                    .font(.pCaption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(gemStore.products, id: \.id) { product in
                                gemPackRow(product: product)
                            }
                        }
                        
                        // Restore purchases
                        Button(action: {
                            Task { await gemStore.restorePurchases() }
                        }) {
                            Text("Restore Purchases")
                                .font(.poppins(13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 12)
                        
                        if let error = gemStore.purchaseError {
                            Text(error)
                                .font(.pCaption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Gem Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func gemPackRow(product: Product) -> some View {
        let gemAmount = RarityUpgradeConfig.gemAmounts[product.id] ?? 0
        let baseAmount = Int(Double(gemAmount) / bonusMultiplier(for: product.id))
        let bonusGems = gemAmount - baseAmount
        
        return Button(action: {
            Task {
                do {
                    try await gemStore.purchase(product)
                } catch {
                    gemStore.purchaseError = error.localizedDescription
                }
            }
        }) {
            HStack(spacing: 14) {
                // Gem icon stack
                ZStack {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(gemAmount) Gems")
                            .font(.poppins(16))
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        if bonusGems > 0 {
                            Text("+\(Int((bonusMultiplier(for: product.id) - 1) * 100))% bonus")
                                .font(.pCaption)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.poppins(15))
                    .fontWeight(.semibold)
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
        .disabled(gemStore.isPurchasing)
    }
    
    private func bonusMultiplier(for productId: String) -> Double {
        switch productId {
        case "com.carcollector.gems.550":  return 1.10
        case "com.carcollector.gems.1200": return 1.20
        case "com.carcollector.gems.2500": return 1.25
        case "com.carcollector.gems.6500": return 1.30
        default: return 1.0
        }
    }
}
