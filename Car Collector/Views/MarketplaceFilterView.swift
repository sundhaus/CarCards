//
//  MarketplaceFilterView.swift
//  CarCardCollector
//
//  FIFA-style marketplace search filter page
//

import SwiftUI

struct MarketplaceFilterView: View {
    var isLandscape: Bool = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var marketplaceService = MarketplaceService.shared
    
    // Filter state
    @State private var filterMake = "Any"
    @State private var filterModel = "Any"
    @State private var filterYear = "Any"
    @State private var bidMinPrice = ""
    @State private var bidMaxPrice = ""
    @State private var buyMinPrice = ""
    @State private var buyMaxPrice = ""
    
    // Navigation
    @State private var showResults = false
    
    // Computed filter options from active listings
    private var availableMakes: [String] {
        let makes = Set(marketplaceService.activeListings.map { $0.make })
        return ["Any"] + makes.sorted()
    }
    
    private var availableModels: [String] {
        if filterMake == "Any" {
            let models = Set(marketplaceService.activeListings.map { $0.model })
            return ["Any"] + models.sorted()
        } else {
            let models = Set(marketplaceService.activeListings.filter { $0.make == filterMake }.map { $0.model })
            return ["Any"] + models.sorted()
        }
    }
    
    private var availableYears: [String] {
        var filtered = marketplaceService.activeListings
        if filterMake != "Any" { filtered = filtered.filter { $0.make == filterMake } }
        if filterModel != "Any" { filtered = filtered.filter { $0.model == filterModel } }
        let years = Set(filtered.map { $0.year })
        return ["Any"] + years.sorted()
    }
    
    // Apply all filters
    private var filteredListings: [CloudListing] {
        marketplaceService.activeListings.filter { listing in
            if filterMake != "Any" && listing.make != filterMake { return false }
            if filterModel != "Any" && listing.model != filterModel { return false }
            if filterYear != "Any" && listing.year != filterYear { return false }
            if let min = Double(bidMinPrice), listing.currentBid < min && listing.currentBid > 0 { return false }
            if let max = Double(bidMaxPrice), listing.currentBid > max { return false }
            if let min = Double(buyMinPrice), listing.buyNowPrice < min { return false }
            if let max = Double(buyMaxPrice), listing.buyNowPrice > max { return false }
            return true
        }
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
                    
                    Text("SEARCH THE MARKET")
                        .font(.pTitle3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 18)
                .padding(.bottom, 10)
                .glassEffect(.regular, in: .rect)
                
                // Filter content
                ScrollView {
                    VStack(spacing: 16) {
                        // Search by name
                        searchNameSection
                        
                        // Filter dropdowns — 2 column grid
                        filterDropdownGrid
                        
                        // Bid Price range
                        priceRangeSection(title: "Bid Price:", minBinding: $bidMinPrice, maxBinding: $bidMaxPrice)
                        
                        // Buy Now Price range
                        priceRangeSection(title: "Buy Now Price:", minBinding: $buyMinPrice, maxBinding: $buyMaxPrice)
                        
                        // Reset & Search buttons
                        actionButtons
                    }
                    .padding()
                    .padding(.bottom, isLandscape ? 0 : 80)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            marketplaceService.listenToActiveListings()
        }
        .navigationDestination(isPresented: $showResults) {
            MarketplaceSearchResultsView(
                listings: filteredListings,
                hasUnfilteredListings: !marketplaceService.activeListings.isEmpty,
                filterSummary: buildFilterSummary()
            )
        }
    }
    
    // MARK: - Search Name Section
    
