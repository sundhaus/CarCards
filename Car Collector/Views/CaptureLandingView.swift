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
    
    // Vehicle camera
    @State private var showVehicleCamera = false
    
    // Driver flow — completely separate
    @State private var showDriverTypeSelector = false
    @State private var showDriverCamera = false
    @State private var driverCaptureType: CaptureType = .driver
    @State private var driverFormImage: IdentifiableImage? = nil
    
    // Location flow — separate
    @State private var showLocationCamera = false
    @State private var locationCapturedImage: UIImage?
    @State private var showLocationForm = false
    
    // Card preview states (shared — just shows a confirmation)
    @State private var showCardPreview = false
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
                            NavigationButton(
                                title: "VEHICLE",
                                subtitle: "Capture a car in the wild",
                                icon: "car.fill",
                                gradient: [Color.blue, Color.cyan],
                                action: { showVehicleCamera = true }
                            )
                            
                            NavigationButton(
                                title: "DRIVER",
                                subtitle: "Capture a driver portrait",
                                icon: "person.fill",
                                gradient: [Color.purple, Color.pink],
                                action: { showDriverTypeSelector = true }
                            )
                            
                            NavigationButton(
                                title: "LOCATION",
                                subtitle: "Capture a special location",
                                icon: "mappin.circle.fill",
                                gradient: [Color.green, Color.teal],
                                action: { showLocationCamera = true }
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
            
            // ===========================================================
            // MARK: - VEHICLE FLOW
            // ===========================================================
            .fullScreenCover(isPresented: $showVehicleCamera) {
                CameraView(
                    isPresented: $showVehicleCamera,
                    onCardSaved: { card in
                        onCardSaved?(card)
                        showVehicleCamera = false
                        selectedTab = 4
                    },
                    captureType: .vehicle
                )
            }
            
            // ===========================================================
            // MARK: - DRIVER FLOW (completely independent)
            // ===========================================================
            
            // Step 1: Pick driver type
            .sheet(isPresented: $showDriverTypeSelector) {
                DriverTypeSelectorView(
                    onSelect: { type in
                        driverCaptureType = type
                        showDriverTypeSelector = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showDriverCamera = true
                        }
                    }
                )
                .presentationDetents([.height(300)])
            }
            
            // Step 2: Camera
            .fullScreenCover(isPresented: $showDriverCamera) {
                CameraView(
                    isPresented: $showDriverCamera,
                    onCardSaved: { card in
                        let img = card.image ?? UIImage(data: card.imageData)
                        if let img = img {
                            print("📸 Driver image: \(img.size)")
                            showDriverCamera = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                driverFormImage = IdentifiableImage(image: img)
                            }
                        } else {
                            print("❌ No driver image")
                            showDriverCamera = false
                        }
                    },
                    captureType: driverCaptureType
                )
            }
            
            // Step 3: Driver info form — item-based so image is passed directly
            .fullScreenCover(item: $driverFormImage) { wrapper in
                DriverInfoFormSheet(
                    capturedImage: wrapper.image,
                    isDriverPlusVehicle: driverCaptureType == .driverPlusVehicle,
                    onComplete: { cardImage, firstName, lastName, nickname, vehicleName in
                        print("📝 Driver: \(firstName) \(lastName)")
                        Task {
                            do {
                                let firebaseId = try await CardService.shared.saveDriverCard(
                                    image: cardImage,
                                    firstName: firstName,
                                    lastName: lastName,
                                    nickname: nickname,
                                    vehicleName: vehicleName,
                                    isDriverPlusVehicle: driverCaptureType == .driverPlusVehicle,
                                    capturedBy: UserService.shared.currentProfile?.username,
                                    capturedLocation: locationService.currentCity
                                )
                                let driverCard = DriverCard(
                                    image: cardImage,
                                    firstName: firstName,
                                    lastName: lastName,
                                    nickname: nickname,
                                    vehicleName: vehicleName,
                                    isDriverPlusVehicle: driverCaptureType == .driverPlusVehicle,
                                    capturedBy: UserService.shared.currentProfile?.username,
                                    capturedLocation: locationService.currentCity,
                                    firebaseId: firebaseId
                                )
                                var localCards = CardStorage.loadDriverCards()
                                localCards.append(driverCard)
                                CardStorage.saveDriverCards(localCards)
                                levelSystem.addXP(10)
                                print("✅ Driver card saved")
                                await MainActor.run {
                                    previewCardImage = cardImage
                                    previewMake = firstName
                                    previewModel = lastName
                                    previewGeneration = nickname.isEmpty ? "" : "(\(nickname))"
                                    driverFormImage = nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        showCardPreview = true
                                    }
                                }
                            } catch {
                                print("❌ Driver save failed: \(error)")
                                await MainActor.run { driverFormImage = nil }
                            }
                        }
                    }
                )
            }
            
            // ===========================================================
            // MARK: - LOCATION FLOW (completely independent)
            // ===========================================================
            .fullScreenCover(isPresented: $showLocationCamera) {
                CameraView(
                    isPresented: $showLocationCamera,
                    onCardSaved: { card in
                        if let img = card.image {
                            locationCapturedImage = img
                        } else {
                            locationCapturedImage = UIImage(data: card.imageData)
                        }
                        showLocationCamera = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showLocationForm = true
                        }
                    },
                    captureType: .location
                )
            }
            
            .fullScreenCover(isPresented: $showLocationForm) {
                Group {
                    if let image = locationCapturedImage {
                        LocationInfoFormSheet(
                            capturedImage: image,
                            onComplete: { cardImage, locationName in
                                print("📍 Location: \(locationName)")
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
                                        print("✅ Location card saved")
                                        await MainActor.run {
                                            previewCardImage = cardImage
                                            previewMake = locationName
                                            previewModel = ""
                                            previewGeneration = ""
                                            showLocationForm = false
                                            locationCapturedImage = nil
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                showCardPreview = true
                                            }
                                        }
                                    } catch {
                                        print("❌ Location save failed: \(error)")
                                        await MainActor.run { showLocationForm = false }
                                    }
                                }
                            }
                        )
                    } else {
                        Color.appBackgroundSolid.ignoresSafeArea()
                            .onAppear { showLocationForm = false }
                    }
                }
            }
            
            // ===========================================================
            // MARK: - SHARED: Card Preview confirmation
            // ===========================================================
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

// Wrapper to pass UIImage through fullScreenCover(item:)
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
