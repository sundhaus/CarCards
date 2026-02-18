//
//  LocationCaptureFlow.swift
//  CarCardCollector
//
//  Unified location capture flow - no nested presentations
//

import SwiftUI

enum LocationCaptureStep {
    case camera
    case locationInfo
}

struct LocationCaptureFlow: View {
    var isLandscape: Bool = false
    var onComplete: ((UIImage, String) -> Void)? = nil
    
    @State private var currentStep: LocationCaptureStep = .camera
    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Explicit background - always visible
            Color(red: 0.1, green: 0.12, blue: 0.18)
                .ignoresSafeArea()
            
            Group {
                switch currentStep {
                case .camera:
                    // Show a temporary placeholder while camera is active
                    Color.black
                        .onAppear { print("🟢 Location camera active (fullScreenCover)") }
                case .locationInfo:
                    if let image = capturedImage {
                        locationInfoForm(image: image)
                            .onAppear { print("🟢 Showing: Location Info Form") }
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
            print("📤 Location camera fullScreenCover dismissed")
            // Wait a bit for the dismissal animation to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔄 Now switching to .locationInfo step")
                currentStep = .locationInfo
                print("✅ Current step is now: \(currentStep)")
            }
        } content: {
            PhotoCaptureView(
                isPresented: $showCamera,
                onPhotoCaptured: { image in
                    print("📸 Location photo captured, image size: \(image.size)")
                    capturedImage = image
                    print("💾 Image stored, dismissing camera...")
                    showCamera = false
                    // Don't change step here - wait for onDismiss
                }
            )
        }
        .onAppear {
            print("🎬 LocationCaptureFlow appeared, current step: \(currentStep)")
            // Start with camera
            showCamera = true
        }
    }
    
    private func locationInfoForm(image: UIImage) -> some View {
        LocationInfoFormView(
            capturedImage: image,
            onComplete: { locationName in
                onComplete?(image, locationName)
                dismiss()
            },
            onCancel: {
                dismiss()
            }
        )
    }
}

// Standalone location info form
struct LocationInfoFormView: View {
    let capturedImage: UIImage
    var onComplete: ((String) -> Void)?
    var onCancel: (() -> Void)?
    
    @State private var locationName = ""
    
    var body: some View {
        ZStack {
            // Explicit dark blue background
            Color(red: 0.1, green: 0.12, blue: 0.18)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Location Info")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("Name this location")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 60)
            
            // Preview image
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 280, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            
            // Form field
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    TextField("Enter location name", text: $locationName)
                        .textFieldStyle(CustomTextFieldStyle())
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: {
                guard !locationName.isEmpty else { return }
                onComplete?(locationName)
            }) {
                Text("Save Location")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(locationName.isEmpty ? Color.gray : Color.green)
                    )
            }
            .disabled(locationName.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .overlay(alignment: .topLeading) {
            Button(action: { onCancel?() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(20)
        }
        } // Close ZStack
    }
}

#Preview {
    LocationCaptureFlow()
}
