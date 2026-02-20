//
//  CameraView.swift
//  CarCardCollector
//
//  Advanced custom camera with professional features
//

import SwiftUI
import AVFoundation
import Vision

// CAMERA SERVICE CLASS - MUST BE FIRST
class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var captureId: UUID? = nil  // Changes on each capture for onChange detection
    @Published var lastDepthData: AVDepthData? = nil  // Depth map from capture
    @Published var zoomFactor: CGFloat = 1.0
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var exposureValue: Float = 0.0
    @Published var isNightModeEnabled = false
    @Published var selectedFilter: CIFilter?
    @Published var aspectRatio: AspectRatio = .wide
    @Published var captureMode: CaptureMode = .heif
    @Published var availableLenses: [AVCaptureDevice] = []
    @Published var currentLensIndex = 1
    
    var output = AVCapturePhotoOutput()
    var videoOutput = AVCaptureVideoDataOutput()
    var preview: AVCaptureVideoPreviewLayer?
    private var currentDevice: AVCaptureDevice?
    private let context = CIContext()
    var previewLayer: CALayer?
    
    enum AspectRatio: String, CaseIterable {
        case standard = "4:3"
        case square = "1:1"
        case wide = "16:9"
    }
    
    enum CaptureMode: String, CaseIterable {
        case heif = "HEIF"
        case raw = "RAW"
        case heifRaw = "HEIF + RAW"
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    func setupCamera() {
        DispatchQueue.main.async {
            do {
                self.session.beginConfiguration()
                self.discoverLenses()
                
                guard self.currentLensIndex < self.availableLenses.count,
                      !self.availableLenses.isEmpty else {
                    self.session.commitConfiguration()
                    return
                }
                
                let device = self.availableLenses[self.currentLensIndex]
                self.currentDevice = device
                
                let input = try AVCaptureDeviceInput(device: device)
                self.session.inputs.forEach { self.session.removeInput($0) }
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                
                self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }
                
                self.session.sessionPreset = .photo
                self.output.maxPhotoQualityPrioritization = .quality
                
                // Enable depth data for screen detection
                if self.output.isDepthDataDeliverySupported {
                    self.output.isDepthDataDeliveryEnabled = true
                    print("📐 Depth data delivery enabled")
                } else {
                    print("⚠️ Depth data not supported on this device")
                }
                
                if self.output.availableRawPhotoPixelFormatTypes.count > 0 {
                    self.output.isAppleProRAWEnabled = self.output.isAppleProRAWSupported
                }
                
                self.session.commitConfiguration()
                self.startSession()
            } catch {
                print("Camera setup error: \(error)")
            }
        }
    }
    
    func discoverLenses() {
        // Try virtual multi-camera devices first (required for depth data)
        // These handle lens switching internally via zoom factor
        let virtualTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,       // Ultra-wide + Wide + Telephoto
            .builtInDualWideCamera,     // Ultra-wide + Wide
            .builtInDualCamera          // Wide + Telephoto
        ]
        
        let virtualDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: virtualTypes,
            mediaType: .video,
            position: .back
        )
        
        if let virtualDevice = virtualDiscovery.devices.first {
            // Use virtual device — supports depth and handles zoom internally
            availableLenses = [virtualDevice]
            print("📐 Using virtual camera: \(virtualDevice.deviceType) — depth supported")
            return
        }
        
        // Fallback to individual lenses if no virtual device
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera
        ]
        
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        
        availableLenses = discovery.devices
        print("⚠️ No virtual camera available — using individual lenses (no depth)")
    }
    
    func switchLens(to index: Int) {
        // With virtual camera (1 device), lens switching is handled by zoom factor
        // The virtual device auto-switches physical lenses at threshold zoom levels
        if availableLenses.count == 1 {
            return  // Zoom handles it
        }
        guard index < availableLenses.count else { return }
        currentLensIndex = index
        setupCamera()
    }
    
    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }
    
    func setZoom(_ zoom: CGFloat) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            let targetZoom = min(max(zoom, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.videoZoomFactor = targetZoom
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.zoomFactor = targetZoom
            }
        } catch {
            print("Zoom error: \(error)")
        }
    }
    
    func setExposure(_ value: Float) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            let clampedValue = min(max(value, -2), 2)
            device.setExposureTargetBias(clampedValue) { _ in }
            exposureValue = clampedValue
            device.unlockForConfiguration()
        } catch {
            print("Exposure error: \(error)")
        }
    }
    
    func toggleNightMode() {
        isNightModeEnabled.toggle()
    }
    
    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .auto
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
    }
    
    func setAspectRatio(_ ratio: AspectRatio) {
        aspectRatio = ratio
    }
    
    func setCaptureMode(_ mode: CaptureMode) {
        captureMode = mode
    }
    
    func capturePhoto() {
        let settings: AVCapturePhotoSettings
        
        switch captureMode {
        case .heif:
            settings = AVCapturePhotoSettings()
        case .raw:
            if let rawFormat = output.availableRawPhotoPixelFormatTypes.first {
                settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
            } else {
                settings = AVCapturePhotoSettings()
            }
        case .heifRaw:
            if let rawFormat = output.availableRawPhotoPixelFormatTypes.first {
                settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat,
                                                 processedFormat: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
        }
        
        if output.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        
        if isNightModeEnabled {
            settings.photoQualityPrioritization = .quality
        }
        
        settings.maxPhotoDimensions = output.maxPhotoDimensions
        
        // Request depth data for screen detection
        if output.isDepthDataDeliveryEnabled {
            settings.isDepthDataDeliveryEnabled = true
        }
        
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            return
        }
        
        // Store depth data for screen detection
        self.lastDepthData = photo.depthData
        if photo.depthData != nil {
            print("📐 Depth data captured with photo")
        } else {
            print("⚠️ No depth data in this photo")
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            return
        }
        
        image = normalizeOrientation(image: image)
        
        if let filter = selectedFilter,
           let ciImage = CIImage(image: image) {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            if let outputImage = filter.outputImage {
                let context = CIContext()
                if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                    image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
                }
            }
        }
        
        SubjectLifter.blurPrivacyRegions(in: image) { result in
            DispatchQueue.main.async {
                let newId = UUID()
                switch result {
                case .success(let blurredImage):
                    self.capturedImage = blurredImage
                case .failure:
                    self.capturedImage = image
                }
                self.captureId = newId
                print("📸 Capture complete, captureId=\(newId)")
            }
        }
    }
    
    private func normalizeOrientation(image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let filter = selectedFilter,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let previewLayer = previewLayer else {
            return
        }
        
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait:
            ciImage = ciImage.oriented(.right)
        case .portraitUpsideDown:
            ciImage = ciImage.oriented(.left)
        case .landscapeLeft:
            ciImage = ciImage.oriented(.up)
        case .landscapeRight:
            ciImage = ciImage.oriented(.down)
        default:
            ciImage = ciImage.oriented(.right)
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = filter.outputImage else {
            return
        }
        
        let scaleX = previewLayer.bounds.width / outputImage.extent.width
        let scaleY = previewLayer.bounds.height / outputImage.extent.height
        let scale = max(scaleX, scaleY)
        
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let cropRect = CGRect(
            x: (scaledImage.extent.width - previewLayer.bounds.width) / 2,
            y: (scaledImage.extent.height - previewLayer.bounds.height) / 2,
            width: previewLayer.bounds.width,
            height: previewLayer.bounds.height
        )
        
        guard let cgImage = context.createCGImage(scaledImage, from: cropRect) else {
            return
        }
        
        DispatchQueue.main.async {
            previewLayer.contents = cgImage
        }
    }
}

