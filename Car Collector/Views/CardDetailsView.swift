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
                // Header
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
                    
                    // Coin counter
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
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Card display
                        ZStack {
                            if !showCardBack {
                                // Front of card
                                if let image = card.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 500)
                                        .cornerRadius(15)
                                        .shadow(color: .black.opacity(0.3), radius: 10)
                                }
                            } else {
                                // Back of card with specs
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
                        
                        // Action buttons
                        VStack(spacing: 16) {
                            // List on Transfer Market (expandable)
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
                                
                                // Expandable listing form
                                if showListingForm {
                                    VStack(spacing: 16) {
                                        // Start Price
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Start Price:")
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(.white)
                                                Spacer()
                                            }
                                            
                                            HStack(spacing: 12) {
                                                Button(action: {
                                                    if let current = Int(minStartBid), current > 100 {
                                                        minStartBid = "\(current - 100)"
                                                    }
                                                }) {
                                                    Image(systemName: "minus")
                                                        .font(.system(size: 20, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .frame(width: 44, height: 44)
                                                        .background(Color.white.opacity(0.2))
                                                        .cornerRadius(8)
                                                }
                                                
                                                TextField("0", text: $minStartBid)
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                    .multilineTextAlignment(.center)
                                                    .padding()
                                                    .background(Color.white.opacity(0.1))
                                                    .cornerRadius(10)
                                                    .keyboardType(.numberPad)
                                                
                                                HStack(spacing: 2) {
                                                    Image(systemName: "dollarsign.circle.fill")
                                                        .foregroundStyle(.yellow)
                                                }
                                                .font(.system(size: 18))
                                                
                                                Button(action: {
                                                    if let current = Int(minStartBid) {
                                                        minStartBid = "\(current + 100)"
                                                    } else {
                                                        minStartBid = "100"
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
                                        }
                                        
                                        // Buy Now Price
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Buy Now Price:")
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(.white)
                                                Spacer()
                                            }
                                            
                                            HStack(spacing: 12) {
                                                Button(action: {
                                                    if let current = Int(buyNowPrice), current > 100 {
                                                        buyNowPrice = "\(current - 100)"
                                                    }
                                                }) {
                                                    Image(systemName: "minus")
                                                        .font(.system(size: 20, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .frame(width: 44, height: 44)
                                                        .background(Color.white.opacity(0.2))
                                                        .cornerRadius(8)
                                                }
                                                
                                                TextField("0", text: $buyNowPrice)
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                    .multilineTextAlignment(.center)
                                                    .padding()
                                                    .background(Color.white.opacity(0.1))
                                                    .cornerRadius(10)
                                                    .keyboardType(.numberPad)
                                                
                                                HStack(spacing: 2) {
                                                    Image(systemName: "dollarsign.circle.fill")
                                                        .foregroundStyle(.yellow)
                                                }
                                                .font(.system(size: 18))
                                                
                                                Button(action: {
                                                    if let current = Int(buyNowPrice) {
                                                        buyNowPrice = "\(current + 100)"
                                                    } else {
                                                        buyNowPrice = "100"
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
                                        }
                                        
                                        // Duration picker
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
                                        
                                        // List button
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
                                        .background(
                                            isFormValid && !isCreating ?
                                            LinearGradient(colors: [Color.green, Color.blue], startPoint: .leading, endPoint: .trailing) :
                                            LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(12)
                                        .disabled(!isFormValid || isCreating)
                                        
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
                            }
                            
                            // Vehicle Specs button
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
                            
                            // Compare Price button
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
                            
                            // Quick Sell button
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
                        .padding(.horizontal)
                        .padding(.bottom, 30)
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
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(card.year)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                
                // Stats grid
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        statItem(label: "HP", value: parseIntValue(displaySpecs?.horsepower))
                        statItem(label: "TRQ", value: parseIntValue(displaySpecs?.torque))
                    }
                    
                    HStack(spacing: 12) {
                        statItem(label: "0-60", value: parseDoubleValue(displaySpecs?.zeroToSixty))
                        statItem(label: "TOP", value: parseIntValue(displaySpecs?.topSpeed))
                    }
                    
                    HStack(spacing: 12) {
                        statItem(label: "ENGINE", value: displaySpecs?.engine ?? "???", compact: true)
                        statItem(label: "DRIVE", value: displaySpecs?.drivetrain ?? "???", compact: true)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .cornerRadius(15)
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
        .cornerRadius(15)
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
        // Award coins for quick sell
        userService.addCoins(250)
        // Close and notify
        onDismiss()
    }
}
