//
//  LaunchScreenView.swift
//  CarCardCollector
//
//  Custom launch screen with Car Collector logo
//

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Exact blue background matching the logo (#4F84C7)
            Color(red: 0.310, green: 0.521, blue: 0.784)
                .ignoresSafeArea()
            
            // Logo image
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 280)
        }
    }
}

#Preview {
    LaunchScreenView()
}