// NOW THE VIEW STRUCTS
struct CameraView: View {
    @Binding var isPresented: Bool
    let onCardSaved: (SavedCard) -> Void
    var captureType: CaptureType = .vehicle // Default to vehicle for backwards compatibility
    @StateObject private var camera = CameraService()
    @State private var lastZoomFactor: CGFloat = 1.0
    @ObservedObject private var locationService = LocationService.shared
    
    @State private var isCheckingContent = false
    @State private var contentRejected = false
    @State private var rejectionMessage = ""
    @State private var contentCheckedImage: UIImage? = nil
    @State private var lastCheckedId: UUID? = nil
    
    init(isPresented: Binding<Bool>, onCardSaved: @escaping (SavedCard) -> Void, captureType: CaptureType = .vehicle) {
        self._isPresented = isPresented
        self.onCardSaved = onCardSaved
        self.captureType = captureType
        print("📷 CameraView initialized with captureType: \(captureType)")
    }
    
    var body: some View {
        ZStack {
            // Camera preview is ALWAYS alive underneath
            ZStack {
                CameraPreview(camera: camera)
                    .ignoresSafeArea()
                
                // Only show controls when not in composer
                if camera.capturedImage == nil {
                    VStack {
                        HStack {
                            Button(action: {
                                OrientationManager.unlockOrientation()
                                isPresented = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.pTitle2)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding()
                            
                            Spacer()
                        }
                        
                        AdvancedCameraControls(camera: camera)
                        
                        Button(action: {
                            camera.capturePhoto()
                        }) {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                                .frame(width: 75, height: 75)
                                .overlay {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 65, height: 65)
                                }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .gesture(
                MagnificationGesture(minimumScaleDelta: 0.0)
                    .onChanged { value in
                        guard camera.capturedImage == nil else { return }
                        let delta = value / lastZoomFactor
                        lastZoomFactor = value
                        let newZoom = camera.zoomFactor * delta
                        camera.setZoom(newZoom)
                        
                        if newZoom < 1 && camera.availableLenses.count > 0 {
                            camera.switchLens(to: 0)
                        } else if newZoom >= 1 && newZoom < 2.5 && camera.availableLenses.count > 1 {
                            camera.switchLens(to: 1)
                        } else if newZoom >= 2.5 && camera.availableLenses.count > 2 {
                            camera.switchLens(to: 2)
                        }
                    }
                    .onEnded { _ in
                        lastZoomFactor = 1.0
                    }
            )
            
            // Checking overlay
            if isCheckingContent {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("CHECKING IMAGE...")
                            .font(.pCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .transition(.opacity)
            }
            
            // Content rejected overlay
            if contentRejected {
                ZStack {
                    Color.black.opacity(0.9)
                        .ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.red)
                        
                        Text("IMAGE REJECTED")
                            .font(.pTitle3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text("This image cannot be used to create a card.")
                            .font(.pSubheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Text(rejectionMessage)
                            .font(.pCaption)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            contentRejected = false
                            camera.capturedImage = nil
                            camera.captureId = nil
                            contentCheckedImage = nil
                            lastCheckedId = nil
                        }) {
                            Text("RETAKE PHOTO")
                                .font(.pSubheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.3))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                }
                .transition(.opacity)
            }
            
            // Composer overlays on top when image passes content check
            if let image = contentCheckedImage {
                CardComposerView(
                    image: image,
                    onSave: { image, make, model, color, year, specs in
                        let card = SavedCard(
                            image: image,
                            make: make,
                            model: model,
                            color: color,
                            year: year,
                            specs: specs,
                            capturedBy: UserService.shared.currentProfile?.username,
                            capturedLocation: locationService.currentCity,
                            previousOwners: 0
                        )
                        onCardSaved(card)
                    },
                    onRetake: {
                        // Just clear the image - camera is already running underneath
                        camera.capturedImage = nil
                        camera.captureId = nil
                        contentCheckedImage = nil
                        lastCheckedId = nil
                    },
                    captureType: captureType
                )
            }
        }
        .onAppear {
            camera.checkPermissions()
            OrientationManager.lockOrientation(.portrait)
            locationService.requestPermission()
        }
        .onDisappear {
            camera.stopSession()
            OrientationManager.unlockOrientation()
        }
        .onChange(of: camera.captureId) { _, newId in
            guard let newId = newId, newId != lastCheckedId else { return }
            guard let image = camera.capturedImage else { return }
            lastCheckedId = newId
            print("🔒 Content check triggered for captureId=\(newId), type=\(captureType)")
            checkContentSafety(image: image)
        }
    }
    
    // MARK: - Content Safety Check (on-device)
    
    private func checkContentSafety(image: UIImage) {
        isCheckingContent = true
        contentRejected = false
        rejectionMessage = ""
        
        Task {
            // Check 1: Depth-based screen detection (if available)
            if detectScreenPhoto(image: image) {
                await MainActor.run {
                    isCheckingContent = false
                    contentRejected = true
                    rejectionMessage = "Photos of screens, screenshots, and downloaded images are not allowed. Please take a photo of a real subject."
                    print("🚫 Image rejected: screen photo detected (depth)")
                }
                return
            }
            
            // Check 2: Vision classification (screens + NSFW combined)
            let result = await performVisionCheck(image: image)
            
            await MainActor.run {
                isCheckingContent = false
                switch result {
                case .safe:
                    contentCheckedImage = image
                case .screen:
                    contentRejected = true
                    rejectionMessage = "Photos of screens, screenshots, and downloaded images are not allowed. Please take a photo of a real subject."
                    print("🚫 Image rejected: screen detected by Vision")
                case .sensitive:
                    contentRejected = true
                    rejectionMessage = "This image contains sensitive content."
                    print("🚫 Image rejected: sensitive content")
                }
            }
        }
    }
    
    // MARK: - Screen Photo Detection (depth-based)
    
    /// Uses the camera's depth data to detect flat surfaces (screens).
    /// Real scenes have varied depth; a screen is all at one distance.
    private func detectScreenPhoto(image: UIImage) -> Bool {
        guard let depthData = camera.lastDepthData else {
            print("🔍 Screen detection: no depth data available — skipping depth check")
            return false
        }
        
        // Convert to disparity float32 for analysis
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        let depthMap = converted.depthDataMap
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            print("🔍 Screen detection: couldn't read depth buffer")
            return false
        }
        
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size
        
        // Sample a grid of depth values from the center region
        let sampleCount = 20
        let startX = width / 4
        let endX = (width * 3) / 4
        let startY = height / 4
        let endY = (height * 3) / 4
        let stepX = max(1, (endX - startX) / sampleCount)
        let stepY = max(1, (endY - startY) / sampleCount)
        
        var depthValues: [Float] = []
        
        for y in stride(from: startY, to: endY, by: stepY) {
            for x in stride(from: startX, to: endX, by: stepX) {
                let value = floatBuffer[y * floatsPerRow + x]
                // Skip NaN/invalid values
                if value.isFinite && value > 0 {
                    depthValues.append(value)
                }
            }
        }
        
        guard depthValues.count > 10 else {
            print("🔍 Screen detection: insufficient depth samples (\(depthValues.count))")
            return false
        }
        
        // Calculate depth variance
        let mean = depthValues.reduce(0, +) / Float(depthValues.count)
        let variance = depthValues.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(depthValues.count)
        let stdDev = sqrt(variance)
        let coeffOfVariation = mean != 0 ? stdDev / abs(mean) : 0
        
        print("🔍 Screen detection: depth samples=\(depthValues.count), mean=\(String(format: "%.4f", mean)), stdDev=\(String(format: "%.4f", stdDev)), CoV=\(String(format: "%.4f", coeffOfVariation))")
        
        // A flat screen has very low depth variation (CoV < 0.05)
        // Real scenes have objects at different distances (CoV > 0.10)
        if coeffOfVariation < 0.05 {
            print("🚫 Detected: flat depth profile — likely a screen (CoV=\(String(format: "%.4f", coeffOfVariation)))")
            return true
        }
        
        return false
    }
    
    // MARK: - Vision Classification Check (screen + sensitivity combined)
    
    private enum VisionResult {
        case safe
        case screen
        case sensitive
    }
    
    private func performVisionCheck(image: UIImage) async -> VisionResult {
        guard let cgImage = image.cgImage else { return .safe }
        
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    print("⚠️ Vision classification error: \(error) — allowing image")
                    continuation.resume(returning: .safe)
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: .safe)
                    return
                }
                
                // Log top 10 labels for debugging
                let topResults = results.prefix(10)
                print("🔍 Vision top labels:")
                for result in topResults {
                    print("   \(result.identifier): \(String(format: "%.1f%%", result.confidence * 100))")
                }
                
                // --- CHECK 1: Screen / document / screenshot detection ---
                let screenKeywords = [
                    "screenshot", "screen", "document", "computer_monitor",
                    "monitor", "display", "webpage", "web_page", "text_document"
                ]
                
                for result in results {
                    let label = result.identifier.lowercased()
                    let confidence = result.confidence
                    
                    for keyword in screenKeywords {
                        if label.contains(keyword) && confidence > 0.5 {
                            print("🚫 Vision screen detect: \(label) (\(String(format: "%.1f%%", confidence * 100)))")
                            continuation.resume(returning: .screen)
                            return
                        }
                    }
                }
                
                // --- CHECK 1b: Photo-of-photo detection ---
                // When the top labels are art/painting/poster, it means
                // Vision sees a picture within the photo (screen, print, poster)
                let photoOfPhotoLabels: Set<String> = [
                    "art", "painting", "poster", "graphic_design", "illustration",
                    "drawing", "cartoon", "comic", "print", "photograph",
                    "picture_frame", "collage", "mural"
                ]
                
                // Check if top-2 labels are both photo-of-photo indicators
                let top3 = results.prefix(3)
                let photoOfPhotoHits = top3.filter { result in
                    photoOfPhotoLabels.contains(result.identifier.lowercased()) && result.confidence > 0.10
                }
                
                if photoOfPhotoHits.count >= 2 {
                    let labels = photoOfPhotoHits.map { "\($0.identifier) \(String(format: "%.1f%%", $0.confidence * 100))" }.joined(separator: ", ")
                    print("🚫 Vision photo-of-photo detect: \(labels)")
                    continuation.resume(returning: .screen)
                    return
                }
                
                // --- CHECK 2: NSFW / sensitive content ---
                let sensitiveKeywords = [
                    "explicit", "nude", "nudity", "sexually", "underwear",
                    "bikini", "lingerie", "brassiere", "swimwear",
                    "topless", "erotic", "pornograph", "adult_content",
                    "nsfw", "intimate", "provocative"
                ]
                
                for result in results {
                    let label = result.identifier.lowercased()
                    let confidence = result.confidence
                    
                    for keyword in sensitiveKeywords {
                        if label.contains(keyword) && confidence > 0.5 {
                            print("🚫 Vision flagged: \(label) (\(String(format: "%.1f%%", confidence * 100)))")
                            continuation.resume(returning: .sensitive)
                            return
                        }
                    }
                }
                
                print("✅ Image passed all Vision checks")
                continuation.resume(returning: .safe)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("⚠️ Vision handler error: \(error) — allowing image")
                continuation.resume(returning: .safe)
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraService
    
    func makeUIView(context: Context) -> FilterPreviewView {
        let view = FilterPreviewView()
        
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview?.frame = view.bounds
        camera.preview?.videoGravity = .resizeAspect
        
        if let preview = camera.preview {
            view.layer.addSublayer(preview)
        }
        
        let filterLayer = CALayer()
        filterLayer.frame = view.bounds
        view.layer.addSublayer(filterLayer)
        camera.previewLayer = filterLayer
        view.filterLayer = filterLayer
        
        camera.startSession()
        
        return view
    }
    
    func updateUIView(_ uiView: FilterPreviewView, context: Context) {
        DispatchQueue.main.async {
            camera.preview?.frame = uiView.bounds
            uiView.filterLayer?.frame = uiView.bounds
            uiView.filterLayer?.isHidden = camera.selectedFilter == nil
        }
    }
}

class FilterPreviewView: UIView {
    var filterLayer: CALayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        filterLayer?.frame = bounds
        filterLayer?.contentsGravity = .resizeAspectFill
    }
}
