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
    @State private var useDoubleColumn = false
    @State private var selectedListing: CloudListing?
    
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
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.pTitle3)
                            .foregroundStyle(.primary)
                    }
                    
                    Text("TRANSFER LIST")
                        .font(.pTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            useDoubleColumn.toggle()
                        }
                    }) {
                        Image(systemName: useDoubleColumn ? "square.grid.2x2" : "rectangle.grid.1x2")
                            .font(.pTitle3)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 18)
                .padding(.bottom, 10)
                .glassEffect(.regular, in: .rect)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Selling Section (Active Listings)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SELLING (\(sellingListings.count))")
                                .font(.pHeadline)
                                .padding(.horizontal)
                            
                            if sellingListings.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "tag")
                                        .font(.poppins(50))
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("No active listings")
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text("List cards from the marketplace")
                                        .font(.pCaption)
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .padding(.horizontal)
                            } else {
                                let columns = useDoubleColumn
                                    ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                                    : [GridItem(.flexible())]
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(sellingListings) { listing in
                                        Group {
                                            if useDoubleColumn {
                                                CompactTransferListingCard(listing: listing)
                                            } else {
                                                TransferListingCard(listing: listing)
                                            }
                                        }
                                        .onTapGesture {
                                            selectedListing = listing
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Sold Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SOLD (\(soldListings.count))")
                                .font(.pHeadline)
                                .padding(.horizontal)
                            
                            if soldListings.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.poppins(50))
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("No sold listings")
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .padding(.horizontal)
                            } else {
                                let columns = useDoubleColumn
                                    ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                                    : [GridItem(.flexible())]
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(soldListings) { listing in
                                        Group {
                                            if useDoubleColumn {
                                                CompactTransferListingCard(listing: listing)
                                            } else {
                                                TransferListingCard(listing: listing)
                                            }
                                        }
                                        .onTapGesture {
                                            selectedListing = listing
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                    .padding(.bottom, isLandscape ? 0 : 80)
                }
            }
            .padding(.trailing, isLandscape ? 100 : 0)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedListing) { listing in
            ListingDetailView(listing: listing)
        }
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
        if remaining <= 0 { return "Expired" }
        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    private var statusColor: Color {
        if listing.status == .sold { return .green }
        return listing.isExpired ? .red : .orange
    }
    
    private var statusText: String {
        if listing.status == .sold { return "Sold" }
        return timeRemaining
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top: image + name + status
            HStack(spacing: 12) {
                // Card thumbnail
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
                            .overlay { ProgressView() }
                    }
                    
                    if let borderImageName = CardBorderConfig.forFrame(listing.customFrame).borderImageName {
                        Image(borderImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .allowsHitTesting(false)
                    }
                }
                
                // Name + status inline
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(listing.make) \(listing.model)")
                            .font(.pHeadline)
                            .lineLimit(1)
                        
                        // Status badge inline
                        HStack(spacing: 3) {
                            Image(systemName: listing.status == .sold ? "checkmark.circle.fill" : "clock.fill")
                                .font(.system(size: 9))
                            Text(statusText)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.2))
                        .foregroundStyle(statusColor)
                        .cornerRadius(6)
                    }
                    
                    Text(listing.year)
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            
            // Bottom: Current Bid | Buy Now — full width
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("CURRENT BID")
                        .font(.pCaption2)
                        .foregroundStyle(.secondary)
                    Text(listing.currentBid > 0 ? "$\(Int(listing.currentBid))" : "None")
                        .font(.pHeadline)
                        .fontWeight(.bold)
                        .foregroundStyle(listing.currentBid > 0 ? .orange : .secondary)
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 36)
                
                VStack(spacing: 4) {
                    Text("BUY NOW")
                        .font(.pCaption2)
                        .foregroundStyle(.secondary)
                    Text("$\(Int(listing.buyNowPrice))")
                        .font(.pHeadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 10)
        }
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .task { await loadImage() }
    }
    
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

// Compact listing card for double column mode
struct CompactTransferListingCard: View {
    let listing: CloudListing
    @State private var cardImage: UIImage?
    
    private var statusColor: Color {
        if listing.status == .sold { return .green }
        return listing.isExpired ? .red : .orange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Card image
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.85, green: 0.85, blue: 0.88))
                
                if let image = cardImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ProgressView().tint(.gray)
                }
                
                if let borderImageName = CardBorderConfig.forFrame(listing.customFrame).borderImageName {
                    Image(borderImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                
                // Status badge overlay
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: listing.status == .sold ? "checkmark.circle.fill" : "clock.fill")
                                .font(.system(size: 8))
                            Text(listing.status == .sold ? "Sold" : (listing.isExpired ? "Expired" : "Active"))
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.8))
                        .foregroundStyle(.white)
                        .cornerRadius(6)
                        .padding(6)
                    }
                    Spacer()
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Name
            HStack {
                Text("\(listing.make) \(listing.model)")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            // Current Bid | Buy Now
            HStack(spacing: 0) {
                VStack(spacing: 1) {
                    Text("BID")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(listing.currentBid > 0 ? "$\(Int(listing.currentBid))" : "None")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(listing.currentBid > 0 ? .orange : .secondary)
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 22)
                
                VStack(spacing: 1) {
                    Text("BUY")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text("$\(Int(listing.buyNowPrice))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)
        }
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .task { await loadImage() }
    }
    
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

#Preview {
    TransferListView()
}
