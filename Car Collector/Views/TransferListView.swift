//
//  TransferListView.swift
//  CarCardCollector
//
//  View for user's own marketplace listings (selling and sold)
//

import SwiftUI

struct TransferListView: View {
    var isLandscape: Bool = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var marketplaceService = MarketplaceService.shared
    
    // Calculate selling listings (active)
    private var sellingListings: [CloudListing] {
        marketplaceService.myListings.filter { $0.status == .active }
    }
    
    // Calculate sold listings
    private var soldListings: [CloudListing] {
        marketplaceService.myListings.filter { $0.status == .sold }
    }
    
    var body: some View {
        ZStack {
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header - compact with background extending to top
                ZStack(alignment: .bottom) {
                    // Background extends to top
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                    
                    // Content at bottom - compact
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                        
                        Text("Transfer List")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Color.clear
                            .frame(width: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .frame(height: 60)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Selling Section (Active Listings)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Selling (\(sellingListings.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if sellingListings.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.gray)
                                    Text("No active listings")
                                        .foregroundStyle(.secondary)
                                    Text("List cards from the marketplace")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .background(.white)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            } else {
                                ForEach(sellingListings) { listing in
                                    TransferListingCard(listing: listing)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Sold Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sold (\(soldListings.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if soldListings.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.gray)
                                    Text("No sold listings")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .background(.white)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            } else {
                                ForEach(soldListings) { listing in
                                    TransferListingCard(listing: listing)
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
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            // Listener already started in app startup
            print("📋 Transfer List - Selling: \(sellingListings.count), Sold: \(soldListings.count)")
            print("📋 Total myListings: \(marketplaceService.myListings.count)")
            if let uid = FirebaseManager.shared.currentUserId {
                print("📋 User ID: \(uid)")
                // Debug: print listing statuses
                for listing in marketplaceService.myListings {
                    print("  - \(listing.make) \(listing.model): \(listing.status.rawValue)")
                }
            }
        }
    }
}

// Listing card for Transfer List
struct TransferListingCard: View {
    let listing: CloudListing
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
    
    var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: listing.status == .active ? "clock.fill" : "checkmark.circle.fill")
                .font(.caption)
            Text(listing.status == .active ? timeRemaining : "Sold")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(listing.status == .active ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
        .foregroundStyle(listing.status == .active ? .orange : .green)
        .cornerRadius(8)
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                                ProgressView()
                            }
                    }
                    
                    // Custom frame/border overlay
                    if let frameName = listing.customFrame, frameName != "None" {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                frameName == "White" ? Color.white : Color.black,
                                lineWidth: 2
                            )
                            .frame(width: 80, height: 80)
                    }
                }
                
                // Card details
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(listing.year) \(listing.make)")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(listing.model)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // Show current bid or "No bids"
                        if listing.currentBid > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "hammer.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("\(Int(listing.currentBid))")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(.gray)
                                    .font(.caption)
                                Text("No bids")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Buy now price
                        HStack(spacing: 4) {
                            Image(systemName: "cart.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("\(Int(listing.buyNowPrice))")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                Spacer()
                
                statusBadge
            }
            .padding(12)
        }
        .background(Color(.systemGray6))
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
    TransferListView()
}
