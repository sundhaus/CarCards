//
//  CardEffectView.swift
//  CarCardCollector
//
//  Pro feature UI: Apply AI-generated effects to cards
//
//  Flow:
//  1. User sees effect menu with curated previews (3 static examples per effect)
//  2. Taps "Continue" → their card is generated with the effect
//  3. Result screen: Accept or Reroll (1 free reroll)
//  4. If rerolled: pick between the two versions
//

import SwiftUI

// MARK: - Main Effect View

struct CardEffectView: View {
    let card: SavedCard
    let onApply: (UIImage) -> Void
    let onDismiss: () -> Void
    
    @StateObject private var effectService = CardEffectService.shared
    @State private var selectedEffect: CardEffect = .smoke
    @State private var currentStep: EffectStep = .browse
    @State private var errorMessage: String?
    @State private var showError = false
    
    enum EffectStep {
        case browse      // Viewing effect previews
        case generating  // AI is generating
        case result      // Viewing generated result
        case picking     // Picking between original and reroll
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content based on step
                switch currentStep {
                case .browse:
                    effectBrowserView
                case .generating:
                    generatingView
                case .result:
                    resultView
                case .picking:
                    pickingView
                }
            }
        }
        .alert("Effect Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: {
                effectService.reset()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Card Effects")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            
            Spacer()
            
            // Pro badge
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                Text("PRO")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.yellow)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.yellow.opacity(0.15))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Step 1: Effect Browser with Static Previews
    
    private var effectBrowserView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current card preview
                VStack(spacing: 8) {
                    Text("Your Card")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    if let image = card.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 280, height: 157.5)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
                    }
                    
                    Text("\(card.make) \(card.model)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 12)
                
                // Effect selection
                ForEach(CardEffect.allCases) { effect in
                    effectCard(effect)
                }
                
                // Continue button
                Button(action: {
                    generateEffect()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Apply \(selectedEffect.displayName)")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Effect Card with 3 Static Previews
    
    private func effectCard(_ effect: CardEffect) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Effect header
            HStack(spacing: 10) {
                Image(systemName: effect.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        selectedEffect == effect
                            ? LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(effect.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text(effect.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: selectedEffect == effect ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(selectedEffect == effect ? .purple : .white.opacity(0.3))
            }
            
            // 3 Static preview images (horizontal scroll)
            VStack(alignment: .leading, spacing: 6) {
                Text("Preview examples — your result will be unique")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(1...3, id: \.self) { index in
                            // These are pre-made static preview images bundled in the app
                            // Named: "effect_smoke_preview_1", "effect_smoke_preview_2", etc.
                            let imageName = "effect_\(effect.rawValue)_preview_\(index)"
                            
                            ZStack {
                                // Placeholder if image not yet created
                                if let previewImage = UIImage(named: imageName) {
                                    Image(uiImage: previewImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 200, height: 112.5)
                                        .clipped()
                                        .cornerRadius(10)
                                } else {
                                    // Placeholder for previews not yet added to asset catalog
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            LinearGradient(
                                                colors: [.gray.opacity(0.3), .gray.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 200, height: 112.5)
                                        .overlay(
                                            VStack(spacing: 4) {
                                                Image(systemName: effect.iconName)
                                                    .font(.system(size: 24))
                                                    .foregroundStyle(.white.opacity(0.3))
                                                Text("Preview \(index)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.white.opacity(0.3))
                                            }
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(selectedEffect == effect ? Color.purple.opacity(0.15) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            selectedEffect == effect ? Color.purple.opacity(0.4) : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
        .padding(.horizontal, 16)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedEffect = effect
            }
        }
    }
    
    // MARK: - Step 2: Generating
    
    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated effect icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: selectedEffect.iconName)
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)
            }
            
            VStack(spacing: 8) {
                Text("Creating Your Effect")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("AI is applying \(selectedEffect.displayName) to your card...")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.purple)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 3: Result View
    
    private var resultView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if let result = effectService.currentResult {
                // Generated card with effect
                VStack(spacing: 8) {
                    Text(selectedEffect.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.purple)
                    
                    Image(uiImage: result.effectImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 320, height: 180)
                        .cornerRadius(12)
                        .shadow(color: .purple.opacity(0.4), radius: 15, y: 5)
                }
                
                // Before / After label
                HStack(spacing: 16) {
                    if let originalImage = card.image {
                        VStack(spacing: 4) {
                            Text("Before")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            Image(uiImage: originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 67.5)
                                .clipped()
                                .cornerRadius(8)
                                .opacity(0.6)
                        }
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.white.opacity(0.3))
                    
                    VStack(spacing: 4) {
                        Text("After")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Image(uiImage: result.effectImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 67.5)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                // Accept button
                Button(action: {
                    if let result = effectService.currentResult {
                        onApply(result.effectImage)
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Apply Effect")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                
                // Reroll button (if not yet used)
                if !effectService.hasUsedReroll {
                    Button(action: {
                        rerollEffect()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Reroll (1 Free)")
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                
                // Cancel
                Button(action: {
                    effectService.reset()
                    currentStep = .browse
                }) {
                    Text("Cancel")
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Step 4: Picking Between Two Results
    
    private var pickingView: some View {
        VStack(spacing: 16) {
            Text("Pick Your Favorite")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 20)
            
            Text("Tap the one you want to keep")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            
            Spacer()
            
            // Two options side by side (or stacked on smaller screens)
            VStack(spacing: 16) {
                // Option 1: Original generation
                if let result1 = effectService.currentResult {
                    pickOption(
                        image: result1.effectImage,
                        label: "Version 1",
                        onSelect: {
                            onApply(result1.effectImage)
                        }
                    )
                }
                
                // Option 2: Reroll
                if let result2 = effectService.rerollResult {
                    pickOption(
                        image: result2.effectImage,
                        label: "Version 2",
                        onSelect: {
                            onApply(result2.effectImage)
                        }
                    )
                }
            }
            
            Spacer()
            
            // Cancel
            Button(action: {
                effectService.reset()
                currentStep = .browse
            }) {
                Text("Cancel — Don't Apply")
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 12)
            }
            .padding(.bottom, 30)
        }
    }
    
    private func pickOption(image: UIImage, label: String, onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 280, height: 157.5)
                    .cornerRadius(12)
                    .shadow(color: .purple.opacity(0.3), radius: 10, y: 3)
                
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Actions
    
    private func generateEffect() {
        guard let cardImage = card.image else { return }
        
        currentStep = .generating
        
        Task {
            do {
                let _ = try await effectService.generateEffect(
                    on: cardImage,
                    effect: selectedEffect,
                    carDescription: "\(card.make) \(card.model) \(card.year)"
                )
                
                await MainActor.run {
                    currentStep = .result
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    currentStep = .browse
                }
            }
        }
    }
    
    private func rerollEffect() {
        guard let cardImage = card.image else { return }
        
        currentStep = .generating
        
        Task {
            do {
                let _ = try await effectService.reroll(
                    on: cardImage,
                    effect: selectedEffect
                )
                
                await MainActor.run {
                    currentStep = .picking
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    currentStep = .result // Go back to result, reroll failed
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CardEffectView(
        card: SavedCard(
            image: UIImage(systemName: "car.fill")!,
            make: "Nissan",
            model: "GT-R",
            color: "White",
            year: "2024"
        ),
        onApply: { _ in },
        onDismiss: { }
    )
}
