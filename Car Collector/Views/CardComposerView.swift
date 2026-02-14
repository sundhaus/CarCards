//
//  CardComposerView.swift
//  CarCardCollector
//
//  Screen for composing photo within card design
//  UPDATED: Added AI vehicle identification
//

import SwiftUI

struct CardComposerView: View {
    let image: UIImage
    let onSave: (UIImage, String, String, String, String, VehicleSpecs?) -> Void
    let onRetake: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var displayImage: UIImage = UIImage()
    @State private var isProcessing = false
    @State private var rotation: Angle = .zero
    @State private var isFlippedHorizontally = false
    @State private var isFlippedVertically = false
    
    // AI Identification
    @StateObject private var aiService = VehicleIdentificationService()
    @State private var previewData: PreviewData?
    @State private var dataToSave: PreviewData? // Hold data for onDismiss
    @State private var showAIError = false
    @State private var aiErrorMessage = ""
    @State private var isGeneratingSpecs = false
    @State private var alternativeVehicles: [VehicleIdentification] = []
    @State private var showAlternatives = false
    @State private var isFetchingAlternatives = false
    
    // Data model for preview screen
    struct PreviewData: Identifiable {
        let id = UUID()
        let cardImage: UIImage
        let make: String
        let model: String
        let generation: String
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Card frame with zoomable/pannable image (always 16:9 landscape)
                ZStack {
                    // The photo (zoomable and pannable) - full size preserved
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(x: isFlippedHorizontally ? -1 : 1, y: isFlippedVertically ? -1 : 1)
                        .rotationEffect(rotation)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: 360, height: 202.5)  // 16:9 crop frame
                        .clipped()
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    
                    // 16:9 horizontal frame border to show crop area
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 360, height: 202.5)
                        .allowsHitTesting(false)
                    
                    // Processing overlay
                    if isProcessing {
                        Color.black.opacity(0.5)
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                )
                
                // Transform controls below the card
                HStack(spacing: 15) {
                    Button(action: rotateLeft) {
                        Image(systemName: "rotate.left")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.gray.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: rotateRight) {
                        Image(systemName: "rotate.right")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.gray.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: flipHorizontal) {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.gray.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: flipVertical) {
                        Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.gray.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Remove background button
                Button(action: removeBackground) {
                    HStack {
                        Image(systemName: "scissors")
                        Text("Remove Background")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.blue)
                    .cornerRadius(20)
                }
                .disabled(isProcessing)
                .padding(.bottom, 10)
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: onRetake) {
                        Text("Retake")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red)
                            .cornerRadius(10)
                    }
                    
