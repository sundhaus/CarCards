//
//  CardComposerView.swift
//  CarCardCollector
//
//  Two-phase composer:
//    Phase 1 — Crop/zoom/rotate the photo within the 16:9 card frame, then tap Save.
//    Phase 2 — AI identifies the vehicle, name appears on the card, user confirms or rejects.
//  "Not your vehicle?" lives here now (not on a separate preview screen).
//

import SwiftUI
import ImageIO

struct CardComposerView: View {
    let image: UIImage
    let onSave: (UIImage, String, String, String, String, VehicleSpecs?) -> Void
    let onRetake: () -> Void
    var captureType: CaptureType = .vehicle
    
    init(image: UIImage, onSave: @escaping (UIImage, String, String, String, String, VehicleSpecs?) -> Void, onRetake: @escaping () -> Void, captureType: CaptureType = .vehicle) {
        self.image = image
        self.onSave = onSave
        self.onRetake = onRetake
        self.captureType = captureType
    }
    
    // Image transform state
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
    @State private var identifiedMake: String = ""
    @State private var identifiedModel: String = ""
    @State private var identifiedGeneration: String = ""
    @State private var hasIdentified = false
    @State private var showAIError = false
    @State private var aiErrorMessage = ""
    @State private var renderedCardImage: UIImage?
    
    // Alternative vehicles
    @State private var alternativeVehicles: [VehicleIdentification] = []
    @State private var showAlternatives = false
    @State private var isFetchingAlternatives = false
    
    // Phase tracking
    private enum ComposerPhase {
        case cropping    // Phase 1: user adjusts image
        case identifying // Transition: AI is working
        case confirming  // Phase 2: name shown, user confirms
    }
    
    @State private var phase: ComposerPhase = .cropping
    
