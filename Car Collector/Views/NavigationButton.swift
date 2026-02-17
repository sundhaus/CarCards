//
//  NavigationButton.swift
//  CarCardCollector
//
//  Reusable navigation button component with gradient icon
//  Used throughout the app for consistent design
//

import SwiftUI

struct NavigationButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
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
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Chevron arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(20)
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
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            NavigationButton(
                title: "Buy Cards",
                subtitle: "Browse the marketplace",
                icon: "cart.fill",
                gradient: [Color.blue, Color.cyan],
                action: {}
            )
            
            NavigationButton(
                title: "Sell Cards",
                subtitle: "List your cards for sale",
                icon: "dollarsign.circle.fill",
                gradient: [Color.green, Color.teal],
                action: {}
            )
            
            NavigationButton(
                title: "Leaderboard",
                subtitle: "See top players",
                icon: "chart.bar.fill",
                gradient: [Color(red: 1.0, green: 0.8, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)],
                action: {}
            )
        }
        .padding()
    }
}
