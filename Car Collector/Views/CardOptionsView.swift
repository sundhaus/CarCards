//
//  CardOptionsView.swift
//  Car Collector
//
//  Full-screen card options popup with card preview and actions
//

import SwiftUI

struct CardOptionsView: View {
    let card: AnyCard
    let onQuickSell: () -> Void
    let onListOnMarket: () -> Void
    let onComparePrice: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showQuickSellConfirm = false
    
    var body: some View {
        ZStack {
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .solidGlassCircle()
                    }
                    
                    Spacer()
                    
                    Text("CARD OPTIONS")
                        .font(.pTitle3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal)
                .padding(.top, 18)
                .padding(.bottom, 12)
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Card preview — centered
                        cardPreview
                            .padding(.horizontal, 30)
                        
                        // Action buttons
                        VStack(spacing: 10) {
                            optionButton(
                                icon: "chart.line.uptrend.xyaxis",
                                label: "List on Market",
                                subtitle: "Set a price and sell to other players",
                                colors: [Color.blue, Color.purple]
                            ) {
                                onListOnMarket()
                            }
                            
                            optionButton(
                                icon: "chart.bar.fill",
                                label: "Compare Price",
                                subtitle: "See similar listings on the market",
                                colors: [Color.teal, Color.cyan]
                            ) {
                                onComparePrice()
                            }
                            
                            optionButton(
                                icon: "bolt.fill",
                                label: "Quick Sell",
                                subtitle: "Instantly sell for 250 coins",
                                colors: [Color.orange, Color.red]
                            ) {
                                showQuickSellConfirm = true
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Quick Sell?", isPresented: $showQuickSellConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sell for 250 coins", role: .destructive) {
                onQuickSell()
            }
        } message: {
            Text("This will permanently remove the card from your garage and award you 250 coins.")
        }
    }
    
    // MARK: - Card Preview
    
    private var isDriverOnly: Bool {
        if case .driver(let dc) = card, !dc.isDriverPlusVehicle { return true }
        return false
    }
    
    private var cardPreview: some View {
        Group {
            // Show the ONE baked flat image — no SwiftUI layers, just pixels
            if let flatImage = CardFlattener.shared.flatten(card) {
                Image(uiImage: flatImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: isDriverOnly ? 400 : 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: isDriverOnly ? 180 : 320, height: isDriverOnly ? 320 : 180)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Option Button
    
    private func optionButton(
        icon: String,
        label: String,
        subtitle: String,
        colors: [Color],
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: disabled ? [Color.gray.opacity(0.4)] : colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.poppins(16))
                        .fontWeight(.semibold)
                        .foregroundStyle(disabled ? .secondary : .primary)
                    
                    Text(subtitle)
                        .font(.poppins(12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .solidGlass(cornerRadius: 14)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

#Preview {
    let card = AnyCard.vehicle(SavedCard(
        image: UIImage(systemName: "car.fill")!,
        make: "Porsche",
        model: "911 GT3",
        color: "White",
        year: "2024"
    ))
    CardOptionsView(
        card: card,
        onQuickSell: {},
        onListOnMarket: {},
        onComparePrice: {}
    )
}
