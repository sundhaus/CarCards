//
//  DriverTypeSelectorView.swift
//  CarCardCollector
//
//  Sheet to select driver capture type
//

import SwiftUI

struct DriverTypeSelectorView: View {
    var onSelect: ((CaptureType) -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Choose Capture Type")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            // Options
            VStack(spacing: 12) {
                Button(action: {
                    onSelect?(.driver)
                }) {
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.title2)
                        Text("Driver")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                
                Button(action: {
                    onSelect?(.driverPlusVehicle)
                }) {
                    HStack {
                        Image(systemName: "person.and.background.dotted")
                            .font(.title2)
                        Text("Driver + Vehicle")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(Color.appBackgroundSolid)
    }
}

#Preview {
    DriverTypeSelectorView()
}
