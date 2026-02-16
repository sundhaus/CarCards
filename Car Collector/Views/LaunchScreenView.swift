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
            // Exact blue background matching the logo (#1F5AB5)
            Color(red: 0.122, green: 0.353, blue: 0.710)
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
