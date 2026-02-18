//
//  CardDetailsView.swift
//  CarCardCollector
//
//  FIFA-style item details page
//

import SwiftUI

struct CardDetailsView: View {
    let card: SavedCard
    let onDismiss: () -> Void
    let onListed: () -> Void
    let onComparePrice: () -> Void
    
    @State private var showCardBack = false
    @State private var showListingForm = false
    @State private var minStartBid = ""
    @State private var buyNowPrice = ""
    @State private var selectedDuration = 24
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showQuickSellConfirm = false
    
    // Fetch specs when viewing back
    @State private var fetchedSpecs: VehicleSpecs?
    @State private var isFetchingSpecs = false
    
    @ObservedObject private var userService = UserService.shared
    
    let durations = [1, 3, 6, 12, 24]
    
    var isFormValid: Bool {
        guard let minBid = Double(minStartBid),
              let buyNow = Double(buyNowPrice) else {
            return false
        }
        return minBid > 0 && buyNow > minBid
    }
    
    private var displaySpecs: VehicleSpecs? {
        fetchedSpecs ?? card.specs
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        cardDisplayView
                        actionButtonsView
                    }
                }
            }
        }
        .alert("Quick Sell", isPresented: $showQuickSellConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Sell", role: .destructive) {
                quickSell()
            }
        } message: {
            Text("Sell this card for 250 coins?")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            Text("Item Details")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            
            Spacer()
            
            coinCounter
        }
        .padding()
    }
    
    private var coinCounter: some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.yellow)
            Text("\(userService.coins)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
    
    // MARK: - Card Display
    
    private var cardDisplayView: some View {
        ZStack {
            if !showCardBack {
                // Front of card - FIFA style
                CardDetailsFrontView(card: card)
            } else {
                if isFetchingSpecs {
                    specsLoadingView
                        .frame(maxWidth: 500)
                        .frame(height: 300)
                } else {
                    cardBackView
                        .frame(maxWidth: 500)
                        .frame(height: 300)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            listOnMarketButton
            vehicleSpecsButton
            comparePriceButton
            quickSellButton
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private var listOnMarketButton: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showListingForm.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 18))
                    Text("List on Transfer Market")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Image(systemName: showListingForm ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            
            if showListingForm {
                listingFormView
            }
        }
    }
    
    private var listingFormView: some View {
        VStack(spacing: 16) {
            priceControl(
                label: "Start Price:",
                value: $minStartBid
            )
            
            priceControl(
                label: "Buy Now Price:",
                value: $buyNowPrice
            )
            
            durationPicker
            
            listButton
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func priceControl(label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
            }
            
            HStack(spacing: 12) {
                minusButton(value: value)
                priceTextField(value: value)
                coinIcon
                plusButton(value: value)
            }
        }
    }
    
    private func minusButton(value: Binding<String>) -> some View {
        Button(action: {
            if let current = Int(value.wrappedValue), current > 100 {
                value.wrappedValue = "\(current - 100)"
            }
        }) {
            Image(systemName: "minus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
        }
    }
    
    private func plusButton(value: Binding<String>) -> some View {
        Button(action: {
            if let current = Int(value.wrappedValue) {
                value.wrappedValue = "\(current + 100)"
            } else {
                value.wrappedValue = "100"
            }
        }) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
        }
    }
    
    private func priceTextField(value: Binding<String>) -> some View {
        TextField("0", text: value)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .keyboardType(.numberPad)
    }
    
    private var coinIcon: some View {
        HStack(spacing: 2) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(.yellow)
        }
        .font(.system(size: 18))
    }
    
    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
            
            Picker("Duration", selection: $selectedDuration) {
                ForEach(durations, id: \.self) { hours in
                    Text("\(hours) Hour\(hours == 1 ? "" : "s")").tag(hours)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .tint(.white)
        }
    }
    
    private var listButton: some View {
        Button(action: {
            Task {
                await createListing()
            }
        }) {
            if isCreating {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text("List for Transfer")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .background(listButtonBackground)
        .cornerRadius(12)
        .disabled(!isFormValid || isCreating)
    }
    
    private var listButtonBackground: LinearGradient {
        isFormValid && !isCreating ?
        LinearGradient(colors: [Color.green, Color.blue], startPoint: .leading, endPoint: .trailing) :
        LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
    }
    
    private var vehicleSpecsButton: some View {
        Button(action: {
            if !showCardBack {
                Task {
                    await fetchSpecsIfNeeded()
                }
            }
            withAnimation(.spring(response: 0.4)) {
                showCardBack.toggle()
            }
        }) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 18))
                Text("Vehicle Specs")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(red: 0.3, green: 0.3, blue: 0.35))
            .cornerRadius(12)
        }
    }
    
    private var comparePriceButton: some View {
        Button(action: onComparePrice) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18))
                Text("Compare Price")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(red: 0.3, green: 0.3, blue: 0.35))
            .cornerRadius(12)
        }
    }
    
    private var quickSellButton: some View {
        Button(action: {
            showQuickSellConfirm = true
        }) {
            HStack {
                Text("Quick Sell")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                HStack(spacing: 4) {
                    Text("250")
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(red: 0.3, green: 0.3, blue: 0.35))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Card Back View
    
    private var cardBackView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                Text("\(card.make) \(card.model)")
                    .font(.custom("Futura-Bold", size: 20))
                    .foregroundStyle(.white)
                
                Text(card.year)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                
                // Summary/Description
                if let description = displaySpecs?.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                }
                
                compactStatsGrid
            }
            .padding()
            
            // PNG border overlay based on customFrame
            if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 300 * 0.08))
    }
    
    private var compactStatsGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left column
            VStack(spacing: 6) {
                compactStatRow(label: "HP", value: parseIntValue(displaySpecs?.horsepower))
                compactStatRow(label: "0-60", value: parseDoubleValue(displaySpecs?.zeroToSixty))
                compactStatRow(label: "ENGINE", value: displaySpecs?.engine ?? "???")
            }
            
            // Right column
            VStack(spacing: 6) {
                compactStatRow(label: "TRQ", value: parseIntValue(displaySpecs?.torque))
                compactStatRow(label: "TOP", value: parseIntValue(displaySpecs?.topSpeed))
                compactStatRow(label: "DRIVE", value: displaySpecs?.drivetrain ?? "???")
            }
        }
        .padding(.horizontal)
    }
    
    private func compactStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 50, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
    
    private var specsLoadingView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                Text("Loading specs...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 300 * 0.08))
    }
    
    private func statItem(label: String, value: String, compact: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: compact ? 12 : 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 4 : 8)
        .background(Color.white.opacity(0.15))
        .cornerRadius(6)
    }
    
    // MARK: - Helper Functions
    
    private func parseIntValue(_ string: String?) -> String {
        guard let string = string, string != "N/A" else { return "???" }
        let cleaned = string.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleaned.isEmpty ? "???" : cleaned
    }
    
    private func parseDoubleValue(_ string: String?) -> String {
        guard let string = string, string != "N/A" else { return "???" }
        let cleaned = string.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return cleaned.isEmpty ? "???" : cleaned + "s"
    }
    
    private func fetchSpecsIfNeeded() async {
        guard displaySpecs == nil else { return }
        
        await MainActor.run {
            isFetchingSpecs = true
        }
        
        do {
            let vehicleService = VehicleIdentificationService()
            let specs = try await vehicleService.fetchSpecs(
                make: card.make,
                model: card.model,
                year: card.year
            )
            
            await MainActor.run {
                fetchedSpecs = specs
                isFetchingSpecs = false
            }
        } catch {
            print("❌ Failed to fetch specs: \(error)")
            await MainActor.run {
                isFetchingSpecs = false
            }
        }
    }
    
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
        userService.addCoins(250)
        onDismiss()
    }
}

