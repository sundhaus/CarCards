//
//  FIFACardView.swift
//  CarCardCollector
//
//  Reusable FIFA-style card component for displaying FriendActivity cards
//  Can be used in Friends, Marketplace, User Profiles, etc.
//

import SwiftUI

struct FIFACardView: View {
    let card: FriendActivity
    let height: CGFloat
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    
    // Card is landscape: width is 16:9 ratio
    private var cardWidth: CGFloat { height * (16/9) }
    
    var body: some View {
        ZStack {
            // Card background with gradient
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.85, blue: 0.88),
                            Color(red: 0.75, green: 0.75, blue: 0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 0) {
                // Top bar - GEN badge + Car name
                HStack(spacing: 8) {
                    // GEN badge (top-left)
                    VStack(spacing: 2) {
                        Text("GEN")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black.opacity(0.6))
                        Text("\(card.level)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    )
                    
                    // Car name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.cardMake.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.7))
                            .lineLimit(1)
                        
                        Text(card.cardModel)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Heat indicator (if any)
                    if card.heatCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                            Text("\(card.heatCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.9))
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                // Car image area (center) - uses GeometryReader for fixed space
                GeometryReader { geo in
                    cardImageView
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                
                // Bottom bar - Username
                HStack {
                    Text("@\(card.username)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.black.opacity(0.5))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(card.cardYear)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.4))
            }
            
            // Black border overlay
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.black, lineWidth: 3)
        }
        .frame(width: cardWidth, height: height) // Fixed frame
        .clipped() // Clip content to frame
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        .onAppear {
            loadImage()
        }
    }
    
    @ViewBuilder
    private var cardImageView: some View {
        if let image = cardImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if isLoadingImage {
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .overlay(
                    ProgressView()
                        .tint(.gray)
                )
        } else {
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .overlay(
                    Image(systemName: "car.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.gray.opacity(0.4))
                )
        }
    }
    
    private func loadImage() {
        guard !isLoadingImage, cardImage == nil else { return }
        
        isLoadingImage = true
        
        guard let url = URL(string: card.imageURL) else {
            isLoadingImage = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    isLoadingImage = false
                }
                return
            }
            
            DispatchQueue.main.async {
                cardImage = image
                isLoadingImage = false
            }
        }.resume()
    }
}
