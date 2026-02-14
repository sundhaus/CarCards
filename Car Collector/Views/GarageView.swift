//
//  GarageView.swift
//  CarCardCollector
//
//  Simple garage page
//

import SwiftUI

struct GarageView: View {
    @State private var showCamera = false
    @State private var allCards: [AnyCard] = []
    @State private var cardsPerRow = 2 // 1 or 2
    
    var body: some View {
        NavigationStack {
            VStack {
                if allCards.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Your collection will appear here")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 100)
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: cardsPerRow), spacing: 15) {
                            ForEach(allCards) { card in
                                UnifiedCardView(card: card, isLargeSize: cardsPerRow == 1)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("GARAGE")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        cardsPerRow = cardsPerRow == 1 ? 2 : 1
                    }) {
                        Image(systemName: cardsPerRow == 1 ? "square.grid.2x2" : "rectangle")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .onAppear {
                loadAllCards()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CardSaved"))) { _ in
                print("📬 Garage received card saved notification")
                loadAllCards()
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(
                    isPresented: $showCamera,
                    onCardSaved: { card in
                        showCamera = false
                        loadAllCards() // Reload after new card
                    }
                )
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }
    
    private func loadAllCards() {
        var cards: [AnyCard] = []
        
        // Load vehicle cards
        let vehicleCards = CardStorage.loadCards()
        cards.append(contentsOf: vehicleCards.map { AnyCard.vehicle($0) })
        
        // Load driver cards
        let driverCards = CardStorage.loadDriverCards()
        cards.append(contentsOf: driverCards.map { AnyCard.driver($0) })
        
        // Load location cards
        let locationCards = CardStorage.loadLocationCards()
        cards.append(contentsOf: locationCards.map { AnyCard.location($0) })
        
        // Sort by date (newest first)
        allCards = cards.sorted { card1, card2 in
            card1.capturedDate > card2.capturedDate
        }
        
        print("📦 Loaded \(vehicleCards.count) vehicles, \(driverCards.count) drivers, \(locationCards.count) locations")
    }
}

// View to display any card type
struct UnifiedCardView: View {
    let card: AnyCard
    let isLargeSize: Bool
    
    var body: some View {
        ZStack {
            // Custom frame/border (only for vehicle cards)
            if let frameName = card.customFrame, frameName != "None" {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(frameName == "White" ? Color.white : Color.black, lineWidth: isLargeSize ? 6 : 3)
                    .frame(width: isLargeSize ? 360 : 175, height: isLargeSize ? 202.5 : 98.4)
            }
            
            // Card image
            if let image = card.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: isLargeSize ? 348 : 169, height: isLargeSize ? 195.75 : 92.4)
                    .clipped()
            }
            
            // Card overlay with title and type badge
            VStack {
                // Type badge in top-left
                HStack {
                    Text(card.cardType)
                        .font(.system(size: isLargeSize ? 10 : 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, isLargeSize ? 8 : 6)
                        .padding(.vertical, isLargeSize ? 4 : 3)
                        .background(typeColor.opacity(0.9))
                        .cornerRadius(isLargeSize ? 6 : 4)
                    Spacer()
                }
                .padding(isLargeSize ? 8 : 6)
                
                Spacer()
                
                // Title and subtitle at bottom
                VStack(spacing: 2) {
                    Text(card.displayTitle)
                        .font(isLargeSize ? .headline : .caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    if let subtitle = card.displaySubtitle {
                        Text(subtitle)
                            .font(isLargeSize ? .caption : .caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(isLargeSize ? 10 : 6)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.6))
            }
            .frame(width: isLargeSize ? 348 : 169, height: isLargeSize ? 195.75 : 92.4)
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var typeColor: Color {
        switch card.cardType {
        case "Vehicle": return .blue
        case "Driver": return .purple
        case "Location": return .green
        default: return .gray
        }
    }
}

// Keep old SavedCardView for backward compatibility
struct SavedCardView: View {
    let card: SavedCard
    let isLargeSize: Bool
    
    var body: some View {
        UnifiedCardView(card: .vehicle(card), isLargeSize: isLargeSize)
    }
}

#Preview {
    GarageView()
}
