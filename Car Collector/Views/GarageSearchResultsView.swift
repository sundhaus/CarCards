//
//  GarageSearchResultsView.swift
//  CarCardCollector
//
//  Shows filtered garage cards from the search — tap a card to list it
//

import SwiftUI

struct GarageSearchResultsView: View {
    let cards: [SavedCard]
    var onCardListed: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCard: SavedCard?
    @State private var useDoubleColumn = false
    
    private var gridColumns: [GridItem] {
        if useDoubleColumn {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        } else {
            return [GridItem(.flexible())]
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
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SELECT A CARD")
                            .font(.pTitle3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        
                        Text("\(cards.count) card\(cards.count == 1 ? "" : "s") found")
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
                
                // Card grid
                ScrollView {
                    if cards.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "square.stack.3d.up.slash")
                                .font(.system(size: 50))
                                .foregroundStyle(.gray)
                            Text("No cards match your filters")
                                .font(.pTitle3)
                                .foregroundStyle(.secondary)
                            Text("Try adjusting your search criteria")
                                .font(.pCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(minHeight: 300)
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(cards) { card in
                                GarageResultCard(card: card)
                                    .onTapGesture {
                                        selectedCard = card
                                    }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedCard) { card in
            CardDetailsView(
                card: card,
                onDismiss: {
                    selectedCard = nil
                },
                onListed: {
                    selectedCard = nil
                    onCardListed?()
                },
                onComparePrice: {
                    // Not needed in sell flow
                    selectedCard = nil
                }
            )
        }
    }
}

// MARK: - Garage Result Card

struct GarageResultCard: View {
    let card: SavedCard
    
    var body: some View {
        let cardHeight: CGFloat = 202.5
        let cardWidth = cardHeight * 16 / 9
        
        Group {
            if let rendered = CardRenderer.shared.landscapeCard(for: card.asAnyCard, height: 400) {
                Image(uiImage: rendered)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: cardWidth, height: cardHeight)
            } else {
                RoundedRectangle(cornerRadius: cardHeight * 0.09)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: cardWidth, height: cardHeight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
}
