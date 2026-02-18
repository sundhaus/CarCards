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
            // Background with spline
            AppBackground()
            
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
