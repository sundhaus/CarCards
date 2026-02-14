//
//  DriverCaptureLandingView.swift
//  CarCardCollector
//
//  Driver capture options: Driver or Driver + Vehicle
//

import SwiftUI

struct DriverCaptureLandingView: View {
    var isLandscape: Bool = false
    var onDriverCaptured: ((UIImage, Bool) -> Void)? = nil // image, isDriverPlusVehicle
    @State private var showCamera = false
    @State private var captureDriverPlusVehicle = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Capture Driver")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Choose capture type")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 30)
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Driver Only
                            NavigationButton(
                                title: "Driver",
                                subtitle: "Capture driver portrait",
                                icon: "person.fill",
                                gradient: [Color.purple, Color.pink],
                                action: {
                                    captureDriverPlusVehicle = false
                                    showCamera = true
                                }
                            )
                            
                            // Driver + Vehicle
                            NavigationButton(
                                title: "Driver + Vehicle",
                                subtitle: "Capture driver with their car",
                                icon: "person.and.background.dotted",
                                gradient: [Color.blue, Color.purple],
                                action: {
                                    captureDriverPlusVehicle = true
                                    showCamera = true
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
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView(
                    isPresented: $showCamera,
                    onPhotoCaptured: { image in
                        // Pass the captured image back
                        onDriverCaptured?(image, captureDriverPlusVehicle)
                        showCamera = false
                        dismiss()
                    }
                )
            }
        }
    }
}

#Preview {
    DriverCaptureLandingView()
}
