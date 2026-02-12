//
//  HotCardsCarousel.swift
//  CarCardCollector
//
//  Carousel showing cards with most heat globally
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
                            HotCardItem(card: card)
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

struct HotCardItem: View {
    let card: FriendActivity
    
    var body: some View {
        VStack(spacing: 8) {
            // Card image with 3D shadow effect
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
                    .frame(width: 280, height: 157.5)
                
                // Actual card with image
                Group {
                    if let url = URL(string: card.imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                // Loading placeholder
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        ProgressView()
                                            .tint(.white)
                                    )
                            case .success(let image):
                                // Successfully loaded image
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                // Failed to load - show placeholder
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.white.opacity(0.5))
                                    )
                            @unknown default:
                                // Unknown state
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                        }
                        .frame(width: 280, height: 157.5)
                        .clipped()
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 8)
                    } else {
                        // Invalid URL placeholder
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
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HotCardsCarousel()
            .padding()
    }
}
