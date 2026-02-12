//
//  HotCardsCarousel.swift
//  CarCardCollector
//
//  Carousel showing cards with most heat globally - UPDATED with flip to view specs
//

import SwiftUI

struct HotCardsCarousel: View {
    @StateObject private var hotCardsService = HotCardsService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Featured Collections")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            if hotCardsService.isLoading {
                // Loading state
                VStack {
                    ProgressView()
                        .tint(.white)
                    Text("Loading hot cards...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
            } else if hotCardsService.hotCards.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange.opacity(0.7))
                    
                    Text("No hot cards yet")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Text("Be the first to get some heat!")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
            } else {
                // Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(hotCardsService.hotCards) { card in
                            FlippableHotCardItem(card: card)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.25, blue: 0.35), Color(red: 0.15, green: 0.2, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .onAppear {
            hotCardsService.fetchHotCards(limit: 20)
        }
    }
}

struct FlippableHotCardItem: View {
    let card: FriendActivity
    
    @State private var isFlipped = false
    @State private var fetchedSpecs: VehicleSpecs?
    @State private var isFetchingSpecs = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Flippable card
            ZStack {
                if !isFlipped {
                    cardFront
                } else {
                    if isFetchingSpecs {
                        specsLoadingView
                    } else {
                        cardBack
                    }
                }
            }
            .frame(width: 280, height: 157.5)
            .onTapGesture {
                if !isFlipped {
                    // Flipping to back - fetch specs if needed
                    Task {
                        await fetchSpecsIfNeeded()
                    }
                }
                withAnimation(.spring(response: 0.4)) {
                    isFlipped.toggle()
                }
            }
            
            // Heat info below card
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("\(card.heatCount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Car info
                VStack(alignment: .trailing, spacing: 2) {
                    Text(card.cardMake)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("\(card.cardModel) '\(String(card.cardYear.suffix(2)))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 280)
        }
    }
    
    // MARK: - Card Front
    
    private var cardFront: some View {
        ZStack(alignment: .bottomTrailing) {
            // Shadow "floor" effect
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 8)
                .offset(y: 12)
            
            // Actual card with image
            Group {
                if let url = URL(string: card.imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.white.opacity(0.5))
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 280, height: 157.5)
                    .clipped()
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 280, height: 157.5)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 8)
                }
            }
            
            // Tap hint
            Text("Tap for specs")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
                .padding(8)
        }
    }
    
    // MARK: - Card Back (Specs)
    
    private var cardBack: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                Text("\(card.cardMake) \(card.cardModel)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(card.cardYear)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                
                // Stats grid - compact version
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        statItem(label: "HP", value: parseIntValue(fetchedSpecs?.horsepower))
                        statItem(label: "TRQ", value: parseIntValue(fetchedSpecs?.torque))
                    }
                    
                    HStack(spacing: 8) {
                        statItem(label: "0-60", value: parseDoubleValue(fetchedSpecs?.zeroToSixty))
                        statItem(label: "TOP", value: parseIntValue(fetchedSpecs?.topSpeed))
                    }
                    
                    HStack(spacing: 8) {
                        statItem(label: "ENG", value: fetchedSpecs?.engine ?? "???", compact: true)
                        statItem(label: "DRV", value: fetchedSpecs?.drivetrain ?? "???", compact: true)
                    }
                }
                .padding(.horizontal, 12)
                
                Text("Tap to flip back")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.vertical, 8)
        }
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 8)
    }
    
    private var specsLoadingView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("Loading specs...")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 8)
    }
    
    private func statItem(label: String, value: String, compact: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: compact ? 10 : 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 3 : 6)
        .background(Color.white.opacity(0.15))
        .cornerRadius(4)
    }
    
    // MARK: - Helper Functions
    
    private func parseIntValue(_ string: String?) -> String {
        guard let string = string, string != "N/A" else { return "???" }
        let cleaned = string.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleaned.isEmpty ? "???" : cleaned
    }
    
    private func parseDoubleValue(_ string: String?) -> String {
        guard let string = string, string != "N/A" else { return "???" }
        let cleaned = string.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return cleaned.isEmpty ? "???" : cleaned + "s"
    }
    
    private func fetchSpecsIfNeeded() async {
        guard fetchedSpecs == nil else { return }
        
        await MainActor.run {
            isFetchingSpecs = true
        }
        
        do {
            // Use VehicleIDService - it checks Firestore cache first!
            // If your friend already flipped this card, the specs will be cached
            let vehicleService = VehicleIdentificationService()
            let specs = try await vehicleService.fetchSpecs(
                make: card.cardMake,
                model: card.cardModel,
                year: card.cardYear
            )
            
            await MainActor.run {
                fetchedSpecs = specs
                isFetchingSpecs = false
            }
            
            print("✅ Loaded specs for \(card.cardMake) \(card.cardModel) from shared cache")
        } catch {
            print("❌ Failed to fetch specs: \(error)")
            await MainActor.run {
                isFetchingSpecs = false
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HotCardsCarousel()
            .padding()
    }
}
