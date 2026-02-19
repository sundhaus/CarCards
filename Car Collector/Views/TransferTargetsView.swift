//
//  TransferTargetsView.swift
//  CarCardCollector
//
//  View for cards the user is bidding on
//

import SwiftUI

struct TransferTargetsView: View {
    var isLandscape: Bool = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var marketplaceService = MarketplaceService.shared
    
    // Calculate winning bids from marketplace service
    private var winningBids: [CloudListing] {
        guard let uid = FirebaseManager.shared.currentUserId else { return [] }
        return marketplaceService.myBids.filter { $0.currentBidderId == uid }
    }
    
    // Outbid cards - would need bid history tracking to implement properly
    // For now, this will always be empty
    private var outbidCards: [CloudListing] {
        return []
    }
    
    var body: some View {
        ZStack {
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    
                    Text("TRANSFER TARGETS")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Winning Bids Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Winning (\(winningBids.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if winningBids.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "trophy")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.gray)
                                    Text("No winning bids")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .background(.white)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            } else {
                                ForEach(winningBids) { listing in
                                    ListingCardView(listing: listing, showActions: false)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Outbid Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Outbid (\(outbidCards.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if outbidCards.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.gray)
                                    Text("No outbid cards")
                                        .foregroundStyle(.secondary)
                                    Text("Bid history tracking coming soon")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .background(.white)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            } else {
                                ForEach(outbidCards) { listing in
                                    ListingCardView(listing: listing, showActions: false)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding(.bottom, isLandscape ? 0 : 80)
            .padding(.trailing, isLandscape ? 100 : 0)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Start listening to bids
            if let uid = FirebaseManager.shared.currentUserId {
                marketplaceService.listenToMyBids(uid: uid)
            }
        }
    }
}

// Simple listing card view for targets
struct ListingCardView: View {
    let listing: CloudListing
    var showActions: Bool = true
    
    @State private var cardImage: UIImage?
    
    var timeRemaining: String {
        let now = Date()
        let remaining = listing.expirationDate.timeIntervalSince(now)
        
        if remaining <= 0 {
            return "Expired"
        }
        
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Car image with frame
            ZStack {
                if let image = cardImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "car.fill")
                                .foregroundStyle(.gray)
                        }
                }
                
                // PNG border overlay based on customFrame
                if let borderImageName = CardBorderConfig.forFrame(listing.customFrame).borderImageName {
                    Image(borderImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .allowsHitTesting(false)
                }
            }
            
            // Card details
            VStack(alignment: .leading, spacing: 4) {
                Text("\(listing.year) \(listing.make)")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(listing.model.uppercased())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("\(Int(listing.currentBid))")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text(timeRemaining)
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(.white)
        .cornerRadius(12)
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard !listing.imageURL.isEmpty else { return }
        
        do {
            let image = try await CardService.shared.loadImage(from: listing.imageURL)
            await MainActor.run {
                cardImage = image
            }
        } catch {
            print("❌ Failed to load listing image: \(error)")
        }
    }
}

#Preview {
    TransferTargetsView()
}
