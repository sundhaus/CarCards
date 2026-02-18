//
//  FIFACardView.swift
//  CarCardCollector
//
//  Reusable card component for displaying FriendActivity cards
//  Cleaner design with full-bleed image and car name overlay
//

import SwiftUI

struct FIFACardView: View {
    let card: FriendActivity
    let height: CGFloat
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    
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
            
            // Car image - full bleed
            cardImageView
                .frame(width: cardWidth, height: height)
                .clipped()
            
            // Car name overlay - top right
            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(card.cardMake.uppercased())
                            .font(.system(size: height * 0.08, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                        
                        Text(card.cardModel)
                            .font(.system(size: height * 0.11, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                            .lineLimit(1)
                    }
                    .padding(.top, height * 0.08)
                    .padding(.trailing, height * 0.08)
                }
                Spacer()
            }
            
            // Heat indicator - bottom right if has heat
            if card.heatCount > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: height * 0.09))
                            Text("\(card.heatCount)")
                                .font(.system(size: height * 0.09, weight: .bold))
                        }
                        .foregroundStyle(.orange)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .padding(.bottom, height * 0.08)
                        .padding(.trailing, height * 0.08)
                    }
                }
            }
            
            // Thicker black border overlay
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.black, lineWidth: 5)
        }
        .frame(width: cardWidth, height: height)
        .clipped()
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
                        .font(.system(size: height * 0.3))
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
