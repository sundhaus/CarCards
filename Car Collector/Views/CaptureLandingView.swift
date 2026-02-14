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
    
    // Card preview states
    @State private var showCardPreview = false
    @State private var previewCardImage: UIImage?
    @State private var previewMake = ""
    @State private var previewModel = ""
    @State private var previewGeneration = ""
    
    // Services
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var levelSystem = LevelSystem.shared
    
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
                        onComplete: { cardImage, firstName, lastName, nickname, vehicleName in
                            print("📝 Driver saved: \(firstName) \(lastName)" + (nickname.isEmpty ? "" : " (\(nickname))"))
                            if !vehicleName.isEmpty {
                                print("   Vehicle: \(vehicleName)")
                            }
                            
                            // Save to Firebase and local storage
                            Task {
                                do {
                                    // Save to Firebase
                                    let firebaseId = try await CardService.shared.saveDriverCard(
                                        image: cardImage,
                                        firstName: firstName,
                                        lastName: lastName,
                                        nickname: nickname,
                                        vehicleName: vehicleName,
                                        isDriverPlusVehicle: captureType == .driverPlusVehicle,
                                        capturedBy: UserService.shared.currentProfile?.username,
                                        capturedLocation: locationService.currentCity
                                    )
                                    
                                    // Save to local storage
                                    let driverCard = DriverCard(
                                        image: cardImage,
                                        firstName: firstName,
                                        lastName: lastName,
                                        nickname: nickname,
                                        vehicleName: vehicleName,
                                        isDriverPlusVehicle: captureType == .driverPlusVehicle,
                                        capturedBy: UserService.shared.currentProfile?.username,
                                        capturedLocation: locationService.currentCity,
                                        firebaseId: firebaseId
                                    )
                                    
                                    var localCards = CardStorage.loadDriverCards()
                                    localCards.append(driverCard)
                                    CardStorage.saveDriverCards(localCards)
                                    
                                    // Award XP
                                    await levelSystem.addXP(10)
                                    
                                    print("✅ Driver card saved successfully")
                                    
                                    // Show card preview
                                    await MainActor.run {
                                        previewCardImage = cardImage
                                        previewMake = firstName
                                        previewModel = lastName
                                        previewGeneration = nickname.isEmpty ? "" : "(\(nickname))"
                                        
                                        showDriverForm = false
                                        showCardPreview = true
                                    }
                                } catch {
                                    print("❌ Failed to save driver card: \(error)")
                                }
                            }
                        }
                    )
                }
            }
            // Location info form
            .sheet(isPresented: $showLocationForm) {
                if let image = capturedImage {
                    LocationInfoFormSheet(
                        capturedImage: image,
                        onComplete: { cardImage, locationName in
                            print("📍 Location saved: \(locationName)")
                            
                            // Save to Firebase and local storage
                            Task {
                                do {
                                    // Save to Firebase
                                    let firebaseId = try await CardService.shared.saveLocationCard(
                                        image: cardImage,
                                        locationName: locationName,
                                        capturedBy: UserService.shared.currentProfile?.username,
                                        capturedLocation: locationService.currentCity
                                    )
                                    
                                    // Save to local storage
                                    let locationCard = LocationCard(
                                        image: cardImage,
                                        locationName: locationName,
                                        capturedBy: UserService.shared.currentProfile?.username,
                                        capturedLocation: locationService.currentCity,
                                        firebaseId: firebaseId
                                    )
                                    
                                    var localCards = CardStorage.loadLocationCards()
                                    localCards.append(locationCard)
                                    CardStorage.saveLocationCards(localCards)
                                    
                                    // Award XP
                                    await levelSystem.addXP(10)
                                    
                                    print("✅ Location card saved successfully")
                                    
                                    // Show card preview
                                    await MainActor.run {
                                        previewCardImage = cardImage
                                        previewMake = locationName
                                        previewModel = ""
                                        previewGeneration = ""
                                        
                                        showLocationForm = false
                                        showCardPreview = true
                                    }
                                } catch {
                                    print("❌ Failed to save location card: \(error)")
                                }
                            }
                        }
                    )
                }
            }
            // Card preview
            .fullScreenCover(isPresented: $showCardPreview) {
                if let cardImage = previewCardImage {
                    CardPreviewView(
                        cardImage: cardImage,
                        make: previewMake,
                        model: previewModel,
                        generation: previewGeneration,
                        onWrongVehicle: nil, // Not applicable for driver/location
                        showWrongVehicleButton: false // Hide "Not your vehicle" button
                    )
                    .onDisappear {
                        dismiss() // Dismiss CaptureLandingView when preview is dismissed
                    }
                }
            }
        }
    }
}

#Preview {
    CaptureLandingView()
}