                    Button(action: saveWithAI) {
                        Text("Save")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .cornerRadius(10)
                    }
                    .disabled(aiService.isIdentifying)
                }
                .padding()
            }
            
            // Instructions
            VStack {
                Text("Pinch to zoom, drag to move")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding()
                
                Spacer()
            }
            
            // AI Processing overlay
            if aiService.isIdentifying {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.purple)
                    
                    Text("AI is analyzing your car...")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("This takes just a few seconds")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            // Specs generation overlay
            if isGeneratingSpecs {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2)
                        .tint(.green)
                    
                    Text("Fetching vehicle specs...")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Getting performance data")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .fullScreenCover(item: $previewData, onDismiss: {
            // Call onSave AFTER preview dismisses
            if let data = dataToSave {
                print("Saving card to garage...")
                // Specs will be fetched when user flips the card
                onSave(data.cardImage, data.make, data.model, "", data.generation, nil)
                dataToSave = nil
                previewData = nil
            }
        }) { data in
            CardPreviewView(
                cardImage: data.cardImage,
                make: data.make,
                model: data.model,
                generation: data.generation,
                onWrongVehicle: {
                    // User tapped "Not My Vehicle" - dismiss preview and fetch alternatives
                    print("🚫 User rejected vehicle identification")
                    print("📱 Dismissing preview...")
                    previewData = nil  // Dismiss the preview first
                    print("🔍 Fetching alternatives...")
                    Task {
                        await fetchAlternativeVehicles()
                    }
                }
            )
        }
        .alert("AI Identification Failed", isPresented: $showAIError) {
            Button("Try Again") {
                saveWithAI()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(aiErrorMessage)
        }
        .sheet(isPresented: $showAlternatives) {
            AlternativeVehiclesSheet(
                alternatives: alternativeVehicles,
                isFetching: isFetchingAlternatives,
                onSelect: { vehicle in
                    // User selected an alternative
                    print("✅ User selected: \(vehicle.make) \(vehicle.model)")
                    showAlternatives = false
                    previewData = nil
                    
                    // Create preview with selected vehicle
                    let finalImage = renderFinalCard()
                    previewData = PreviewData(
                        cardImage: finalImage,
                        make: vehicle.make,
                        model: vehicle.model,
                        generation: vehicle.generation
                    )
                },
                onCancel: {
                    print("❌ User cancelled alternative selection")
                    showAlternatives = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .onChange(of: showAlternatives) { oldValue, newValue in
            print("📊 showAlternatives changed: \(oldValue) → \(newValue)")
        }
        .onAppear {
            displayImage = image
            OrientationManager.lockOrientation(.portrait)
        }
        .onDisappear {
            OrientationManager.unlockOrientation()
        }
    }
    
    // Render the final composed card as a single image
    private func renderFinalCard() -> UIImage {
        // Horizontal 16:9 aspect ratio (landscape card)
        let cardSize = CGSize(width: 360, height: 202.5)
        
        // Create a renderer with the card size
        let renderer = UIGraphicsImageRenderer(size: cardSize)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Save the context state
            cgContext.saveGState()
            
            // Set up clipping to card bounds
            cgContext.clip(to: CGRect(origin: .zero, size: cardSize))
            
            // Move to center for transformations
            cgContext.translateBy(x: cardSize.width / 2, y: cardSize.height / 2)
            
            // Apply transformations in REVERSE order because CGContext transforms coordinate system
            // SwiftUI applies modifiers inside-out: offset -> scale -> rotation -> flip
            // So CGContext needs: flip -> rotation -> scale -> offset (reversed)
            cgContext.translateBy(x: offset.width, y: offset.height)
            cgContext.scaleBy(x: scale, y: scale)
            cgContext.rotate(by: rotation.radians)
            cgContext.scaleBy(x: isFlippedHorizontally ? -1 : 1, y: isFlippedVertically ? -1 : 1)
            
            // Calculate image size to fill the frame while maintaining aspect ratio
            let imageSize = displayImage.size
            let imageAspect = imageSize.width / imageSize.height
            let frameAspect = cardSize.width / cardSize.height
            
            var drawSize: CGSize
            if imageAspect > frameAspect {
                // Image is wider - fit to height
                drawSize = CGSize(width: cardSize.height * imageAspect, height: cardSize.height)
            } else {
                // Image is taller - fit to width
                drawSize = CGSize(width: cardSize.width, height: cardSize.width / imageAspect)
            }
            
            // Draw the image centered
            let imageRect = CGRect(
                x: -drawSize.width / 2,
                y: -drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            
            // Use UIImage.draw which respects orientation and uses aspect fill
            displayImage.draw(in: imageRect)
            
            // Restore the context state
            cgContext.restoreGState()
        }
    }
    
    private func removeBackground() {
        isProcessing = true
        
        SubjectLifter.liftSubject(from: image) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let processedImage):
                    displayImage = processedImage
                case .failure(let error):
                    print("Background removal failed: \(error)")
                    // Keep original image if it fails
                }
            }
        }
    }
    
    private func rotateLeft() {
        rotation -= .degrees(90)
    }
    
    private func rotateRight() {
        rotation += .degrees(90)
    }
    
    private func flipHorizontal() {
        isFlippedHorizontally.toggle()
    }
    
    private func flipVertical() {
        isFlippedVertically.toggle()
    }
    
    // MARK: - AI Identification & Save
    
    private func saveWithAI() {
        Task {
            let result = await aiService.identifyVehicle(from: displayImage)
            
            await MainActor.run {
                switch result {
                case .success(let identification):
                    print("âœ… AI Success: \(identification.make) \(identification.model) \(identification.generation)")
                    
                    // Prepare card and data for preview
                    let finalCardImage = renderFinalCard()
                    print("ðŸ–¼ï¸ Card rendered: \(finalCardImage.size)")
                    
                    // Create preview data object
                    let data = PreviewData(
                        cardImage: finalCardImage,
                        make: identification.make,
                        model: identification.model,
                        generation: identification.generation
                    )
                    
                    print("ðŸ’¾ Preview data created:")
                    print("   - Make: \(data.make)")
                    print("   - Model: \(data.model)")
                    print("   - Generation: \(data.generation)")
                    print("   - Image size: \(data.cardImage.size)")
                    
                    // Store data for saving later
                    dataToSave = data
                    
                    // Show preview by setting the data
                    print("ðŸ“± Showing card preview...")
                    previewData = data
                    
                case .failure(let error):
                    print("âŒ AI Failed: \(error.localizedDescription)")
                    aiErrorMessage = error.localizedDescription
                    showAIError = true
                }
            }
        }
    }
    
    private func fetchAlternativeVehicles() async {
        print("🔍 Fetching alternative vehicles...")
        isFetchingAlternatives = true
        showAlternatives = true
        
        let result = await aiService.identifyVehicleMultiple(from: displayImage)
        
        await MainActor.run {
            isFetchingAlternatives = false
            
            switch result {
            case .success(let vehicles):
                print("✅ Got \(vehicles.count) alternatives")
                alternativeVehicles = vehicles
            case .failure(let error):
                print("❌ Failed to get alternatives: \(error)")
                showAlternatives = false
                aiErrorMessage = "Failed to get alternative vehicles: \(error.localizedDescription)"
                showAIError = true
            }
        }
    }
}

