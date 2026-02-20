//
//  ListingDetailView.swift
//  CarCardCollector
//
//  Detail view for a marketplace listing — view, bid, or buy now
//

import SwiftUI

struct ListingDetailView: View {
    let listing: CloudListing
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var marketplaceService = MarketplaceService.shared
    
    @State private var bidAmount: String = ""
    @State private var cardImage: UIImage?
    @State private var isPlacingBid = false
    @State private var isBuyingNow = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showBuyConfirm = false
    
    private var isOwnListing: Bool {
        listing.sellerId == FirebaseManager.shared.currentUserId
    }
    
    private var minimumBid: Int {
        let current = Int(listing.currentBid)
        let minStart = Int(listing.minStartBid)
        return max(current + 1, minStart)
    }
    
    private var currentUserIsWinning: Bool {
        listing.currentBidderId == FirebaseManager.shared.currentUserId
    }
    
    var body: some View {
        ZStack {
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
                            )
                    }
                    
                    Spacer()
                    
                    Text("LISTING")
                        .font(.pBody)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Time remaining badge
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.pCaption2)
                        Text(listing.timeRemaining)
                            .font(.pCaption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(listing.isExpired ? Color.red.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundStyle(listing.isExpired ? .red : .orange)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)
                
                // Card + pricing as one joined unit
                ZStack(alignment: .bottom) {
                    // Pricing container — extends up behind the card
                    VStack {
                        Spacer()
                        pricingSection
                    }
                    
                    // Card image on top, with bottom padding to reveal pricing below
                    cardImageSection
                        .padding(.bottom, 70)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Bid / Buy section (not for own listings)
                if !isOwnListing && !listing.isExpired {
                    actionSection
                        .padding(.horizontal)
                        .padding(.top, 16)
                } else if isOwnListing {
                    ownerSection
                        .padding(.top, 16)
                }
                
                Spacer()
                
                // Seller info pinned to bottom
                sellerSection
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .alert("ERROR", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("SUCCESS", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(successMessage)
        }
        .alert("CONFIRM PURCHASE", isPresented: $showBuyConfirm) {
            Button("CANCEL", role: .cancel) {}
            Button("BUY NOW") {
                Task { await performBuyNow() }
            }
        } message: {
            Text("Buy \(listing.make) \(listing.model) for $\(Int(listing.buyNowPrice)) coins?")
        }
        .task {
            await loadImage()
        }
    }
    
    // MARK: - Card Image
    
    private var cardImageSection: some View {
        ZStack {
            if let image = cardImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .clipped()
            } else {
                ProgressView()
                    .tint(.gray)
                    .frame(height: 220)
            }
            
            // Border overlay
            if let borderImageName = CardBorderConfig.forFrame(listing.customFrame).borderImageName {
                Image(borderImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .allowsHitTesting(false)
            }
            
            // Make/Model overlay
            VStack {
                HStack {
                    let config = CardBorderConfig.forFrame(listing.customFrame)
                    Text(listing.make.uppercased())
                        .font(.custom("Futura-Light", size: 14))
                        .foregroundStyle(config.textColor)
                    Text(listing.model.uppercased())
                        .font(.custom("Futura-Bold", size: 14))
                        .foregroundStyle(config.textColor)
                    Spacer()
                }
                .padding(12)
                Spacer()
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipped()
    }
    
    // MARK: - Pricing
    
    private var pricingSection: some View {
        HStack(spacing: 0) {
            // Current Bid
            VStack(spacing: 6) {
                Text("CURRENT BID")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
                
                if listing.currentBid > 0 {
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.pCaption)
                            .foregroundStyle(.orange)
                        Text("\(Int(listing.currentBid))")
                            .font(.pTitle2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                    
                    if let bidder = listing.currentBidderUsername {
                        Text("by \(bidder)")
                            .font(.pCaption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if currentUserIsWinning {
                        Text("YOU'RE WINNING")
                            .font(.pCaption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                    }
                } else {
                    Text("No bids")
                        .font(.pBody)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 60)
            
            // Buy Now Price
            VStack(spacing: 6) {
                Text("BUY NOW")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Text("$")
                        .font(.pCaption)
                        .foregroundStyle(.green)
                    Text("\(Int(listing.buyNowPrice))")
                        .font(.pTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Action Section (Bid / Buy)
    
    private var actionSection: some View {
        VStack(spacing: 12) {
            // Bid input
            HStack(spacing: 12) {
                HStack {
                    Text("$")
                        .font(.pBody)
                        .foregroundStyle(.secondary)
                    TextField("Min \(minimumBid)", text: $bidAmount)
                        .font(.pBody)
                        .keyboardType(.numberPad)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                
                Button(action: {
                    Task { await performBid() }
                }) {
                    if isPlacingBid {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("BID")
                            .font(.pSubheadline)
                            .fontWeight(.bold)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.orange)
                .foregroundStyle(.white)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                .disabled(isPlacingBid || isBuyingNow)
            }
            
            // Buy Now button
            Button(action: {
                showBuyConfirm = true
            }) {
                if isBuyingNow {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.fill")
                        Text("BUY NOW — $\(Int(listing.buyNowPrice))")
                            .fontWeight(.bold)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.green)
            .foregroundStyle(.white)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .disabled(isPlacingBid || isBuyingNow)
        }
    }
    
    // MARK: - Owner Section
    
    private var ownerSection: some View {
        Button(action: {
            Task { await cancelListing() }
        }) {
            Text("CANCEL LISTING")
                .font(.pCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
                .glassEffect(.regular, in: .capsule)
        }
    }
    
    // MARK: - Seller Info
    
    private var sellerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SELLER")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
                Text(listing.sellerUsername)
                    .font(.pBody)
                    .fontWeight(.semibold)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("LISTED")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
                Text(listing.listingDate, style: .relative)
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 34)
        .background(.clear)
        .glassEffect(.regular, in: .rect)
    }
    
    // MARK: - Actions
    
    private func performBid() async {
        guard let amount = Int(bidAmount), amount >= minimumBid else {
            errorMessage = "Bid must be at least $\(minimumBid)"
            showError = true
            return
        }
        
        isPlacingBid = true
        do {
            try await marketplaceService.placeBid(listingId: listing.id, amount: Double(amount))
            successMessage = "Bid of $\(amount) placed!"
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isPlacingBid = false
    }
    
    private func performBuyNow() async {
        isBuyingNow = true
        do {
            try await marketplaceService.buyNow(listingId: listing.id)
            successMessage = "You bought \(listing.make) \(listing.model) for $\(Int(listing.buyNowPrice))!"
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isBuyingNow = false
    }
    
    private func cancelListing() async {
        do {
            try await marketplaceService.cancelListing(listingId: listing.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Load Image
    
    private func loadImage() async {
        guard !listing.imageURL.isEmpty else { return }
        do {
            let image = try await CardService.shared.loadImage(from: listing.imageURL)
            await MainActor.run { cardImage = image }
        } catch {
            print("❌ Failed to load listing image: \(error)")
        }
    }
}

// Preview not available — requires Firestore CloudListing
