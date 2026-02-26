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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 20/255, green: 20/255, blue: 24/255))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            // Red accent line at top
            Capsule()
                .fill(Color.appAccent.opacity(0.5))
                .frame(width: 80, height: 2)
                .padding(.top, 1)
        }
    }
    
    private var headerSection: some View {
        HStack {
            Text("FEATURED")
                .font(.poppins(DeviceScale.f(20)))
                .foregroundStyle(.primary)
            
            Spacer()
            
            timerBadge
        }
        .padding(.horizontal, DeviceScale.w(20))
        .padding(.top, DeviceScale.h(20))
    }
    
    private var timerBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.poppins(DeviceScale.f(14)))
                .foregroundStyle(.secondary)
            
            Text(hotCardsService.timeUntilNextRefresh)
                .font(.poppins(DeviceScale.f(14)))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DeviceScale.w(12))
        .padding(.vertical, DeviceScale.h(6))
        .background(Color.primary.opacity(0.08))
        .cornerRadius(20)
    }
    
    private var carouselSection: some View {
        HotCardsCarousel()
            .padding(.horizontal, 8)
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
