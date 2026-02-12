//
//  GarageView.swift
//  CarCardCollector
//
//  Simple garage page
//

import SwiftUI

struct GarageView: View {
    @State private var showCamera = false
    @State private var savedCards: [SavedCard] = []
    @State private var cardsPerRow = 2 // 1 or 2
    
    var body: some View {
        NavigationStack {
            VStack {
                if savedCards.isEmpty {
                    Text("Your collection will appear here")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: cardsPerRow), spacing: 15) {
                            ForEach(savedCards) { card in
                                SavedCardView(card: card, isLargeSize: cardsPerRow == 1)
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
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(
                    isPresented: $showCamera,
                    onCardSaved: { card in
                        savedCards.append(card)
                        showCamera = false
                    }
                )
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

// View to display a saved card
struct SavedCardView: View {
    let card: SavedCard
    let isLargeSize: Bool
    
    var body: some View {
        ZStack {
            if let image = card.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: isLargeSize ? 360 : 175, height: isLargeSize ? 202.5 : 98.4)
                    .clipped()
            }
            
            // Card overlay
            VStack {
                Spacer()
                Text("\(card.make) \(card.model)")
                    .font(isLargeSize ? .headline : .caption)
                    .foregroundStyle(.white)
                    .padding(isLargeSize ? 10 : 6)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.6))
            }
            .frame(width: isLargeSize ? 360 : 175, height: isLargeSize ? 202.5 : 98.4)
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    GarageView()
}
