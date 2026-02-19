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
    @State private var useDoubleColumn = false
    
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
                            .font(.pTitle3)
                            .foregroundStyle(.primary)
                    }
                    
                    Text("TRANSFER TARGETS")
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
                        // Winning Bids Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Winning (\(winningBids.count))")
                                .font(.pHeadline)
                                .padding(.horizontal)
                            
                            if winningBids.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "trophy")
                                        .font(.poppins(50))
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("No winning bids")
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
                                    ForEach(winningBids) { listing in
                                        if useDoubleColumn {
                                            CompactTargetCard(listing: listing)
                                        } else {
                                            ListingCardView(listing: listing, showActions: false)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Outbid Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Outbid (\(outbidCards.count))")
                                .font(.pHeadline)
                                .padding(.horizontal)
                            
                            if outbidCards.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.poppins(50))
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("No outbid cards")
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text("Bid history tracking coming soon")
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
                                    ForEach(outbidCards) { listing in
                                        if useDoubleColumn {
                                            CompactTargetCard(listing: listing)
                                        } else {
                                            ListingCardView(listing: listing, showActions: false)
                                        }
                                    }
                                }
                                .padding(.horizontal)
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
                    .font(.pHeadline)
                    .lineLimit(1)
                
                Text(listing.model.uppercased())
                    .font(.pSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(.green)
                            .font(.pCaption)
                        Text("\(Int(listing.currentBid))")
                            .font(.pCaption)
                            .fontWeight(.semibold)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.orange)
                            .font(.pCaption)
                        Text(timeRemaining)
                            .font(.pCaption)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
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

// Compact target card for double column mode
struct CompactTargetCard: View {
    let listing: CloudListing
    @State private var cardImage: UIImage?
    
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
                    Image(systemName: "car.fill")
                        .font(.poppins(24))
                        .foregroundStyle(.gray.opacity(0.4))
                }
                
                if let borderImageName = CardBorderConfig.forFrame(listing.customFrame).borderImageName {
                    Image(borderImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Info bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(listing.make) \(listing.model)")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text("\(Int(listing.currentBid))")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
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
    TransferTargetsView()
}
