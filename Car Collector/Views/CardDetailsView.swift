//
//  CardDetailsView.swift
//  Car Collector
//
//  Item Details page — redesigned to match CardOptionsView style
//  Uses AppBackground, Liquid Glass effects, and gradient option buttons
//

import SwiftUI

struct CardDetailsView: View {
    let card: SavedCard
    let onDismiss: () -> Void
    let onListed: () -> Void
    let onComparePrice: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var userService = UserService.shared
    
    @State private var showListingForm = false
    @State private var minStartBid = ""
    @State private var buyNowPrice = ""
    @State private var selectedDuration = 24
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showQuickSellConfirm = false
    @State private var showRarityUpgrade = false
    
    // Cached flat image (computed once, not on every body eval)
    @State private var flatImage: UIImage?
    
    
    let durations = [1, 3, 6, 12, 24]
    
    var isFormValid: Bool {
        guard let minBid = Double(minStartBid),
              let buyNow = Double(buyNowPrice) else {
            return false
        }
        return minBid > 0 && buyNow > minBid
    }
    
    var body: some View {
        ZStack {
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header — matches CardOptionsView
                headerView
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Card preview — flattened, centered
                        cardPreview
                            .padding(.horizontal, 30)
                        
                        // Action buttons — same style as CardOptionsView
                        VStack(spacing: 10) {
                            // Upgrade Rarity
                            if card.specs?.rarity != .legendary {
                                optionButton(
                                    icon: "arrow.up.diamond.fill",
                                    label: "Upgrade Rarity",
                                    subtitle: "\(card.specs?.rarity?.rawValue ?? "Common") → \(RarityUpgradeConfig.nextRarity(from: card.specs?.rarity ?? .common)?.rawValue ?? "")",
                                    colors: [Color.yellow, Color.orange]
                                ) {
                                    showRarityUpgrade = true
                                }
                            }
                            
                            // List on Market (expandable)
                            listOnMarketOption
                            
                            // Compare Price
                            optionButton(
                                icon: "chart.bar.fill",
                                label: "Compare Price",
                                subtitle: "See similar listings on the market",
                                colors: [Color.teal, Color.cyan]
                            ) {
                                onComparePrice()
                            }
                            
                            // Quick Sell
                            optionButton(
                                icon: "bolt.fill",
                                label: "Quick Sell",
                                subtitle: "Instantly sell for 250 coins",
                                colors: [Color.orange, Color.red]
                            ) {
                                showQuickSellConfirm = true
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Quick Sell?", isPresented: $showQuickSellConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sell for 250 coins", role: .destructive) {
                quickSell()
            }
        } message: {
            Text("This will permanently remove the card from your garage and award you 250 coins.")
        }
        .fullScreenCover(isPresented: $showRarityUpgrade) {
            let cloudCard = CardService.shared.myCards.first { cc in
                cc.make == card.make && cc.model == card.model && cc.year == card.year
            }
            RarityUpgradeView(
                card: card,
                cloudCard: cloudCard,
                onDismiss: { showRarityUpgrade = false },
                onUpgraded: { _ in
                    // Card rarity updated in Firestore — will sync via listener
                    showRarityUpgrade = false
                }
            )
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
            
            Text("ITEM DETAILS")
                .font(.pTitle3)
                .fontWeight(.bold)
            
            Spacer()
            
            // Coin counter
            coinCounter
        }
        .padding(.horizontal)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
    
    private var coinCounter: some View {
        HStack(spacing: 4) {
            HeatCheckCoin(size: 14)
            Text("\(userService.coins)")
                .font(.poppins(13))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
    
    // MARK: - Card Preview
    
    private var cardPreview: some View {
        Group {
            if let image = flatImage ?? card.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .liquidGlassShimmer(
                        rarity: card.specs?.rarity,
                        cornerRadius: 12,
                        borderWidth: 3.0
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 320, height: 180)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // Flatten once on appear, not on every body evaluation
            if flatImage == nil {
                flatImage = CardFlattener.shared.flatten(AnyCard.vehicle(card))
            }
        }
    }
    
    // MARK: - List on Market (Expandable)
    
    private var listOnMarketOption: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showListingForm.toggle()
                }
            }) {
                HStack(spacing: 14) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("List on Market")
                            .font(.poppins(16))
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text("Set a price and sell to other players")
                            .font(.poppins(12))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: showListingForm ? "chevron.up" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            }
            
            // Expanded listing form
            if showListingForm {
                listingFormView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Listing Form
    
    private var listingFormView: some View {
        VStack(spacing: 16) {
            priceControl(label: "Start Price:", value: $minStartBid)
            priceControl(label: "Buy Now Price:", value: $buyNowPrice)
            durationPicker
            listButton
            
            if let error = errorMessage {
                Text(error)
                    .font(.pCaption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(.top, -4)
    }
    
    private func priceControl(label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.poppins(14))
                .foregroundStyle(.primary)
            
            HStack(spacing: 12) {
                Button(action: {
                    if let current = Int(value.wrappedValue), current > 100 {
                        value.wrappedValue = "\(current - 100)"
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                }
                
                TextField("0", text: value)
                    .font(.poppins(18))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 10))
                    .keyboardType(.numberPad)
                
                HeatCheckCoin(size: 20)
                
                Button(action: {
                    if let current = Int(value.wrappedValue) {
                        value.wrappedValue = "\(current + 100)"
                    } else {
                        value.wrappedValue = "100"
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                }
            }
        }
    }
    
    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.poppins(14))
                .foregroundStyle(.primary)
            
            Picker("Duration", selection: $selectedDuration) {
                ForEach(durations, id: \.self) { hours in
                    Text("\(hours) Hour\(hours == 1 ? "" : "s")").tag(hours)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
            .tint(.primary)
        }
    }
    
    private var listButton: some View {
        Button(action: {
            Task { await createListing() }
        }) {
            if isCreating {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                Text("List for Transfer")
                    .font(.poppins(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .background(
            LinearGradient(
                colors: isFormValid && !isCreating
                    ? [Color.green, Color.blue]
                    : [Color.gray.opacity(0.5), Color.gray.opacity(0.5)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(!isFormValid || isCreating)
    }
    
    // MARK: - Option Button (reusable — matches CardOptionsView)
    
    private func optionButton(
        icon: String,
        label: String,
        subtitle: String,
        colors: [Color],
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: disabled ? [Color.gray.opacity(0.4)] : colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.poppins(16))
                        .fontWeight(.semibold)
                        .foregroundStyle(disabled ? .secondary : .primary)
                    
                    Text(subtitle)
                        .font(.poppins(12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
    
    // MARK: - Helper Functions
    
    private func createListing() async {
        guard let minBid = Double(minStartBid),
              let buyNow = Double(buyNowPrice) else { return }
        
        await MainActor.run {
            isCreating = true
            errorMessage = nil
        }
        
        do {
            let cloudCard = CardService.shared.myCards.first { cloudCard in
                cloudCard.make == card.make &&
                cloudCard.model == card.model &&
                cloudCard.year == card.year
            }
            
            guard let cloudCard = cloudCard else {
                throw NSError(domain: "CardDetails", code: -1, userInfo: [NSLocalizedDescriptionKey: "Card not found"])
            }
            
            let _ = try await MarketplaceService.shared.createListing(
                card: cloudCard,
                minStartBid: minBid,
                buyNowPrice: buyNow,
                duration: selectedDuration
            )
            
            await MainActor.run {
                isCreating = false
                onListed()
            }
        } catch {
            await MainActor.run {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func quickSell() {
        let rarity = card.specs?.rarity ?? .common
        userService.addCoins(RewardConfig.quickSellCoins(for: rarity))
        userService.addXP(RewardConfig.quickSellXP(for: rarity))
        onDismiss()
    }
}

#Preview {
    CardDetailsView(
        card: SavedCard(
            image: UIImage(systemName: "car.fill")!,
            make: "Porsche",
            model: "911 GT3",
            color: "White",
            year: "2024"
        ),
        onDismiss: {},
        onListed: {},
        onComparePrice: {}
    )
}
