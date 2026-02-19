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
    @State private var displayImage: UIImage?
    @State private var isRemovingBackground = false
    @State private var backgroundRemoved = false
    @State private var originalImage: UIImage?  // Preserved original before bg removal
    
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
                            .font(.pTitle3)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    Text("Customize Card")
                        .font(.pTitle3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
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
                    if let image = displayImage ?? card.image {
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
                                
                                Text(card.model.uppercased())
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
                .clipShape(RoundedRectangle(cornerRadius: 180 * 0.09))
                .cardTilt()
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
                            effectsTabContent
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
            
            // If card has original image stored, background was previously removed
            if let storedOriginal = card.originalImage {
                originalImage = storedOriginal
                backgroundRemoved = true
                print("🖼️ Loaded stored original image (from \(card.originalImageData != nil ? "memory" : "file"))")
            } else {
                print("🖼️ No stored original image")
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
                    .font(.pSubheadline)
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
                .font(.pHeadline)
                .foregroundStyle(.primary)
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
                    .font(.pCaption)
                    .foregroundStyle(selectedFrame == frame ? .white : .white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Placeholder Tab Content
    
    private func placeholderTabContent(title: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.poppins(40))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.pHeadline)
                .foregroundStyle(.tertiary)
            Text("Coming Soon")
                .font(.pCaption)
                .foregroundStyle(.tertiary)
        }
    }
    
    // MARK: - Effects Tab Content
    
    private var effectsTabContent: some View {
        VStack(spacing: 16) {
            Text("Effects")
                .font(.pHeadline)
                .foregroundStyle(.primary)
                .padding(.top, 20)
            
            Button(action: removeBackground) {
                HStack(spacing: 10) {
                    if isRemovingBackground {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: backgroundRemoved ? "checkmark.circle.fill" : "scissors")
                            .font(.pSubheadline)
                    }
                    Text(backgroundRemoved ? "Background Removed" : "Remove Background")
                        .font(.pSubheadline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(backgroundRemoved ? Color.green : Color.blue)
                .cornerRadius(12)
            }
            .disabled(isRemovingBackground || backgroundRemoved)
            .padding(.horizontal, 30)
            
            if backgroundRemoved {
                Button(action: restoreBackground) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.pCaption)
                        Text("Restore Original")
                            .font(.pCaption)
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
    }
    
    private func removeBackground() {
        isRemovingBackground = true
        
        // Use original image if we have one, otherwise use current card image
        guard let sourceImage = originalImage ?? card.image else {
            isRemovingBackground = false
            return
        }
        
        // Preserve the original image before processing
        if originalImage == nil {
            originalImage = sourceImage
        }
        
        SubjectLifter.liftSubject(from: sourceImage) { result in
            DispatchQueue.main.async {
                isRemovingBackground = false
                
                switch result {
                case .success(let processedImage):
                    displayImage = processedImage
                    backgroundRemoved = true
                case .failure(let error):
                    print("❌ Background removal failed: \(error)")
                }
            }
        }
    }
    
    private func restoreBackground() {
        // Restore original image (sets displayImage so save will write it back)
        displayImage = originalImage
        originalImage = nil
        backgroundRemoved = false
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
            
            // If background was removed, save the processed image too
            if let updatedImage = displayImage {
                savedCards[index] = SavedCard(
                    id: card.id,
                    image: updatedImage,
                    make: card.make,
                    model: card.model,
                    color: card.color,
                    year: card.year,
                    specs: card.specs,
                    capturedBy: card.capturedBy,
                    capturedLocation: card.capturedLocation,
                    previousOwners: card.previousOwners,
                    customFrame: customFrameValue,
                    firebaseId: card.firebaseId,
                    originalImage: backgroundRemoved ? originalImage : nil
                )
                print("💾 Saving card - bgRemoved: \(backgroundRemoved), originalImage: \(originalImage != nil), originalImageData: \(savedCards[index].originalImageData?.count ?? 0) bytes")
            } else {
                savedCards[index].customFrame = customFrameValue
                // If background was restored, clear the original image data
                if !backgroundRemoved {
                    savedCards[index].originalImageData = nil
                }
            }
            
            CardStorage.saveCards(savedCards)
            
            print("💾 Saved frame: \(customFrameValue) for card: \(card.make) \(card.model)")
            
            // Sync to Firebase (use firebaseId if available)
            if let firebaseId = card.firebaseId {
                Task {
                    do {
                        // Sync custom frame
                        try await CardService.shared.updateCustomFrame(
                            cardId: firebaseId,
                            customFrame: customFrameValue
                        )
                        print("✅ Synced custom frame to Firebase")
                        
                        // If background was removed, re-upload image to Firebase
                        if let updatedImage = displayImage {
                            try await CardService.shared.updateCardImage(
                                cardId: firebaseId,
                                image: updatedImage
                            )
                            print("✅ Synced updated card image to Firebase")
                        }
                    } catch {
                        print("❌ Failed to sync customization to Firebase: \(error)")
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
