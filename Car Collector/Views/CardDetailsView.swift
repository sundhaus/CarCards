//
//  CardDetailsView.swift (FIXED)
//  CarCardCollector
//
//  Now fetches specs on flip and displays all metadata on card back
//  FIXED: Uses CarSpecs instead of VehicleSpecs
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
    
    // NEW: Fetch specs when card flips
    @State private var fetchedSpecs: VehicleSpecs?
    @State private var isFetchingSpecs = false
    @StateObject private var vehicleIDService = VehicleIdentificationService()
    
    let durations = [6, 12, 24, 48, 72]
    
    var isFormValid: Bool {
        guard let minBid = Double(minStartBid),
              let buyNow = Double(buyNowPrice) else {
            return false
        }
        return minBid > 0 && buyNow > minBid
    }
    
    // Use fetched specs or fall back to card.specs
    private var displaySpecs: VehicleSpecs? {
        fetchedSpecs ?? card.specs
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
                                // Back of card - NOW with specs fetch
                                if isFetchingSpecs {
                                    specsLoadingView
                                } else {
                                    cardBackView
                                        .frame(width: 280, height: 157.5)
                                }
                            }
                        }
                        .rotation3DEffect(
                            .degrees(showCardBack ? 180 : 0),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .animation(.easeInOut(duration: 0.6), value: showCardBack)
                        .onTapGesture {
                            if !showCardBack {
                                // Flipping to back - fetch specs
                                Task {
                                    await fetchSpecsIfNeeded()
                                }
                            }
                            showCardBack.toggle()
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 30)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            // List Item button
                            Button(action: {
                                showListingForm = true
                            }) {
                                HStack {
                                    Image(systemName: "tag")
                                    Text("List Item")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            
                            // Compare Price button
                            Button(action: onComparePrice) {
                                HStack {
                                    Image(systemName: "chart.bar")
                                    Text("Compare Price")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            
            // Listing form overlay
            if showListingForm {
                listingFormView
            }
            
            // Specs fetching overlay
            if isFetchingSpecs && showCardBack {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.green)
                    
                    Text("Fetching vehicle specs...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Fetch Specs
    
    private func fetchSpecsIfNeeded() async {
        // Only fetch if we don't have specs already
        guard displaySpecs == nil else {
            print("✅ Specs already exist, skipping fetch")
            return
        }
        
        await MainActor.run {
            isFetchingSpecs = true
        }
        
        print("🔍 Fetching specs for \(card.make) \(card.model) \(card.year)")
        
        do {
            // Use VehicleIDService directly - it handles Firestore caching
            let specs = try await vehicleIDService.fetchSpecs(
                make: card.make,
                model: card.model,
                year: card.year
            )
            
            await MainActor.run {
                fetchedSpecs = specs
                isFetchingSpecs = false
                print("✅ Specs fetched successfully")
            }
        } catch {
            print("❌ Failed to fetch specs: \(error)")
            await MainActor.run {
                isFetchingSpecs = false
            }
        }
    }
    
    // MARK: - Card Back View (UPDATED with metadata)
    
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
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Specs Grid
            VStack(spacing: 6) {
                // Row 1: Power
                HStack(spacing: 12) {
                    statItem(
                        label: "HP",
                        value: parseIntValue(displaySpecs?.horsepower),
                        highlight: displaySpecs?.horsepower != nil && displaySpecs?.horsepower != "N/A"
                    )
                    statItem(
                        label: "TRQ",
                        value: parseIntValue(displaySpecs?.torque),
                        highlight: displaySpecs?.torque != nil && displaySpecs?.torque != "N/A"
                    )
                }
                
                // Row 2: Performance
                HStack(spacing: 12) {
                    statItem(
                        label: "0-60",
                        value: parseDoubleValue(displaySpecs?.zeroToSixty),
                        highlight: displaySpecs?.zeroToSixty != nil && displaySpecs?.zeroToSixty != "N/A"
                    )
                    statItem(
                        label: "TOP",
                        value: parseIntValue(displaySpecs?.topSpeed),
                        highlight: displaySpecs?.topSpeed != nil && displaySpecs?.topSpeed != "N/A"
                    )
                }
                
                // Row 3: Details
                HStack(spacing: 12) {
                    statItem(
                        label: "ENGINE",
                        value: displaySpecs?.engine ?? "???",
                        highlight: displaySpecs?.engine != nil && displaySpecs?.engine != "N/A",
                        compact: true
                    )
                    statItem(
                        label: "DRIVE",
                        value: displaySpecs?.drivetrain ?? "???",
                        highlight: displaySpecs?.drivetrain != nil && displaySpecs?.drivetrain != "N/A",
                        compact: true
                    )
                }
            }
            .padding(.horizontal, 16)
            
            Divider()
                .background(.white.opacity(0.3))
                .padding(.vertical, 8)
            
            // NEW: Metadata section
            VStack(spacing: 4) {
                if let capturedBy = card.capturedBy {
                    Text("Captured by \(capturedBy)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                if let location = card.capturedLocation {
                    Text("Location: \(location)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                if card.previousOwners > 0 {
                    Text("Previous Owners: \(card.previousOwners)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.bottom, 8)
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
    
    // MARK: - Helper Functions to Parse VehicleSpecs Strings
    
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
    
    // Specs loading view
    private var specsLoadingView: some View {
        VStack {
            ProgressView()
                .tint(.white)
            Text("Loading specs...")
                .font(.caption)
                .foregroundStyle(.white)
        }
        .frame(width: 280, height: 157.5)
        .background(
            LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.8)],
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
    private func statItem(label: String, value: String, highlight: Bool, compact: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value.isEmpty ? "???" : value)
                .font(.system(size: compact ? 11 : 16, weight: .bold))
                .foregroundStyle(highlight ? .white : .white.opacity(0.4))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 4 : 6)
        .background(highlight ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Listing Form
    
    private var listingFormView: some View {
        Color.black.opacity(0.9)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 20) {
                    Text("Create Listing")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    TextField("Min Starting Bid", text: $minStartBid)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(.white.opacity(0.1))
                        .cornerRadius(10)
                    
                    TextField("Buy Now Price", text: $buyNowPrice)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(.white.opacity(0.1))
                        .cornerRadius(10)
                    
                    Picker("Duration (hours)", selection: $selectedDuration) {
                        ForEach(durations, id: \.self) { duration in
                            Text("\(duration)h").tag(duration)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showListingForm = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.gray)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                        
                        Button("Create") {
                            Task {
                                await createListing()
                            }
                        }
                        .disabled(!isFormValid || isCreating)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? .blue : .gray)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(.white.opacity(0.05))
                .cornerRadius(16)
                .padding()
            )
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
                showListingForm = false
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
