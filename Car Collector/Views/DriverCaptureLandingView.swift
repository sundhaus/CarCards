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
    @State private var capturedImage: UIImage?
    @State private var navigateToDriverInfo = false
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
                            .foregroundStyle(.primary)
                        
                        Text("Choose capture type")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
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
                                .background(.ultraThinMaterial)
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
                        capturedImage = image
                        showCamera = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            navigateToDriverInfo = true
                        }
                    }
                )
            }
            .navigationDestination(isPresented: $navigateToDriverInfo) {
                if let image = capturedImage {
                    DriverInfoView(
                        capturedImage: image,
                        isDriverPlusVehicle: captureDriverPlusVehicle,
                        onComplete: { firstName, lastName, nickname in
                            print("📝 Driver saved: \(firstName) \(lastName)" + (nickname.isEmpty ? "" : " (\(nickname))"))
                            onDriverCaptured?(image, captureDriverPlusVehicle)
                            dismiss()
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    DriverCaptureLandingView()
}
