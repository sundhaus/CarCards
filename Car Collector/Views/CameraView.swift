//
//  CameraView.swift
//  CarCardCollector
//
//  Advanced custom camera with professional features
//

import SwiftUI
import AVFoundation
import SensitiveContentAnalysis

// CAMERA SERVICE CLASS - MUST BE FIRST
class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
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
    }
    
    func switchLens(to index: Int) {
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
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            return
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
                switch result {
                case .success(let blurredImage):
                    self.capturedImage = blurredImage
                case .failure:
                    self.capturedImage = image
                }
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
            
            // Content safety check overlay
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
                            contentCheckedImage = nil
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
                        contentCheckedImage = nil
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
        .onChange(of: camera.capturedImage) { _, newImage in
            guard let image = newImage else {
                contentCheckedImage = nil
                return
            }
            checkContentSafety(image: image)
        }
    }
    
    // MARK: - Content Safety Check (on-device)
    
    private func checkContentSafety(image: UIImage) {
        isCheckingContent = true
        contentRejected = false
        rejectionMessage = ""
        
        Task {
            // Check 1: Is this a photo of a screen / downloaded image?
            if detectScreenPhoto(image: image) {
                await MainActor.run {
                    isCheckingContent = false
                    contentRejected = true
                    rejectionMessage = "Photos of screens, screenshots, and downloaded images are not allowed. Please take a photo of a real subject."
                    print("🚫 Image rejected: screen photo detected")
                }
                return
            }
            
            // Check 2: Sensitive content (NSFW)
            let isSafe = await performSensitivityCheck(image: image)
            
            await MainActor.run {
                isCheckingContent = false
                if isSafe {
                    contentCheckedImage = image
                } else {
                    contentRejected = true
                    rejectionMessage = "This image contains sensitive content."
                    print("🚫 Image rejected: sensitive content")
                }
            }
        }
    }
    
    // MARK: - Screen Photo Detection (on-device, no AI)
    
    /// Detects photos of screens by analyzing color variance, edge patterns, and pixel uniformity
    private func detectScreenPhoto(image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Only analyze a center crop for performance
        let sampleSize = 200
        let cropX = max(0, (width - sampleSize) / 2)
        let cropY = max(0, (height - sampleSize) / 2)
        let cropW = min(sampleSize, width)
        let cropH = min(sampleSize, height)
        
        guard let cropped = cgImage.cropping(to: CGRect(x: cropX, y: cropY, width: cropW, height: cropH)) else {
            return false
        }
        
        // Get pixel data
        guard let data = cropped.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return false
        }
        
        let bytesPerPixel = cropped.bitsPerPixel / 8
        let bytesPerRow = cropped.bytesPerRow
        let totalPixels = cropW * cropH
        guard totalPixels > 100 else { return false }
        
        // Analyze pixel patterns
        var totalVariance: Double = 0
        var identicalNeighborCount = 0
        var totalComparisons = 0
        
        // Sample rows for horizontal pixel uniformity (screens have unnaturally uniform rows)
        let rowStep = max(1, cropH / 20)  // Sample ~20 rows
        
        for y in stride(from: 0, to: cropH - 1, by: rowStep) {
            for x in 0..<(cropW - 1) {
                let offset1 = y * bytesPerRow + x * bytesPerPixel
                let offset2 = y * bytesPerRow + (x + 1) * bytesPerPixel
                
                guard offset1 + 2 < CFDataGetLength(data),
                      offset2 + 2 < CFDataGetLength(data) else { continue }
                
                let r1 = Int(ptr[offset1])
                let g1 = Int(ptr[offset1 + 1])
                let b1 = Int(ptr[offset1 + 2])
                let r2 = Int(ptr[offset2])
                let g2 = Int(ptr[offset2 + 1])
                let b2 = Int(ptr[offset2 + 2])
                
                let diff = abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)
                totalVariance += Double(diff)
                totalComparisons += 1
                
                // Pixels that are exactly identical or differ by ≤1 per channel
                if diff <= 3 {
                    identicalNeighborCount += 1
                }
            }
        }
        
        guard totalComparisons > 0 else { return false }
        
        let avgVariance = totalVariance / Double(totalComparisons)
        let uniformityRatio = Double(identicalNeighborCount) / Double(totalComparisons)
        
        print("🔍 Screen detection: avgVariance=\(String(format: "%.1f", avgVariance)), uniformity=\(String(format: "%.3f", uniformityRatio))")
        
        // Screen photos have very low variance between adjacent pixels
        // and very high uniformity (digital images have flat color regions)
        // Real photos have natural noise, texture, and gradients
        //
        // Thresholds tuned to catch:
        // - Phone/monitor photos (very uniform, low variance)
        // - Downloaded/screenshot images (extremely uniform)
        // While allowing:
        // - Real car photos (have reflections, texture, environmental noise)
        // - Studio photos (still have lens artifacts and natural gradients)
        
        if uniformityRatio > 0.85 && avgVariance < 8.0 {
            print("🚫 Detected: extremely uniform image (likely screenshot or solid screen)")
            return true
        }
        
        if uniformityRatio > 0.75 && avgVariance < 4.0 {
            print("🚫 Detected: very low variance with high uniformity (likely screen photo)")
            return true
        }
        
        return false
    }
    
    // MARK: - Sensitive Content Check
    
    private func performSensitivityCheck(image: UIImage) async -> Bool {
        // Use Apple's SensitiveContentAnalysis (iOS 17+)
        if #available(iOS 17.0, *) {
            do {
                let analyzer = SCSensitivityAnalyzer()
                let policy = analyzer.analysisPolicy
                
                guard policy != .disabled else {
                    print("🔍 Content analysis disabled by user settings — allowing")
                    return true
                }
                
                guard let cgImage = image.cgImage else { return true }
                
                let result = try await analyzer.analyzeImage(cgImage)
                
                if result.isSensitive {
                    print("🚫 SensitiveContentAnalysis flagged image as sensitive")
                    return false
                }
                
                print("✅ Image passed sensitivity check")
                return true
            } catch {
                print("⚠️ SensitiveContentAnalysis error: \(error) — allowing image")
                return true
            }
        }
        
        print("⚠️ SensitiveContentAnalysis unavailable — allowing image")
        return true
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