// MARK: - Card Details Front View

struct CardDetailsFrontView: View {
    let card: SavedCard
    
    var body: some View {
        GeometryReader { geometry in
            let cardHeight = geometry.size.width / (16/9)
            
            ZStack {
                // Card background with gradient
                RoundedRectangle(cornerRadius: cardHeight * 0.08)
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
                
                // Car image - full bleed
                Group {
                    if let image = card.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .overlay(
                                Image(systemName: "car.fill")
                                    .font(.system(size: cardHeight * 0.3))
                                    .foregroundStyle(.gray.opacity(0.4))
                            )
                    }
                }
                .frame(width: geometry.size.width, height: cardHeight)
                .clipped()
                
            // PNG border overlay based on customFrame
            if let borderImageName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: cardHeight)
                    .allowsHitTesting(false)
            }
                
                // Car name overlay - top left, horizontal
                VStack {
                    HStack {
                        HStack(spacing: 6) {
                            let config = CardBorderConfig.forFrame(card.customFrame)
                            Text(card.make.uppercased())
                                .font(.custom("Futura-Light", size: cardHeight * 0.08))
                                .foregroundStyle(config.textColor)
                                .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                            
                            Text(card.model)
                                .font(.custom("Futura-Bold", size: cardHeight * 0.08))
                                .foregroundStyle(config.textColor)
                                .shadow(color: config.textShadow.color, radius: config.textShadow.radius, x: config.textShadow.x, y: config.textShadow.y)
                                .lineLimit(1)
                        }
                        .padding(.top, cardHeight * 0.08)
                        .padding(.leading, cardHeight * 0.08)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(width: geometry.size.width, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.08))
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .frame(maxWidth: 500)
        .aspectRatio(16/9, contentMode: .fit)
    }
    
    // Calculate card level based on category rarity
    private var cardLevel: Int {
        guard let category = card.specs?.category else { return 1 }
        
        switch category {
        case .hypercar: return 10
        case .supercar: return 9
        case .track: return 8
        case .sportsCar: return 7
        case .muscle: return 6
        case .rally: return 5
        case .electric, .hybrid: return 5
        case .luxury: return 4
        case .classic, .concept: return 6
        case .coupe, .convertible: return 4
        case .offRoad, .suv, .truck: return 3
        case .sedan, .wagon, .hatchback, .van: return 2
        }
    }
}
