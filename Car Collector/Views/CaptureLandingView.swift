//
//  CaptureLandingView.swift
//  CarCardCollector
//
//  Capture landing page with vehicle, driver, and location options
//

import SwiftUI

struct CaptureLandingView: View {
    var isLandscape: Bool = false
    var onCardSaved: ((SavedCard) -> Void)? = nil
    @State private var showVehicleCapture = false
    @State private var showDriverCapture = false
    @State private var showLocationCapture = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Capture")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Choose what to capture")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 30)
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Vehicle Capture
                            NavigationButton(
                                title: "Vehicle",
                                subtitle: "Capture a car in the wild",
                                icon: "car.fill",
                                gradient: [Color.blue, Color.cyan],
                                action: {
                                    showVehicleCapture = true
                                }
                            )
                            
                            // Driver Capture (Coming Soon)
                            NavigationButton(
                                title: "Driver",
                                subtitle: "Coming soon",
                                icon: "person.fill",
                                gradient: [Color.purple, Color.pink],
                                action: {
                                    // Coming soon
                                }
                            )
                            .opacity(0.5)
                            
                            // Location Capture (Coming Soon)
                            NavigationButton(
                                title: "Location",
                                subtitle: "Coming soon",
                                icon: "mappin.circle.fill",
                                gradient: [Color.green, Color.teal],
                                action: {
                                    // Coming soon
                                }
                            )
                            .opacity(0.5)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, isLandscape ? 0 : 80)
                .padding(.trailing, isLandscape ? 100 : 0)
                
                // Close button
                VStack {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.headerBackground)
                                .clipShape(Circle())
                        }
                        .padding(20)
                        
                        Spacer()
                    }
                    Spacer()
                }
            }
            .fullScreenCover(isPresented: $showVehicleCapture) {
                CameraView(
                    isPresented: $showVehicleCapture,
                    onCardSaved: { card in
                        onCardSaved?(card)
                        showVehicleCapture = false
                        dismiss()
                    }
                )
            }
        }
    }
}

#Preview {
    CaptureLandingView()
}
