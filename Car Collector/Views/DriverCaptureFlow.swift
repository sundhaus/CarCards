//
//  DriverCaptureFlow.swift
//  CarCardCollector
//
//  Unified driver capture flow - no nested presentations
//

import SwiftUI

enum DriverCaptureStep {
    case selectType
    case camera
    case driverInfo
}

struct DriverCaptureFlow: View {
    var isLandscape: Bool = false
    var onComplete: ((UIImage, Bool, String, String, String) -> Void)? = nil
    
    @State private var currentStep: DriverCaptureStep = .selectType
    @State private var captureDriverPlusVehicle = false
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Explicit background - always visible
            Color(red: 0.1, green: 0.12, blue: 0.18)
                .ignoresSafeArea()
            
            Group {
                switch currentStep {
                case .selectType:
                    driverTypeSelection
                        .onAppear { print("🟢 Showing: Type Selection") }
                case .camera:
                    // Show a temporary placeholder while camera is active
                    Color.black
                        .onAppear { print("🟢 Camera active (fullScreenCover)") }
                case .driverInfo:
                    if let image = capturedImage {
                        driverInfoForm(image: image)
                            .onAppear { print("🟢 Showing: Driver Info Form") }
                            .transition(.opacity)
                    } else {
                        Text("Error: No image")
                            .foregroundStyle(.red)
                            .onAppear { print("🔴 ERROR: No captured image!") }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            // This closure runs AFTER the camera is dismissed
            print("📤 Camera fullScreenCover dismissed")
            // Wait a bit more for the dismissal animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔄 Now switching to .driverInfo step")
                currentStep = .driverInfo
                print("✅ Current step is now: \(currentStep)")
            }
        } content: {
            PhotoCaptureView(
                isPresented: $showCamera,
                onPhotoCaptured: { image in
                    print("📸 Photo captured, image size: \(image.size)")
                    capturedImage = image
                    print("💾 Image stored, dismissing camera...")
                    showCamera = false
                    // Don't change step here - wait for onDismiss
                }
            )
        }
        .onAppear {
            print("🎬 DriverCaptureFlow appeared, current step: \(currentStep)")
        }
    }
    
    private var driverTypeSelection: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("CAPTURE DRIVER")
                    .font(.poppins(42))
                    .foregroundStyle(.white)
                
                Text("Choose capture type")
                    .font(.poppins(16))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 60)
            .padding(.bottom, 30)
            
            // Options
            ScrollView {
                VStack(spacing: 16) {
                    NavigationButton(
                        title: "DRIVER",
                        subtitle: "Capture driver portrait",
                        icon: "person.fill",
                        gradient: [Color.purple, Color.pink],
                        action: {
                            captureDriverPlusVehicle = false
                            currentStep = .camera
                            showCamera = true
                        }
                    )
                    
                    NavigationButton(
                        title: "Driver + Vehicle",
                        subtitle: "Capture driver with their car",
                        icon: "person.and.background.dotted",
                        gradient: [Color.blue, Color.purple],
                        action: {
                            captureDriverPlusVehicle = true
                            currentStep = .camera
                            showCamera = true
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            
            Spacer()
        }
        .overlay(alignment: .topLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.pTitle2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(20)
        }
    }
    
    private func driverInfoForm(image: UIImage) -> some View {
        DriverInfoFormView(
            capturedImage: image,
            isDriverPlusVehicle: captureDriverPlusVehicle,
            onComplete: { firstName, lastName, nickname in
                onComplete?(image, captureDriverPlusVehicle, firstName, lastName, nickname)
                dismiss()
            },
            onBack: {
                withAnimation {
                    currentStep = .selectType
                    capturedImage = nil
                }
            }
        )
    }
}

// Standalone driver info form without nested navigation
struct DriverInfoFormView: View {
    let capturedImage: UIImage
    let isDriverPlusVehicle: Bool
    var onComplete: ((String, String, String) -> Void)?
    var onBack: (() -> Void)?
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var nickname = ""
    @State private var showSignature = false
    @State private var signatureImage: UIImage?
    
    var body: some View {
        ZStack {
            // Explicit dark blue background
            Color(red: 0.1, green: 0.12, blue: 0.18)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("DRIVER INFO")
                    .font(.poppins(32))
                    .foregroundStyle(.white)
                
                Text("Add driver details")
                    .font(.poppins(16))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 60)
            
            // Preview image
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            
            // Form fields
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("First Name")
                        .font(.poppins(14))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    TextField("Required", text: $firstName)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Name")
                        .font(.poppins(14))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    TextField("Required", text: $lastName)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nickname (Optional)")
                        .font(.poppins(14))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    TextField("Optional", text: $nickname)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                Button(action: {
                    showSignature = true
                }) {
                    HStack {
                        Image(systemName: signatureImage != nil ? "checkmark.circle.fill" : "signature")
                            .font(.poppins(20))
                        
                        Text(signatureImage != nil ? "Signature Added" : "Add Signature")
                            .font(.poppins(16))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(signatureImage != nil ? Color.green.opacity(0.3) : Color.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(signatureImage != nil ? Color.green : Color.white.opacity(0.3), lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: {
                guard !firstName.isEmpty && !lastName.isEmpty else { return }
                onComplete?(firstName, lastName, nickname)
            }) {
                Text("Save Driver")
                    .font(.poppins(18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(firstName.isEmpty || lastName.isEmpty ? Color.gray : Color.blue)
                    )
            }
            .disabled(firstName.isEmpty || lastName.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .overlay(alignment: .topLeading) {
            Button(action: { onBack?() }) {
                Image(systemName: "chevron.left")
                    .font(.pTitle2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(20)
        }
        .fullScreenCover(isPresented: $showSignature) {
            SignatureView(
                cardImage: capturedImage,
                onSignatureComplete: { signature in
                    signatureImage = signature
                    showSignature = false
                }
            )
        }
        } // Close ZStack
    }
}

#Preview {
    DriverCaptureFlow()
}
