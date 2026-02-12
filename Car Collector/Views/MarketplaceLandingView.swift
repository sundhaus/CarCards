//
//  MarketplaceLandingView.swift
//  CarCardCollector
//
//  Marketplace landing page with navigation options
//

import SwiftUI

struct MarketplaceLandingView: View {
    var isLandscape: Bool = false
    var savedCards: [SavedCard]
    var onCardListed: ((SavedCard) -> Void)? = nil  // ✅ Updated to match Firebase version
    @State private var showBuySell = false
    @State private var showTransferList = false
    @State private var showTransferTargets = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.05, green: 0.05, blue: 0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Marketplace")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Trade & collect rare cards")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 30)
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Buy & Sell Card
                            NavigationButton(
                                title: "Buy & Sell",
                                subtitle: "Browse marketplace listings",
                                icon: "cart.fill",
                                gradient: [Color.blue, Color.purple],
                                action: {
                                    showBuySell = true
                                }
                            )
                            
                            // Transfer List
                            NavigationButton(
                                title: "Transfer List",
                                subtitle: "Cards you've listed for sale",
                                icon: "list.bullet.rectangle",
                                gradient: [Color.orange, Color.red],
                                action: {
                                    showTransferList = true
                                }
                            )
                            
                            // Transfer Targets
                            NavigationButton(
                                title: "Transfer Targets",
                                subtitle: "Cards you're bidding on",
                                icon: "target",
                                gradient: [Color.green, Color.teal],
                                action: {
                                    showTransferTargets = true
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, isLandscape ? 0 : 80)
                .padding(.trailing, isLandscape ? 100 : 0)
            }
            .navigationDestination(isPresented: $showBuySell) {
                MarketplaceBuySellView(
                    isLandscape: isLandscape,
                    savedCards: savedCards,
                    onCardListed: onCardListed
                )
            }
            .navigationDestination(isPresented: $showTransferList) {
                TransferListView(isLandscape: isLandscape)
            }
            .navigationDestination(isPresented: $showTransferTargets) {
                TransferTargetsView(isLandscape: isLandscape)
            }
        }
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
        }
        .onDisappear {
            OrientationManager.unlockOrientation()
        }
    }
}

// Navigation Button Component
struct NavigationButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
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
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Arrow
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
    }
}

// Custom corner radius extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    MarketplaceLandingView(savedCards: [])
}
