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
            VStack(spacing: DeviceScale.h(8)) {
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
                        .frame(width: DeviceScale.w(70), height: DeviceScale.w(70))
                    
                    Image(systemName: icon)
                        .font(.poppins(32))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white)
                }
                
                // Title
                Text(title)
                    .font(.poppins(16))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, DeviceScale.h(16))
            }
            .frame(maxWidth: .infinity)
            .frame(height: DeviceScale.h(140))
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 20/255, green: 20/255, blue: 24/255))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
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
