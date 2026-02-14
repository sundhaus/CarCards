//
//  ShopView.swift
//  CarCardCollector
//
//  Shop page view
//

import SwiftUI

struct ShopView: View {
    var isLandscape: Bool = false
    
    var body: some View {
        ZStack {
            // Dark blue background
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Image(systemName: "bag.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("Shop")
                    .font(.title)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                Text("Coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.bottom, isLandscape ? 0 : 80) // Space for bottom nav in portrait
        .padding(.trailing, isLandscape ? 100 : 0) // Space for side nav in landscape
        .onAppear {
            OrientationManager.lockOrientation(.portrait)
        }
        .onDisappear {
            OrientationManager.unlockOrientation()
        }
    }
}

#Preview {
    ShopView()
}
