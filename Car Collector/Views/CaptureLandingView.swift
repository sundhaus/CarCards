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
    @State private var showCamera = false
    @State private var captureType: CaptureType = .vehicle
    @State private var capturedImage: UIImage?
    @State private var showDriverForm = false
    @State private var showLocationForm = false
    @State private var showDriverTypeSelector = false
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
                                    captureType = .vehicle
                                    showCamera = true
                                }
                            )
                            
                            // Driver Capture
                            NavigationButton(
                                title: "Driver",
                                subtitle: "Capture a driver portrait",
                                icon: "person.fill",
                                gradient: [Color.purple, Color.pink],
                                action: {
                                    showDriverTypeSelector = true
                                }
                            )
                            
                            // Location Capture
                            NavigationButton(
                                title: "Location",
                                subtitle: "Capture a special location",
                                icon: "mappin.circle.fill",
                                gradient: [Color.green, Color.teal],
                                action: {
                                    print("📍 Location button tapped")
                                    captureType = .location
                                    print("   captureType set to: \(captureType)")
                                    showCamera = true
                                    print("   Opening camera with captureType: \(captureType)")
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
            // Camera for all capture types
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(
                    isPresented: $showCamera,
                    onCardSaved: { card in
                        // Vehicle flow - use existing AI detection
                        if captureType == .vehicle {
                            onCardSaved?(card)
                            showCamera = false
                            dismiss()
                        } else {
                            // Driver or Location - save image and show form
                            capturedImage = card.image
                            showCamera = false
                            if captureType == .driver || captureType == .driverPlusVehicle {
                                showDriverForm = true
                            } else if captureType == .location {
                                showLocationForm = true
                            }
                        }
                    },
                    captureType: captureType
                )
            }
            // Driver type selector
            .sheet(isPresented: $showDriverTypeSelector) {
                DriverTypeSelectorView(
                    onSelect: { type in
                        print("👤 Driver type selected: \(type)")
                        captureType = type
                        print("   captureType set to: \(captureType)")
                        showDriverTypeSelector = false
                        showCamera = true
                        print("   Opening camera with captureType: \(captureType)")
                    }
                )
                .presentationDetents([.height(300)])
            }
            // Driver info form
            .sheet(isPresented: $showDriverForm) {
                if let image = capturedImage {
                    DriverInfoFormSheet(
                        capturedImage: image,
                        isDriverPlusVehicle: captureType == .driverPlusVehicle,
                        onComplete: { firstName, lastName, nickname, vehicleName in
                            print("📝 Driver saved: \(firstName) \(lastName)" + (nickname.isEmpty ? "" : " (\(nickname))"))
                            print("   Vehicle: \(vehicleName)")
                            // TODO: Create driver card and show on CardDetailsView
                            showDriverForm = false
                            dismiss()
                        }
                    )
                }
            }
            // Location info form
            .sheet(isPresented: $showLocationForm) {
                if let image = capturedImage {
                    LocationInfoFormSheet(
                        capturedImage: image,
                        onComplete: { locationName in
                            print("📍 Location saved: \(locationName)")
                            // TODO: Create location card and show on CardDetailsView
                            showLocationForm = false
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