// MARK: - Alternative Vehicles Sheet

struct AlternativeVehiclesSheet: View {
    let alternatives: [VehicleIdentification]
    let isFetching: Bool
    let onSelect: (VehicleIdentification) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                
                if isFetching {
                    loadingSection
                } else {
                    alternativesList
                }
                
                cancelButton
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            print("📋 AlternativeVehiclesSheet appeared")
            print("   Alternatives count: \(alternatives.count)")
            print("   Is fetching: \(isFetching)")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Choose Your Vehicle")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            Text("Select the correct match from these options")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Finding alternatives...")
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var alternativesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(alternatives) { vehicle in
                    vehicleButton(vehicle)
                }
            }
            .padding()
        }
    }
    
    private func vehicleButton(_ vehicle: VehicleIdentification) -> some View {
        Button(action: {
            onSelect(vehicle)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    vehicleInfo(vehicle)
                    Spacer()
                    confidenceBadge(vehicle)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func vehicleInfo(_ vehicle: VehicleIdentification) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(vehicle.make) \(vehicle.model)")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(vehicle.generation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func confidenceBadge(_ vehicle: VehicleIdentification) -> some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceIcon(vehicle.confidence))
                .foregroundStyle(confidenceColor(vehicle.confidence))
            Text(vehicle.confidence?.capitalized ?? "Unknown")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(confidenceColor(vehicle.confidence))
        }
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .cornerRadius(12)
        }
        .padding()
    }
    
    private func confidenceIcon(_ confidence: String?) -> String {
        guard let confidence = confidence else { return "questionmark.circle" }
        switch confidence.lowercased() {
        case "high": return "checkmark.circle.fill"
        case "medium": return "checkmark.circle"
        default: return "questionmark.circle"
        }
    }
    
    private func confidenceColor(_ confidence: String?) -> Color {
        guard let confidence = confidence else { return .gray }
        switch confidence.lowercased() {
        case "high": return .green
        case "medium": return .orange
        default: return .gray
        }
    }
}