    private var searchNameSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.pTitle3)
                .foregroundStyle(.secondary)
            
            Text("Search by Make or Model")
                .font(.pBody)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
    
    // MARK: - Filter Dropdown Grid
    
    private var filterDropdownGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                filterPill(
                    icon: "car.fill",
                    label: filterMake == "Any" ? "Make" : filterMake,
                    isActive: filterMake != "Any",
                    options: availableMakes,
                    onSelect: { make in
                        filterMake = make
                        filterModel = "Any"
                        filterYear = "Any"
                    }
                )
                
                filterPill(
                    icon: "doc.text",
                    label: filterModel == "Any" ? "Model" : filterModel,
                    isActive: filterModel != "Any",
                    options: availableModels,
                    onSelect: { model in
                        filterModel = model
                        filterYear = "Any"
                    }
                )
            }
            
            HStack(spacing: 10) {
                filterPill(
                    icon: "calendar",
                    label: filterYear == "Any" ? "Year" : filterYear,
                    isActive: filterYear != "Any",
                    options: availableYears,
                    onSelect: { year in
                        filterYear = year
                    }
                )
                
                // Placeholder for future filter
                Color.clear
                    .frame(height: 48)
            }
        }
    }
    
    // MARK: - Filter Pill
    
    private func filterPill(
        icon: String,
        label: String,
        isActive: Bool,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            Button("Any") { onSelect("Any") }
            Divider()
            ForEach(options.filter { $0 != "Any" }, id: \.self) { option in
                Button(option) { onSelect(option) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isActive ? .white : .secondary)
                
                Text(label)
                    .font(.pSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isActive ? .white : .secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
        }
    }
    
    // MARK: - Price Range Section
    
    private func priceRangeSection(title: String, minBinding: Binding<String>, maxBinding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.pBody)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !minBinding.wrappedValue.isEmpty || !maxBinding.wrappedValue.isEmpty {
                    Button("Clear") {
                        minBinding.wrappedValue = ""
                        maxBinding.wrappedValue = ""
                    }
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
                }
            }
            
            // Min
            VStack(alignment: .leading, spacing: 4) {
                Text("Min:")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    Button(action: {
                        let current = Int(minBinding.wrappedValue) ?? 0
                        if current > 0 {
                            minBinding.wrappedValue = "\(current - 100)"
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.pBody)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    
                    TextField("Any", text: minBinding)
                        .keyboardType(.numberPad)
                        .font(.pBody)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                    
                    Button(action: {
                        let current = Int(minBinding.wrappedValue) ?? 0
                        minBinding.wrappedValue = "\(current + 100)"
                    }) {
                        Image(systemName: "plus")
                            .font(.pBody)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            }
            
            // Max
            VStack(alignment: .leading, spacing: 4) {
                Text("Max:")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    Button(action: {
                        let current = Int(maxBinding.wrappedValue) ?? 0
                        if current > 0 {
                            maxBinding.wrappedValue = "\(current - 100)"
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.pBody)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    
                    TextField("Any", text: maxBinding)
                        .keyboardType(.numberPad)
                        .font(.pBody)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                    
                    Button(action: {
                        let current = Int(maxBinding.wrappedValue) ?? 0
                        maxBinding.wrappedValue = "\(current + 100)"
                    }) {
                        Image(systemName: "plus")
                            .font(.pBody)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Reset
            Button(action: resetFilters) {
                Text("Reset")
                    .font(.pBody)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
            .foregroundStyle(.white)
            
            // Search
            Button(action: {
                showResults = true
            }) {
                Text("Search")
                    .font(.pBody)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
            .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    
    private func resetFilters() {
        filterMake = "Any"
        filterModel = "Any"
        filterYear = "Any"
        bidMinPrice = ""
        bidMaxPrice = ""
        buyMinPrice = ""
        buyMaxPrice = ""
    }
    
    private func buildFilterSummary() -> String {
        var parts: [String] = []
        if filterMake != "Any" { parts.append(filterMake) }
        if filterModel != "Any" { parts.append(filterModel) }
        if filterYear != "Any" { parts.append(filterYear) }
        return parts.isEmpty ? "All Listings" : parts.joined(separator: " ")
    }
}
