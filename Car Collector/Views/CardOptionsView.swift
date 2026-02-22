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
    let onReplicate: () -> Void
    
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
                    
                    Text("CARD OPTIONS")
                        .font(.pTitle3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Balance spacer
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal)
                .padding(.top, 18)
                .padding(.bottom, 20)
                
                Spacer()
                
                // Card preview — centered and prominent
                cardPreview
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    // List on Market
                    optionButton(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "List on Market",
                        subtitle: "Set a price and sell to other players",
                        colors: [Color.blue, Color.purple]
                    ) {
                        onListOnMarket()
                    }
                    
                    // Quick Sell
                    optionButton(
                        icon: "bolt.fill",
                        label: "Quick Sell",
                        subtitle: "Instantly sell for 250 coins",
                        colors: [Color.orange, Color.red]
                    ) {
                        showQuickSellConfirm = true
                    }
                    
                    // Replicate
                    optionButton(
                        icon: "doc.on.doc.fill",
                        label: "Replicate",
                        subtitle: "Coming soon",
                        colors: [Color.gray, Color.gray.opacity(0.6)],
                        disabled: true
                    ) {
                        onReplicate()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
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
    
    private var cardPreview: some View {
        GeometryReader { geo in
            let isDriver = {
                if case .driver = card { return true }
                return false
            }()
            
            let maxWidth = geo.size.width
            let maxHeight = geo.size.height
            
            let cardAspect: CGFloat = isDriver ? 9.0 / 16.0 : 16.0 / 9.0
            let cardWidth: CGFloat
            let cardHeight: CGFloat
            
            if isDriver {
                // Portrait card — fit by height
                cardHeight = min(maxHeight, maxWidth / cardAspect)
                cardWidth = cardHeight * cardAspect
            } else {
                // Landscape card — fit by width
                cardWidth = min(maxWidth, maxHeight * cardAspect)
                cardHeight = cardWidth / cardAspect
            }
            
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    
                    ZStack {
                        if let image = card.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: cardWidth, height: cardHeight)
                                .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: cardWidth, height: cardHeight)
                        }
                        
                        // Border overlay
                        if let borderName = CardBorderConfig.forFrame(card.customFrame).borderImageName {
                            Image(borderName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: cardWidth, height: cardHeight)
                                .allowsHitTesting(false)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    
                    // Card title
                    Text(card.displayTitle)
                        .font(.poppins(16))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    
                    Spacer()
                }
                Spacer()
            }
        }
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
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
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
        onReplicate: {}
    )
}
