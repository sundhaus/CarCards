//
//  CarCard.swift
//  CarCardCollector
//
//  Card component with image background and text
//

import SwiftUI

struct CarCard: View {
    var body: some View {
        ZStack {
            // Background box
            Rectangle()
                .fill(.gray.opacity(0.3))
            
            // Text overlay
            VStack {
                Spacer()
                Text("Car Name")
                    .font(.pHeadline)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
        .frame(width: 200, height: 300)
        .cornerRadius(15)
    }
}

#Preview {
    CarCard()
}
