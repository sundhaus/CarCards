//
//  FeaturedCollectionsContainer.swift
//  CarCardCollector
//
//  Container for Featured Collections
//  Title in top-left, timer in top-right, carousel in center
//

import SwiftUI

struct FeaturedCollectionsContainer: View {
    let action: () -> Void
    @StateObject private var hotCardsService = HotCardsService()
    
    var body: some View {
        Button(action: action) {
            containerContent
        }
        .buttonStyle(.plain)
    }
    
    // Break down into separate computed property
    private var containerContent: some View {
        VStack(spacing: 0) {
            headerSection
            carouselSection
        }
        .background(containerBackground)
        .overlay(containerBorder)
    }
    
    private var headerSection: some View {
        HStack {
            Text("Featured")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            
            Spacer()
            
            timerBadge
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    private var timerBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
            
            Text(hotCardsService.timeUntilNextRefresh)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.15))
        .cornerRadius(20)
    }
    
    private var carouselSection: some View {
        HotCardsCarousel()
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
    }
    
    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.1))
    }
    
    private var containerBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        FeaturedCollectionsContainer(action: {})
            .padding()
    }
}