    private var shouldUseAI: Bool { captureType == .vehicle }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch phase {
            case .cropping:
                croppingPhaseView
            case .identifying:
                identifyingOverlay
            case .confirming:
                confirmingPhaseView
            }
        }
        .sheet(isPresented: $showAlternatives) {
            AlternativeVehiclesSheet(
                alternatives: alternativeVehicles,
                isFetching: isFetchingAlternatives,
                onSelect: { vehicle in
                    showAlternatives = false
                    identifiedMake = vehicle.make
                    identifiedModel = vehicle.model
                    identifiedGeneration = vehicle.generation
                    hasIdentified = true
                    phase = .confirming
                },
                onCancel: {
                    showAlternatives = false
                    onRetake()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .alert("AI Identification Failed", isPresented: $showAIError) {
            Button("Try Again") { runAIIdentification() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(aiErrorMessage)
        }
        .onAppear {
            displayImage = image
            OrientationManager.lockOrientation(.portrait)
        }
        .onDisappear {
            OrientationManager.unlockOrientation()
        }
    }
    
    // MARK: - Phase 1: Cropping
    
    private var croppingPhaseView: some View {
        VStack {
            Spacer()
            
            cardFrame
            transformControls
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 20) {
                Button(action: onRetake) {
                    Text("Retake")
                        .font(.pHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    if shouldUseAI {
                        runAIIdentification()
                    } else {
                        saveWithoutAI()
                    }
                }) {
                    Text("Save")
                        .font(.pHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .overlay(alignment: .top) {
            Text("Pinch to zoom, drag to move")
                .font(.pCaption)
                .foregroundStyle(.white)
                .padding()
                .background(.black.opacity(0.6))
                .cornerRadius(10)
                .padding()
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - Identifying Overlay
    
    private var identifyingOverlay: some View {
        VStack {
            Spacer()
            
            // Show the rendered card (locked — no more cropping)
            if let rendered = renderedCardImage {
                Image(uiImage: rendered)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 360, height: 202.5)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                    )
            }
            
            Spacer().frame(height: 40)
            
            ProgressView()
                .scaleEffect(2)
                .tint(.purple)
            
            Text("AI is analyzing your car...")
                .font(.pHeadline)
                .foregroundStyle(.white)
                .padding(.top, 20)
            
            Text("This takes just a few seconds")
                .font(.pSubheadline)
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
        }
    }
    
    // MARK: - Phase 2: Confirming
    
    private var confirmingPhaseView: some View {
        VStack {
            // "Not your vehicle?" in top-right
            HStack {
                Spacer()
                Button(action: {
                    Task { await fetchAlternativeVehicles() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.pCaption)
                        Text("Not your vehicle?")
                            .font(.pCaption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.9))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.3), radius: 5)
                }
                .padding()
            }
            
            Spacer()
            
            // Rendered card with name overlay
            if let rendered = renderedCardImage {
                ZStack {
                    Image(uiImage: rendered)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 360, height: 202.5)
                        .clipped()
                    
                    // White border overlay
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white, lineWidth: 3)
                    
                    // Car name overlay (top-left)
                    VStack {
                        HStack {
                            HStack(spacing: 4) {
                                Text(identifiedMake.uppercased())
                                    .font(.custom("Futura-Light", fixedSize: 14))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                                
                                if !identifiedModel.isEmpty {
                                    Text(identifiedModel.uppercased())
                                        .font(.custom("Futura-Bold", fixedSize: 14))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                                }
                            }
                            .padding(.leading, 12)
                            .padding(.top, 10)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .frame(width: 360, height: 202.5)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(color: .white.opacity(0.3), radius: 10)
            }
            
            // Car details below the card
            VStack(spacing: 8) {
                Text("\(identifiedMake) \(identifiedModel)")
                    .font(.pTitle2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                if !identifiedGeneration.isEmpty {
                    Text(identifiedGeneration)
                        .font(.pSubheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Confirm + Retake buttons
            HStack(spacing: 20) {
                Button(action: onRetake) {
                    Text("Retake")
                        .font(.pHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.8))
                        .cornerRadius(10)
                }
                
                Button(action: confirmAndSave) {
                    Text("Confirm")
                        .font(.pHeadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Shared Card Frame (Phase 1 — interactive crop)
    
    private var cardFrame: some View {
        ZStack {
            Image(uiImage: displayImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(x: isFlippedHorizontally ? -1 : 1, y: isFlippedVertically ? -1 : 1)
                .rotationEffect(rotation)
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: 360, height: 202.5)
                .clipped()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in scale = lastScale * value }
                        .onEnded { _ in lastScale = scale }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in lastOffset = offset }
                )
            
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white, lineWidth: 3)
                .allowsHitTesting(false)
            
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
    }
    
    // MARK: - Transform Controls
    
    private var transformControls: some View {
        HStack(spacing: 15) {
            Button(action: { rotation -= .degrees(90) }) {
                Image(systemName: "rotate.left")
                    .font(.pTitle3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.gray.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Button(action: { rotation += .degrees(90) }) {
                Image(systemName: "rotate.right")
                    .font(.pTitle3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.gray.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Button(action: { isFlippedHorizontally.toggle() }) {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    .font(.pTitle3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.gray.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Button(action: { isFlippedVertically.toggle() }) {
                Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                    .font(.pTitle3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.gray.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Actions
    
    private func runAIIdentification() {
        // Render the final card image (locks the crop)
        renderedCardImage = renderFinalCard()
        phase = .identifying
        
        Task {
            let result = await aiService.identifyVehicle(from: displayImage)
            
            await MainActor.run {
                switch result {
                case .success(let identification):
                    if identification.make == "Unknown" || identification.model == "Unknown" {
                        Task { await fetchAlternativeVehicles() }
                        return
                    }
                    
                    identifiedMake = identification.make
                    identifiedModel = identification.model
                    identifiedGeneration = identification.generation
                    hasIdentified = true
                    phase = .confirming
                    
                case .failure(let error):
                    aiErrorMessage = error.localizedDescription
                    showAIError = true
                    phase = .cropping
                }
            }
        }
    }
    
    private func confirmAndSave() {
        guard let cardImage = renderedCardImage else { return }
        onSave(cardImage, identifiedMake, identifiedModel, "", identifiedGeneration, nil)
    }
    
    private func saveWithoutAI() {
        let finalCardImage = renderFinalCard()
        onSave(finalCardImage, "", "", "", "", nil)
    }
    
    private func fetchAlternativeVehicles() async {
        isFetchingAlternatives = true
        showAlternatives = true
        
        let result = await aiService.identifyVehicleMultiple(from: displayImage)
        
        await MainActor.run {
            isFetchingAlternatives = false
            
            switch result {
            case .success(let vehicles):
                alternativeVehicles = vehicles
            case .failure(let error):
                showAlternatives = false
                aiErrorMessage = "Failed to get alternative vehicles: \(error.localizedDescription)"
                showAIError = true
                phase = .cropping
            }
        }
    }
    
    // MARK: - Render Final Card
    
    private func renderFinalCard() -> UIImage {
        let cardSize = CGSize(width: 360, height: 202.5)
        let renderer = UIGraphicsImageRenderer(size: cardSize)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.clip(to: CGRect(origin: .zero, size: cardSize))
            cgContext.translateBy(x: cardSize.width / 2, y: cardSize.height / 2)
            cgContext.translateBy(x: offset.width, y: offset.height)
            cgContext.scaleBy(x: scale, y: scale)
            cgContext.rotate(by: rotation.radians)
            cgContext.scaleBy(x: isFlippedHorizontally ? -1 : 1, y: isFlippedVertically ? -1 : 1)
            
            let imageSize = displayImage.size
            let imageAspect = imageSize.width / imageSize.height
            let frameAspect = cardSize.width / cardSize.height
            
            var drawSize: CGSize
            if imageAspect > frameAspect {
                drawSize = CGSize(width: cardSize.height * imageAspect, height: cardSize.height)
            } else {
                drawSize = CGSize(width: cardSize.width, height: cardSize.width / imageAspect)
            }
            
            let imageRect = CGRect(
                x: -drawSize.width / 2,
                y: -drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            
            displayImage.draw(in: imageRect)
            cgContext.restoreGState()
        }
    }
    
    /// Efficiently downsample an image using ImageIO
    private static func downsample(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        if longest <= maxDimension { return image }
        
        guard let data = image.jpegData(compressionQuality: 0.95) else { return image }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: image.imageOrientation)
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
    }
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Choose Your Vehicle")
                .font(.pTitle2)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            Text("Select the correct match from these options")
                .font(.pSubheadline)
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
        Button(action: { onSelect(vehicle) }) {
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
                .font(.pHeadline)
                .foregroundStyle(.primary)
            
            Text(vehicle.generation)
                .font(.pSubheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func confidenceBadge(_ vehicle: VehicleIdentification) -> some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceIcon(vehicle.confidence))
                .foregroundStyle(confidenceColor(vehicle.confidence))
            Text(vehicle.confidence?.capitalized ?? "Unknown")
                .font(.pCaption)
                .fontWeight(.semibold)
                .foregroundStyle(confidenceColor(vehicle.confidence))
        }
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.pHeadline)
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
