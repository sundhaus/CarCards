//
//  MarketplaceSearchResultsView.swift
//  CarCardCollector
//
//  Shows filtered marketplace listings from the search filter page
//

import SwiftUI

struct MarketplaceSearchResultsView: View {
    let listings: [CloudListing]
    let hasUnfilteredListings: Bool
    let filterSummary: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var useDoubleColumn = false
    @State private var selectedListing: CloudListing?
    
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
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RESULTS")
                            .font(.pTitle3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Text("\(listings.count) listing\(listings.count == 1 ? "" : "s") — \(filterSummary)")
                            .font(.pCaption)
                            .foregroundStyle(.secondary)
                    }
                    
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
                
                // Results
                BuyView(
                    activeListings: listings,
                    hasUnfilteredListings: hasUnfilteredListings,
                    useDoubleColumn: useDoubleColumn,
                    onListingSelected: { listing in
                        selectedListing = listing
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedListing) { listing in
            ListingDetailView(listing: listing)
        }
    }
}
