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
    private let sortOptions = ["Newest First", "Oldest First", "Make A-Z", "Make Z-A", "Year High to Low", "Year Low to High", "HP High to Low", "HP Low to High"]
    
    // HP Range
    @State private var hpMin: Double = 0
    @State private var hpMax: Double = 2000
    @State private var hpRange: ClosedRange<Double> = 0...2000
    
    // Search text
    @State private var searchText = ""
    
    // Filter dropdowns
    @State private var filterMake = "Any"
    @State private var filterModel = "Any"
    @State private var filterYear = "Any"
    @State private var filterColor = "Any"
    @State private var filterDrivetrain = "Any"
    @State private var filterEngine = "Any"
    
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
    
    private var availableColors: [String] {
        ["Any"] + Set(allCards.map { $0.color }).sorted()
    }
    
    private var availableDrivetrains: [String] {
        let drivetrains = allCards.compactMap { $0.specs?.drivetrain }.filter { $0 != "N/A" }
        return ["Any"] + Set(drivetrains).sorted()
    }
    
    private var availableEngines: [String] {
        let engines = allCards.compactMap { $0.specs?.engine }.filter { $0 != "N/A" }
        // Simplify engine types
        let simplified = Set(engines.map { simplifyEngine($0) }).sorted()
        return ["Any"] + simplified
    }
    
    // Actual HP bounds from garage
    private var hpBounds: (min: Double, max: Double) {
        let hps = allCards.compactMap { $0.parseHP() }
        guard !hps.isEmpty else { return (0, 2000) }
        return (Double(hps.min()!), Double(hps.max()!))
    }
    
    // Filtered results
    private var filteredCards: [SavedCard] {
        var cards = allCards
        
        // Text search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            cards = cards.filter {
                $0.make.lowercased().contains(query) ||
                $0.model.lowercased().contains(query)
            }
        }
        
        // Dropdown filters
        if filterMake != "Any" { cards = cards.filter { $0.make == filterMake } }
        if filterModel != "Any" { cards = cards.filter { $0.model == filterModel } }
        if filterYear != "Any" { cards = cards.filter { $0.year == filterYear } }
        if filterColor != "Any" { cards = cards.filter { $0.color == filterColor } }
        
        if filterDrivetrain != "Any" {
            cards = cards.filter { ($0.specs?.drivetrain ?? "N/A") == filterDrivetrain }
        }
        
        if filterEngine != "Any" {
            cards = cards.filter { simplifyEngine($0.specs?.engine ?? "") == filterEngine }
        }
        
        // HP range
        let bounds = hpBounds
        if hpMin > bounds.min || hpMax < bounds.max {
            cards = cards.filter { card in
                guard let hp = card.parseHP() else { return true }
                return Double(hp) >= hpMin && Double(hp) <= hpMax
            }
        }
        
        // Sort
        cards = sortCards(cards)
        
        return cards
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
                    
                    // Subtitle
                    Text("Garage Search")
                        .font(.pBody)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .rect)
                    
                    // Filters — scrollable
                    ScrollView {
                        VStack(spacing: 14) {
                            // Sort By
                            sortSection
                            
                            // HP Range
                            hpRangeSection
                            
                            // Search bar
                            searchBarSection
                            
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
                            
                            fullWidthPill(icon: "calendar", label: "Year", value: filterYear, options: availableYears) { val in
                                filterYear = val
                            }
                            
                            fullWidthPill(icon: "paintpalette", label: "Color", value: filterColor, options: availableColors) { val in
                                filterColor = val
                            }
                            
                            fullWidthPill(icon: "gear.circle", label: "Drivetrain", value: filterDrivetrain, options: availableDrivetrains) { val in
                                filterDrivetrain = val
                            }
                            
                            fullWidthPill(icon: "engine.combustion", label: "Engine", value: filterEngine, options: availableEngines) { val in
                                filterEngine = val
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
            .onAppear {
                // Initialize HP range from actual data
                let bounds = hpBounds
                hpMin = bounds.min
                hpMax = bounds.max
                hpRange = bounds.min...bounds.max
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
    
    // MARK: - HP Range Section
    
    private var hpRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HP Range")
                .font(.pCaption)
                .foregroundStyle(.secondary)
            
            let bounds = hpBounds
            Text("The HP ranges from \(Int(bounds.min))-\(Int(bounds.max))")
                .font(.pCaption2)
                .foregroundStyle(.secondary.opacity(0.7))
            
            // Dual slider
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let range = bounds.max - bounds.min
                let safeDivisor = max(range, 1)
                
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 4)
                    
                    // Active track
                    let minX = (hpMin - bounds.min) / safeDivisor * totalWidth
                    let maxX = (hpMax - bounds.min) / safeDivisor * totalWidth
                    
                    Capsule()
                        .fill(.white)
                        .frame(width: max(0, maxX - minX), height: 4)
                        .offset(x: minX)
                    
                    // Min thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(radius: 2)
                        .offset(x: minX - 11)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let pct = max(0, min(1, value.location.x / totalWidth))
                                    let newMin = bounds.min + pct * range
                                    hpMin = min(newMin, hpMax - 10)
                                }
                        )
                    
                    // Max thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(radius: 2)
                        .offset(x: maxX - 11)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let pct = max(0, min(1, value.location.x / totalWidth))
                                    let newMax = bounds.min + pct * range
                                    hpMax = max(newMax, hpMin + 10)
                                }
                        )
                }
            }
            .frame(height: 30)
            .padding(.vertical, 4)
            
            // Min / Max fields
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min HP")
                        .font(.pCaption2)
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int(hpMin))")
                        .font(.pBody)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max HP")
                        .font(.pCaption2)
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int(hpMax))")
                        .font(.pBody)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBarSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.pTitle3)
                .foregroundStyle(.secondary)
            
            TextField("Type Make or Model", text: $searchText)
                .font(.pBody)
                .foregroundStyle(.white)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
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
                    .foregroundStyle(isActive ? .white : isDisabled ? .secondary.opacity(0.4) : .secondary)
                
                Spacer()
                
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(isDisabled ? .secondary.opacity(0.3) : .secondary)
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
        searchText = ""
        filterMake = "Any"
        filterModel = "Any"
        filterYear = "Any"
        filterColor = "Any"
        filterDrivetrain = "Any"
        filterEngine = "Any"
        let bounds = hpBounds
        hpMin = bounds.min
        hpMax = bounds.max
    }
    
    private func sortCards(_ cards: [SavedCard]) -> [SavedCard] {
        switch sortOption {
        case "Newest First": return cards // Already in storage order (newest)
        case "Oldest First": return cards.reversed()
        case "Make A-Z": return cards.sorted { $0.make < $1.make }
        case "Make Z-A": return cards.sorted { $0.make > $1.make }
        case "Year High to Low": return cards.sorted { ($0.year) > ($1.year) }
        case "Year Low to High": return cards.sorted { ($0.year) < ($1.year) }
        case "HP High to Low": return cards.sorted { ($0.parseHP() ?? 0) > ($1.parseHP() ?? 0) }
        case "HP Low to High": return cards.sorted { ($0.parseHP() ?? 0) < ($1.parseHP() ?? 0) }
        default: return cards
        }
    }
    
    private func simplifyEngine(_ engine: String) -> String {
        let lower = engine.lowercased()
        if lower.contains("v12") { return "V12" }
        if lower.contains("v10") { return "V10" }
        if lower.contains("v8") { return "V8" }
        if lower.contains("v6") { return "V6" }
        if lower.contains("inline-6") || lower.contains("i6") || lower.contains("straight-6") { return "I6" }
        if lower.contains("inline-4") || lower.contains("i4") || lower.contains("4-cylinder") { return "I4" }
        if lower.contains("flat") || lower.contains("boxer") { return "Boxer" }
        if lower.contains("electric") { return "Electric" }
        if lower.contains("hybrid") { return "Hybrid" }
        if lower.contains("rotary") || lower.contains("wankel") { return "Rotary" }
        if lower.contains("w16") { return "W16" }
        if lower.contains("w12") { return "W12" }
        return engine
    }
}
