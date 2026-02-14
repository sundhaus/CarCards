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
    @State private var showDriverLanding = false
    @State private var showLocationCapture = false
    @Environment(\.dismiss) private var dismiss
    
    // Driver flow states
    @State private var driverImage: UIImage?
    @State private var isDriverPlusVehicle = false
    @State private var showDriverInfo = false
    
    // Location flow states
    @State private var locationImage: UIImage?
    @State private var showLocationInfo = false
    
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
                            
                            // Driver Capture
                            NavigationButton(
                                title: "Driver",
                                subtitle: "Capture a driver portrait",
                                icon: "person.fill",
                                gradient: [Color.purple, Color.pink],
                                action: {
                                    showDriverLanding = true
                                }
                            )
                            
                            // Location Capture
                            NavigationButton(
                                title: "Location",
                                subtitle: "Capture a special location",
                                icon: "mappin.circle.fill",
                                gradient: [Color.green, Color.teal],
                                action: {
                                    showLocationCapture = true
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
            // Vehicle flow
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
            // Driver flow
            .fullScreenCover(isPresented: $showDriverLanding) {
                DriverCaptureLandingView(
                    isLandscape: isLandscape,
                    onDriverCaptured: { image, isPlusVehicle in
                        driverImage = image
                        isDriverPlusVehicle = isPlusVehicle
                        showDriverInfo = true
                    }
                )
            }
            .fullScreenCover(isPresented: $showDriverInfo) {
                if let image = driverImage {
                    DriverInfoView(
                        capturedImage: image,
                        isDriverPlusVehicle: isDriverPlusVehicle,
                        onComplete: { firstName, lastName, nickname in
                            print("📝 Driver saved: \(firstName) \(lastName) (\(nickname))")
                            // TODO: Save driver card with metadata
                            dismiss()
                        }
                    )
                }
            }
            // Location flow
            .fullScreenCover(isPresented: $showLocationCapture) {
                PhotoCaptureView(
                    isPresented: $showLocationCapture,
                    onPhotoCaptured: { image in
                        locationImage = image
                        showLocationInfo = true
                    }
                )
            }
            .fullScreenCover(isPresented: $showLocationInfo) {
                if let image = locationImage {
                    LocationInfoView(
                        capturedImage: image,
                        onComplete: { locationName in
                            print("📍 Location saved: \(locationName)")
                            // TODO: Save location card with metadata
                            dismiss()
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    CaptureLandingView()
}
