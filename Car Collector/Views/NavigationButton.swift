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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer(minLength: 8)
                
                // Chevron arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(height: 92)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
