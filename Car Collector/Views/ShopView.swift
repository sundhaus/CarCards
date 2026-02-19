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
        VStack {
            Spacer()
            Image(systemName: "bag.fill")
                .font(.poppins(60))
                .foregroundStyle(.green)
            Text("Shop")
                .font(.pTitle)
                .fontWeight(.semibold)
                .padding(.top, 8)
            Text("Coming soon")
                .font(.pSubheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AppBackground() }
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
