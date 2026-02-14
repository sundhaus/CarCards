//
//  ListingFormView.swift
//  CarCardCollector
//
//  Form for listing a card for sale - UPDATED to use Firebase
//

import SwiftUI

struct ListingFormView: View {
    let card: SavedCard
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var minStartBid = ""
    @State private var buyNowPrice = ""
    @State private var selectedDuration = 24
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
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Card preview
                    if let image = card.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360, height: 202.5)
                            .clipped()
                            .cornerRadius(12)
                    }
                    
                    // Listing form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Min Start Bid")
                                .font(.headline)
                            TextField("0", text: $minStartBid)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Buy Now Price")
                                .font(.headline)
                            TextField("0", text: $buyNowPrice)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration")
                                .font(.headline)
                            Picker("Duration", selection: $selectedDuration) {
                                ForEach(durations, id: \.self) { hours in
                                    Text("\(hours) hours").tag(hours)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Buttons
                        HStack(spacing: 12) {
                            // Cancel button
                            Button(action: onCancel) {
                                Text("Cancel")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                            .disabled(isCreating)
                            
                            // List Card button - simplified to avoid type-checking timeout
                            createListingButton
                        }
                    }
                    .padding()
                    .background(.white)
                    .cornerRadius(16)
                }
                .padding()
                
                Spacer()
            }
        }
    }
    
    // Extracted to separate view to avoid type-checking timeout
    private var createListingButton: some View {
        Button(action: {
            Task {
                await createListing()
            }
        }) {
            if isCreating {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text("List Card")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .background(buttonBackground)
        .cornerRadius(12)
        .disabled(!isFormValid || isCreating)
    }
    
    private var buttonBackground: Color {
        if isFormValid && !isCreating {
            return .blue
        } else {
            return .gray
        }
    }
    
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
                    domain: "ListingForm",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Card not found in cloud storage. Please try again."]
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
            
            // Success - close the form
            await MainActor.run {
                isCreating = false
                onConfirm()
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
    // Create a dummy image for preview
    let dummyImage = UIImage(systemName: "car.fill")!
    
    ListingFormView(
        card: SavedCard(
            id: UUID(),
            image: dummyImage,
            make: "Toyota",
            model: "Supra",
            color: "Red",
            year: "1998"
        ),
        onConfirm: {},
        onCancel: {}
    )
}
