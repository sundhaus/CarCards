//
//  CardDetailsView.swift
//  CarCardCollector
//
//  FIFA-style card details with expandable listing options
//

import SwiftUI

struct CardDetailsView: View {
    let card: SavedCard
    let onDismiss: () -> Void
    let onListed: () -> Void
    let onComparePrice: () -> Void
    
    @State private var showListingOptions = false
    @State private var minStartBid = "100"
    @State private var buyNowPrice = "500"
    @State private var selectedDuration = 24
    @State private var showCardBack = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    let durations = [6, 12, 24, 48, 72]
    
    var isFormValid: Bool {
        guard let minBid = Double(minStartBid),
              let buyNow = Double(buyNowPrice) else {
            return false
        }
        return minBid > 0 && buyNow > minBid
    }
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Text("Item Details")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Balance placeholder
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(.yellow)
                        Text("1")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Card display with flip
                        ZStack {
                            if !showCardBack {
                                // Front of card
                                if let image = card.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 280, height: 157.5)
                                        .cornerRadius(12)
                                }
                            } else {
                                // Back of card - specs
                                cardBackView
                                    .frame(width: 280, height: 157.5)
                            }
                        }
                        .rotation3DEffect(
                            .degrees(showCardBack ? 180 : 0),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .padding(.vertical, 30)
                        
                        // Options list
                        VStack(spacing: 0) {
                            // List on Transfer Market (expandable)
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    showListingOptions.toggle()
                                }
                            }) {
                                HStack {
                                    Text("List on Transfer Market")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(Color.white.opacity(0.05))
                            }
                            
                            // Expanded listing form
                            if showListingOptions {
                                listingFormView
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Card Details (flip)
                            Button(action: {
                                withAnimation(.spring(response: 0.6)) {
                                    showCardBack.toggle()
                                }
                            }) {
                                HStack {
                                    Text("Card Details")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Compare Price
                            Button(action: onComparePrice) {
                                HStack {
                                    Text("Compare Price")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            // Quick Sell
                            Button(action: {
                                // Quick sell action
                            }) {
                                HStack {
                                    Text("Quick Sell")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("500")
                                            .font(.system(size: 16, weight: .semibold))
                                        Image(systemName: "dollarsign.circle.fill")
                                            .foregroundStyle(.yellow)
                                    }
                                    .foregroundStyle(.white)
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // MARK: - Listing Form View
    
    private var listingFormView: some View {
        VStack(spacing: 20) {
            // Start Price
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Price:")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                HStack(spacing: 12) {
                    // Minus button
                    Button(action: {
                        if let current = Double(minStartBid), current > 100 {
                            minStartBid = String(Int(current) - 50)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Price field
                    HStack {
                        TextField("0", text: $minStartBid)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                        
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(.yellow)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Plus button
                    Button(action: {
                        let current = Double(minStartBid) ?? 100
                        minStartBid = String(Int(current) + 50)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Buy Now Price
            VStack(alignment: .leading, spacing: 8) {
                Text("Buy Now Price:")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                HStack(spacing: 12) {
                    // Minus button
                    Button(action: {
                        if let current = Double(buyNowPrice), current > 100 {
                            buyNowPrice = String(Int(current) - 50)
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Price field
                    HStack {
                        TextField("0", text: $buyNowPrice)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                        
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(.yellow)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Plus button
                    Button(action: {
                        let current = Double(buyNowPrice) ?? 100
                        buyNowPrice = String(Int(current) + 50)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Menu {
                    ForEach(durations, id: \.self) { hours in
                        Button("\(hours) Hours") {
                            selectedDuration = hours
                        }
                    }
                } label: {
                    HStack {
                        Text("\(selectedDuration) Hour\(selectedDuration == 1 ? "" : "s")")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            // List for Transfer button
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(
                LinearGradient(
                    colors: isFormValid && !isCreating ?
                        [Color.blue, Color.purple] :
                        [Color.gray, Color.gray.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .disabled(!isFormValid || isCreating)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
    }
    
    // MARK: - Card Back View
    
    private var cardBackView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("\(card.make) \(card.model)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(card.year)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Stats Grid (FIFA-style)
            VStack(spacing: 8) {
                // Row 1: Power
                HStack(spacing: 20) {
                    statItem(
                        label: "HP",
                        value: card.specs.horsepower.map { "\($0)" } ?? "???",
                        highlight: card.specs.horsepower != nil
                    )
                    statItem(
                        label: "TRQ",
                        value: card.specs.torque.map { "\($0)" } ?? "???",
                        highlight: card.specs.torque != nil
                    )
                }
                
                // Row 2: Performance
                HStack(spacing: 20) {
                    statItem(
                        label: "0-60",
                        value: card.specs.zeroToSixty.map { String(format: "%.1f", $0) } ?? "???",
                        highlight: card.specs.zeroToSixty != nil
                    )
                    statItem(
                        label: "TOP",
                        value: card.specs.topSpeed.map { "\($0)" } ?? "???",
                        highlight: card.specs.topSpeed != nil
                    )
                }
                
                // Row 3: Details
                HStack(spacing: 20) {
                    statItem(
                        label: "ENGINE",
                        value: card.specs.engineType ?? "???",
                        highlight: card.specs.engineType != nil
                    )
                    statItem(
                        label: "DRIVE",
                        value: card.specs.drivetrain ?? "???",
                        highlight: card.specs.drivetrain != nil
                    )
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer - only show if incomplete specs
            if !card.specs.isComplete {
                Text("Some specs unavailable")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 280, height: 157.5)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .rotation3DEffect(
            .degrees(180),
            axis: (x: 0, y: 1, z: 0)
        )
    }
    
    // Helper view for stat items
    private func statItem(label: String, value: String, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(highlight ? .white : .white.opacity(0.4))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(highlight ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Create Listing
    
    private func createListing() async {
        guard let minBid = Double(minStartBid),
              let buyNow = Double(buyNowPrice) else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Find the CloudCard that matches this SavedCard
            let cloudCard = CardService.shared.myCards.first { cloudCard in
                cloudCard.make == card.make &&
                cloudCard.model == card.model &&
                cloudCard.year == card.year
            }
            
            guard let cloudCard = cloudCard else {
                throw NSError(
                    domain: "CardDetails",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Card not found in cloud storage"]
                )
            }
            
            // Create listing in Firebase
            let _ = try await MarketplaceService.shared.createListing(
                card: cloudCard,
                minStartBid: minBid,
                buyNowPrice: buyNow,
                duration: selectedDuration
            )
            
            print("✅ Successfully created listing for \(cloudCard.make) \(cloudCard.model)")
            
            // Success
            await MainActor.run {
                isCreating = false
                onListed()
            }
            
        } catch {
            print("❌ Failed to create listing: \(error)")
            await MainActor.run {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    CardDetailsView(
        card: SavedCard(
            id: UUID(),
            image: UIImage(systemName: "car.fill")!,
            make: "Toyota",
            model: "Supra",
            color: "Red",
            year: "1998"
        ),
        onDismiss: {},
        onListed: {},
        onComparePrice: {}
    )
}
