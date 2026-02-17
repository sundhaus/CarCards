//
//  HomeContainer.swift
//  CarCardCollector
//
//  Container component for home page grid items
//  Logo on top, label below
//

import SwiftUI

struct HomeContainer: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    var disabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Spacer()
                
                // Gradient icon circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                
                // Title - closer to icon, farther from bottom
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HStack(spacing: 16) {
            HomeContainer(
                title: "Leaderboard",
                icon: "chart.bar.fill",
                gradient: [Color(red: 1.0, green: 0.8, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)],
                action: {}
            )
            
            HomeContainer(
                title: "Friends",
                icon: "person.2.fill",
                gradient: [Color.blue, Color.cyan],
                action: {}
            )
        }
        .padding()
    }
}
