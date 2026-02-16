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
            // Blue background matching the logo
            Color(red: 0.22, green: 0.47, blue: 0.76)
                .ignoresSafeArea()
            
            // Logo image
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250)
        }
    }
}

#Preview {
    LaunchScreenView()
}
