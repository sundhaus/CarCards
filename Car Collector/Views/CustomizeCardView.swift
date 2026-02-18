//
//  CustomizeCardView.swift
//  CarCardCollector
//
//  Card customization view with tabbed interface
//

import SwiftUI

enum CardFrame: String, CaseIterable {
    case white = "White"
    case black = "Black"
    
    var displayName: String { rawValue }
}

struct CustomizeCardView: View {
    let card: SavedCard
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFrame: CardFrame = .white
    @State private var selectedTab = 0 // 0: Border, 1: Stickers, 2: Effects
    
    var body: some View {
        ZStack {
            // Dark blue background
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Text("Customize Card")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        saveFrameSelection()
                        dismiss()
                    }) {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
                
                // Card preview centered
                ZStack {
                    // Card image
                    if let image = card.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 320, height: 180)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 320, height: 180)
                    }
                    
                    // Border PNG overlay based on selection
                    if selectedFrame == .white {
                        Image("Border_Def_Wht")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 320, height: 180)
                            .allowsHitTesting(false)
                    } else {
                        Image("Border_Def_Blk")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 320, height: 180)
                            .allowsHitTesting(false)
                    }
                    
                    // Car name overlay (preview)
                    VStack {
                        HStack {
                            HStack(spacing: 4) {
                                let textColor: Color = selectedFrame == .white ? .white : .black
                                let shadowColor: Color = selectedFrame == .white ? .black.opacity(0.8) : .white.opacity(0.6)
                                
                                Text(card.make.uppercased())
                                    .font(.custom("Futura-Light", size: 14))
                                    .foregroundStyle(textColor)
                                    .shadow(color: shadowColor, radius: 3, x: 0, y: 2)
                                
                                Text(card.model)
                                    .font(.custom("Futura-Bold", size: 14))
                                    .foregroundStyle(textColor)
                                    .shadow(color: shadowColor, radius: 3, x: 0, y: 2)
                                    .lineLimit(1)
                            }
                            .padding(.top, 14)
                            .padding(.leading, 14)
                            Spacer()
                        }
                        Spacer()
                    }
                    .frame(width: 320, height: 180)
                }
                .clipShape(RoundedRectangle(cornerRadius: 180 * 0.08))
                .animation(.spring(response: 0.3), value: selectedFrame)
                
                Spacer()
                
                // Tabbed customization panel at bottom
                VStack(spacing: 0) {
                    // Tab headers
                    HStack(spacing: 0) {
                        tabHeader(title: "Border", index: 0)
                        tabHeader(title: "Stickers", index: 1)
                        tabHeader(title: "Effects", index: 2)
                    }
                    .frame(height: 50)
                    
                    // Tab content
                    ZStack {
                        Color(white: 0.15)
                        
                        if selectedTab == 0 {
                            borderTabContent
                        } else if selectedTab == 1 {
                            placeholderTabContent(title: "Stickers", icon: "photo.on.rectangle.angled")
                        } else {
                            placeholderTabContent(title: "Effects", icon: "sparkles")
                        }
                    }
                    .frame(height: 200)
                }
                .background(Color(white: 0.15))
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
            
            // Set initial frame from customFrame value
            if let currentFrame = card.customFrame {
                switch currentFrame {
                case "Border_Def_Blk", "Black":
                    selectedFrame = .black
                default:
                    selectedFrame = .white
                }
            } else {
                selectedFrame = .white
            }
        }
        .onDisappear {
            OrientationManager.unlockOrientation()
        }
    }
    
    // MARK: - Tab Header
    
    private func tabHeader(title: String, index: Int) -> some View {
        Button(action: {
            selectedTab = index
        }) {
            VStack(spacing: 0) {
                Spacer()
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.6))
                    .padding(.bottom, 8)
                
                // Active indicator
                Rectangle()
                    .fill(selectedTab == index ? Color.blue : Color.clear)
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(white: selectedTab == index ? 0.2 : 0.15))
    }
    
    // MARK: - Border Tab Content
    
    private var borderTabContent: some View {
        VStack(spacing: 20) {
            Text("Border Color")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top, 20)
            
            HStack(spacing: 30) {
                // White option
                borderColorOption(frame: .white, label: "White")
                
                // Black option
                borderColorOption(frame: .black, label: "Black")
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private func borderColorOption(frame: CardFrame, label: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedFrame = frame
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.25))
                        .frame(width: 60, height: 60)
                    
                    if frame == .white {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 50, height: 50)
                    } else {
                        Circle()
                            .stroke(Color.black, lineWidth: 4)
                            .frame(width: 50, height: 50)
                    }
                    
                    // Selected indicator
                    if selectedFrame == frame {
                        Circle()
                            .stroke(Color.blue, lineWidth: 3)
                            .frame(width: 66, height: 66)
                    }
                }
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(selectedFrame == frame ? .white : .white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Placeholder Tab Content
    
    private func placeholderTabContent(title: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.5))
            Text("Coming Soon")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }
    
    // MARK: - Helper Functions
    
    private func saveFrameSelection() {
        // Load current cards from storage
        var savedCards = CardStorage.loadCards()
        
        if let index = savedCards.firstIndex(where: { $0.id == card.id }) {
            // Map CardFrame enum to actual PNG border names
            let customFrameValue: String = {
                switch selectedFrame {
                case .white:
                    return "Border_Def_Wht"
                case .black:
                    return "Border_Def_Blk"
                }
            }()
            
            savedCards[index].customFrame = customFrameValue
            CardStorage.saveCards(savedCards)
            
            print("💾 Saved frame: \(customFrameValue) for card: \(card.make) \(card.model)")
            
            // Sync to Firebase (use firebaseId if available)
            if let firebaseId = card.firebaseId {
                Task {
                    do {
                        try await CardService.shared.updateCustomFrame(
                            cardId: firebaseId,
                            customFrame: customFrameValue
                        )
                        print("✅ Synced custom frame to Firebase")
                    } catch {
                        print("❌ Failed to sync custom frame to Firebase: \(error)")
                    }
                }
            }
        } else {
            print("❌ Could not find card in storage to save frame")
        }
    }
}

#Preview {
    CustomizeCardView(
        card: SavedCard(
            image: UIImage(systemName: "photo")!,
            make: "Toyota",
            model: "Supra",
            color: "Red",
            year: "1998"
        )
    )
}
