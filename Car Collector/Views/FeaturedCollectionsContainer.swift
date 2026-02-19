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
    @ObservedObject private var hotCardsService = HotCardsService.shared
    
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
        .contentShape(Rectangle())
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
    
    private var headerSection: some View {
        HStack {
            Text("FEATURED")
                .font(.poppins(20))
                .foregroundStyle(.primary)
            
            Spacer()
            
            timerBadge
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var timerBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.poppins(14))
                .foregroundStyle(.secondary)
            
            Text(hotCardsService.timeUntilNextRefresh)
                .font(.poppins(14))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.08))
        .cornerRadius(20)
    }
    
    private var carouselSection: some View {
        HotCardsCarousel()
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
    }
    
    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.clear)
    }
    
    private var containerBorder: some View {
        EmptyView()
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        FeaturedCollectionsContainer(action: {})
            .padding()
    }
}
