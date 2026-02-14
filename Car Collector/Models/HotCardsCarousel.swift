//
//  HotCardsCarousel.swift
//  CarCardCollector
//
//  3D horizontal scroll carousel with dynamic rotation based on position
//  Based on: https://github.com/khanboy1989/ThreeDRotationEffectCarousel
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
                loadingView
            } else if hotCardsService.hotCards.isEmpty {
                emptyView
            } else {
                carouselView
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
            // Check if 24 hours passed and refresh if needed
            // On first launch, this will force a refresh and set the timer
            hotCardsService.fetchHotCardsIfNeeded(limit: 20)
        }
    }
    
    // MARK: - Carousel View (Horizontal Scroll with 3D Rotation)
    
    private var carouselView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(hotCardsService.hotCards) { card in
                    GeometryReader { geometry in
                        HotCardItem(card: card)
                            .rotation3DEffect(
                                // Dynamic rotation based on card's horizontal position
                                // Cards closer to screen center are flat, edges are rotated
                                Angle(degrees: Double(geometry.frame(in: .global).minX - 50) / -20.0),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: .center,
                                anchorZ: 0.0,
                                perspective: 1.0
                            )
                    }
                    .frame(width: 280, height: 220)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(height: 240)
    }
    
    // MARK: - Loading & Empty States
    
    private var loadingView: some View {
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
    }
    
    private var emptyView: some View {
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
    }
}

// MARK: - Hot Card Item

struct HotCardItem: View {
    let card: FriendActivity
    
    var body: some View {
        VStack(spacing: 12) {
            // Card with proper format (like SavedCardView)
            ZStack {
                // Custom frame/border
                if let frameName = card.customFrame, frameName != "None" {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(frameName == "White" ? Color.white : Color.black, lineWidth: 6)
                        .frame(width: 280, height: 157.5)
                }
                
                // Card image
                cardImageView
                    .frame(width: 268, height: 150.75)
                    .clipped()
                
                // Card text overlay at bottom
                VStack {
                    Spacer()
                    Text("\(card.cardMake) \(card.cardModel)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.6))
                }
                .frame(width: 268, height: 150.75)
            }
            .frame(width: 280, height: 157.5)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
            )
            
            // Heat info below card
            HStack(spacing: 8) {
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
                
                Text("'\(String(card.cardYear.suffix(2)))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 280)
            .padding(.horizontal, 4)
        }
    }
    
    @ViewBuilder
    private var cardImageView: some View {
        if let url = URL(string: card.imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderView(isLoading: true)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderView(isLoading: false)
                @unknown default:
                    placeholderView(isLoading: false)
                }
            }
        } else {
            placeholderView(isLoading: false)
        }
    }
    
    private func placeholderView(isLoading: Bool) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HotCardsCarousel()
            .padding()
    }
}
