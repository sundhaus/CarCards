//
//  GarageSearchView.swift
//  CarCardCollector
//
//  FIFA Club Search-style filter page for finding garage cards to list
//

import SwiftUI

struct GarageSearchView: View {
    @Environment(\.dismiss) private var dismiss
    var onCardListed: (() -> Void)? = nil
    
    // All local cards
    private var allCards: [SavedCard] {
        CardStorage.loadCards()
    }
    
    // Sort
    @State private var sortOption = "Newest First"
    private let sortOptions = ["Newest First", "Oldest First", "Make A-Z", "Make Z-A", "Year High to Low", "Year Low to High"]
    
    // Filter dropdowns
    @State private var filterMake = "Any"
    @State private var filterModel = "Any"
    @State private var filterYear = "Any"
    @State private var filterCategory = "Any"
    
    // Navigation
    @State private var showResults = false
    
    // MARK: - Computed filter options
    
    private var availableMakes: [String] {
        ["Any"] + Set(allCards.map { $0.make }).sorted()
    }
    
    private var availableModels: [String] {
        var cards = allCards
        if filterMake != "Any" { cards = cards.filter { $0.make == filterMake } }
        return ["Any"] + Set(cards.map { $0.model }).sorted()
    }
    
    private var availableYears: [String] {
        var cards = allCards
        if filterMake != "Any" { cards = cards.filter { $0.make == filterMake } }
        if filterModel != "Any" { cards = cards.filter { $0.model == filterModel } }
        return ["Any"] + Set(cards.map { $0.year }).sorted().reversed()
    }
    
    private var availableCategories: [String] {
        ["Any"] + VehicleCategory.allCases.map { $0.rawValue }
    }
    
    // Filtered results
    private var filteredCards: [SavedCard] {
        var cards = allCards
        
        if filterMake != "Any" { cards = cards.filter { $0.make == filterMake } }
        if filterModel != "Any" { cards = cards.filter { $0.model == filterModel } }
        if filterYear != "Any" { cards = cards.filter { $0.year == filterYear } }
        
        if filterCategory != "Any" {
            cards = cards.filter { $0.specs?.category?.rawValue == filterCategory }
        }
        
        return sortCards(cards)
    }
    
    var body: some View {
        NavigationStack {
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
                        
                        Text("GARAGE SEARCH")
                            .font(.pTitle3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Balance spacer
                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.horizontal)
                    .padding(.top, 18)
                    .padding(.bottom, 10)
                    
                    // Filters
                    ScrollView {
                        VStack(spacing: 14) {
                            // Sort By
                            sortSection
                            
                            // Filter pills — full width, single column
                            fullWidthPill(icon: "car.fill", label: "Make", value: filterMake, options: availableMakes) { val in
                                filterMake = val
                                filterModel = "Any"
                                filterYear = "Any"
                            }
                            
                            fullWidthPill(icon: "doc.text", label: "Model", value: filterModel, options: availableModels) { val in
                                filterModel = val
                                filterYear = "Any"
                            }
                            
                            fullWidthPill(icon: "calendar", label: "Generation", value: filterYear, options: availableYears) { val in
                                filterYear = val
                            }
                            
                            fullWidthPill(icon: "square.grid.2x2", label: "Category", value: filterCategory, options: availableCategories) { val in
                                filterCategory = val
                            }
                        }
                        .padding()
                        .padding(.bottom, 90)
                    }
                    
                    // Sticky bottom buttons
                    actionButtons
                }
            }
            .navigationDestination(isPresented: $showResults) {
                GarageSearchResultsView(
                    cards: filteredCards,
                    onCardListed: {
                        onCardListed?()
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Sort Section
    
    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sort By")
                .font(.pCaption)
                .foregroundStyle(.secondary)
            
            Menu {
                ForEach(sortOptions, id: \.self) { option in
                    Button(option) { sortOption = option }
                }
            } label: {
                HStack {
                    Text(sortOption)
                        .font(.pSubheadline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
            }
        }
    }
    
    // MARK: - Full Width Filter Pill
    
    private func fullWidthPill(
        icon: String,
        label: String,
        value: String,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        let isActive = value != "Any"
        let isDisabled = options.count <= 1
        
        return Menu {
            Button("Any") { onSelect("Any") }
            Divider()
            ForEach(options.filter { $0 != "Any" }, id: \.self) { option in
                Button(option) { onSelect(option) }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isActive ? .white : .secondary)
                    .frame(width: 24)
                
                Text(isActive ? value : label)
                    .font(.pSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isActive ? Color.white : isDisabled ? Color.secondary.opacity(0.4) : Color.secondary)
                
                Spacer()
                
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(isDisabled ? Color.secondary.opacity(0.3) : Color.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
        }
        .disabled(isDisabled)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: resetFilters) {
                Text("Reset")
                    .font(.pBody)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
            .foregroundStyle(.white)
            
            Button(action: { showResults = true }) {
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
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.appBackgroundSolid)
    }
    
    // MARK: - Helpers
    
    private func resetFilters() {
        sortOption = "Newest First"
        filterMake = "Any"
        filterModel = "Any"
        filterYear = "Any"
        filterCategory = "Any"
    }
    
    private func sortCards(_ cards: [SavedCard]) -> [SavedCard] {
        switch sortOption {
        case "Newest First": return cards
        case "Oldest First": return cards.reversed()
        case "Make A-Z": return cards.sorted { $0.make < $1.make }
        case "Make Z-A": return cards.sorted { $0.make > $1.make }
        case "Year High to Low": return cards.sorted { $0.year > $1.year }
        case "Year Low to High": return cards.sorted { $0.year < $1.year }
        default: return cards
        }
    }
}
