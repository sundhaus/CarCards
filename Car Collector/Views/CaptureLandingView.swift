//
//  CaptureLandingView.swift
//  CarCardCollector
//
//  Capture landing page with vehicle, driver, and location options
//

import SwiftUI

struct CaptureLandingView: View {
    var isLandscape: Bool = false
    var levelSystem: LevelSystem
    @Binding var selectedTab: Int
    var onCardSaved: ((SavedCard) -> Void)? = nil
    @State private var showCamera = false
    @State private var captureType: CaptureType = .vehicle
    @State private var capturedImage: UIImage?
    @State private var showDriverForm = false
    @State private var showLocationForm = false
    @State private var showDriverTypeSelector = false
    
    // Pending form flags — set before camera dismiss, acted on in onDismiss
    @State private var pendingDriverForm = false
    @State private var pendingLocationForm = false
    @State private var pendingCameraOpen = false
    
    // Card preview states
    @State private var showCardPreview = false
    @State private var pendingCardPreview = false
    @State private var previewCardImage: UIImage?
    @State private var previewMake = ""
    @State private var previewModel = ""
    @State private var previewGeneration = ""
    
    // Services
    @ObservedObject private var locationService = LocationService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("CAPTURE")
                            .font(.poppins(42))
                            .foregroundStyle(.primary)
                        
                        Text("Choose what to capture")
                            .font(.poppins(16))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 30)
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Vehicle Capture
                            NavigationButton(
                                title: "VEHICLE",
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
                                title: "DRIVER",
                                subtitle: "Capture a driver portrait",
                                icon: "person.fill",
                                gradient: [Color.purple, Color.pink],
                                action: {
                                    showDriverTypeSelector = true
                                }
                            )
                            
                            // Location Capture
                            NavigationButton(
                                title: "LOCATION",
                                subtitle: "Capture a special location",
                                icon: "mappin.circle.fill",
                                gradient: [Color.green, Color.teal],
                                action: {
                                    captureType = .location
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
            }
            .background { AppBackground() }
            // Camera for all capture types
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                // Fires AFTER camera fullScreenCover dismiss animation completes
                print("📤 Camera dismissed. pendingDriverForm=\(pendingDriverForm), pendingLocationForm=\(pendingLocationForm)")
                if pendingDriverForm {
                    pendingDriverForm = false
                    showDriverForm = true
                    print("🟢 showDriverForm = true")
                } else if pendingLocationForm {
                    pendingLocationForm = false
                    showLocationForm = true
                }
            }) {
                CameraView(
                    isPresented: $showCamera,
                    onCardSaved: { card in
                        // Vehicle flow - use existing AI detection
                        if captureType == .vehicle {
                            onCardSaved?(card)
                            showCamera = false
                            selectedTab = 4
                        } else {
                            // Driver or Location - store image, flag pending form, dismiss camera
                            capturedImage = card.image
                            print("📸 Stored capturedImage: \(capturedImage != nil ? "\(capturedImage!.size)" : "NIL")")
                            if captureType == .driver || captureType == .driverPlusVehicle {
                                pendingDriverForm = true
                                print("🏁 pendingDriverForm = true")
                            } else if captureType == .location {
                                pendingLocationForm = true
                            }
                            showCamera = false
                            // Form will show via onDismiss callback above
                        }
                    },
                    captureType: captureType
                )
            }
            // Driver type selector
            .sheet(isPresented: $showDriverTypeSelector, onDismiss: {
                // If a driver type was picked, open camera now that sheet is fully gone
                if pendingCameraOpen {
                    pendingCameraOpen = false
                    showCamera = true
                }
            }) {
                DriverTypeSelectorView(
                    onSelect: { type in
                        captureType = type
                        pendingCameraOpen = true
                        showDriverTypeSelector = false
                    }
                )
                .presentationDetents([.height(300)])
            }
            // Driver info form — fullScreenCover to avoid sheet presentation conflicts
            .fullScreenCover(isPresented: $showDriverForm, onDismiss: {
                if pendingCardPreview {
                    pendingCardPreview = false
                    showCardPreview = true
                }
            }) {
                if let image = capturedImage {
                    DriverInfoFormSheet(
                        capturedImage: image,
                        isDriverPlusVehicle: captureType == .driverPlusVehicle,
                        onComplete: { cardImage, firstName, lastName, nickname, vehicleName in
                            print("📝 Driver saved: \(firstName) \(lastName)" + (nickname.isEmpty ? "" : " (\(nickname))"))
                            
                            // Save to Firebase and local storage
                            Task {
                                do {
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
                                    
                                    levelSystem.addXP(10)
                                    print("✅ Driver card saved successfully")
                                    
                                    await MainActor.run {
                                        previewCardImage = cardImage
                                        previewMake = firstName
                                        previewModel = lastName
                                        previewGeneration = nickname.isEmpty ? "" : "(\(nickname))"
                                        
                                        pendingCardPreview = true
                                        showDriverForm = false
                                        // Preview will show via onDismiss callback above
                                    }
                                } catch {
                                    print("❌ Failed to save driver card: \(error)")
                                    await MainActor.run {
                                        showDriverForm = false
                                    }
                                }
                            }
                        }
                    )
                }
            }
            // Location info form — fullScreenCover
            .fullScreenCover(isPresented: $showLocationForm, onDismiss: {
                if pendingCardPreview {
                    pendingCardPreview = false
                    showCardPreview = true
                }
            }) {
                if let image = capturedImage {
                    LocationInfoFormSheet(
                        capturedImage: image,
                        onComplete: { cardImage, locationName in
                            print("📍 Location saved: \(locationName)")
                            
                            Task {
                                do {
                                    let firebaseId = try await CardService.shared.saveLocationCard(
                                        image: cardImage,
                                        locationName: locationName,
                                        capturedBy: UserService.shared.currentProfile?.username,
                                        capturedLocation: locationService.currentCity
                                    )
                                    
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
                                    
                                    levelSystem.addXP(10)
                                    print("✅ Location card saved successfully")
                                    
                                    await MainActor.run {
                                        previewCardImage = cardImage
                                        previewMake = locationName
                                        previewModel = ""
                                        previewGeneration = ""
                                        
                                        pendingCardPreview = true
                                        showLocationForm = false
                                    }
                                } catch {
                                    print("❌ Failed to save location card: \(error)")
                                    await MainActor.run {
                                        showLocationForm = false
                                    }
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
                        onWrongVehicle: nil,
                        showWrongVehicleButton: false
                    )
                    .onDisappear {
                        selectedTab = 4
                    }
                }
            }
        }
    }
}

#Preview {
    CaptureLandingView(levelSystem: LevelSystem(), selectedTab: .constant(2))
}
