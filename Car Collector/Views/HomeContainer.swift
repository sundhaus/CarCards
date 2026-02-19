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
                        .font(.poppins(32))
                        .foregroundStyle(.white)
                }
                
                // Title
                Text(title)
                    .font(.poppins(16))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .contentShape(Rectangle())
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
                title: "LEADERBOARD",
                icon: "chart.bar.fill",
                gradient: [Color(red: 1.0, green: 0.8, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)],
                action: {}
            )
            
            HomeContainer(
                title: "FRIENDS",
                icon: "person.2.fill",
                gradient: [Color.blue, Color.cyan],
                action: {}
            )
        }
        .padding()
    }
}
