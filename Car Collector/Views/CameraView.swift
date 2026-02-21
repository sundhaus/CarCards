//
//  CameraView.swift
//  CarCardCollector
//
//  Advanced custom camera with professional features
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - LiDAR Depth Scanner (uses main camera session's depth output)
class LiDARDepthScanner: NSObject, AVCaptureDepthDataOutputDelegate {
    static let shared = LiDARDepthScanner()
    
    let isAvailable: Bool
    private var latestDepthMap: CVPixelBuffer?
    private var isAttached = false
    var hasDepthData: Bool { latestDepthMap != nil }
    let depthOutput = AVCaptureDepthDataOutput()
    
    override init() {
        // Check if device has LiDAR
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInLiDARDepthCamera],
            mediaType: .video,
            position: .back
        )
        isAvailable = !discovery.devices.isEmpty
        super.init()
        depthOutput.isFilteringEnabled = true
        depthOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "depthQueue"))
        print("📐 LiDAR available: \(isAvailable)")
    }
    
    /// Attach depth output to an existing camera session
    func attachToSession(_ session: AVCaptureSession) {
        guard isAvailable, !isAttached else { return }
        
        session.beginConfiguration()
        if session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
            isAttached = true
            print("📐 LiDAR depth output attached to camera session")
        } else {
            print("⚠️ Could not add depth output to session")
        }
        session.commitConfiguration()
    }
    
    func start() {
        // No-op — depth comes from main camera session
    }
    
    func stop() {
        latestDepthMap = nil
    }
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                         didOutput depthData: AVDepthData,
                         timestamp: CMTime,
                         connection: AVCaptureConnection) {
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        latestDepthMap = converted.depthDataMap
    }
    
    /// Check if the scene in front of the camera is flat (screen)
    func isSceneFlat() -> Bool {
        guard let depthMap = latestDepthMap else {
            print("🔍 LiDAR: no depth data yet")
            return false
        }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            print("🔍 LiDAR: couldn't read depth buffer")
            return false
        }
        
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size
        
        // Sample center 50%
        let startX = width / 4
        let endX = (width * 3) / 4
        let startY = height / 4
        let endY = (height * 3) / 4
        let step = max(1, (endX - startX) / 15)
        
        var depthValues: [Float] = []
        
        for y in stride(from: startY, to: endY, by: step) {
            for x in stride(from: startX, to: endX, by: step) {
                let value = floatBuffer[y * floatsPerRow + x]
                if value.isFinite && value > 0 && value < 10 {
                    depthValues.append(value)
                }
            }
        }
        
        guard depthValues.count > 20 else {
            print("🔍 LiDAR: insufficient samples (\(depthValues.count))")
            return false
        }
        
        let sorted = depthValues.sorted()
        let mean = depthValues.reduce(0, +) / Float(depthValues.count)
        
        // Use interquartile range to ignore edge noise (bezels, desk)
        let q1 = sorted[sorted.count / 4]
        let q3 = sorted[(sorted.count * 3) / 4]
        let iqr = q3 - q1
        
        let minDepth = sorted.first!
        let maxDepth = sorted.last!
        let fullRange = maxDepth - minDepth
        
        print("🔍 LiDAR depth: samples=\(depthValues.count), mean=\(String(format: "%.3f", mean))m, range=\(String(format: "%.3f", fullRange))m, IQR=\(String(format: "%.3f", iqr))m, min=\(String(format: "%.3f", minDepth))m, max=\(String(format: "%.3f", maxDepth))m")
        
        // A screen held up to the camera:
        // - Very close: mean < 0.75m (arm's length)
        // - Flat: IQR < 0.12m (screen + bezel edge noise)
        //   Real data: monitor at 0.47m → IQR=0.079m
        //
        // A real car/person even at close range:
        // - IQR > 0.20m (hood, windshield, background all different depths)
        
        if iqr < 0.12 && mean < 0.75 {
            print("🚫 LiDAR: flat surface — IQR \(String(format: "%.3f", iqr))m at \(String(format: "%.2f", mean))m (likely screen)")
            return true
        }
        
        return false
    }
}

// CAMERA SERVICE CLASS - MUST BE FIRST
class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var captureId: UUID? = nil  // Changes on each capture for onChange detection
    // Store EXIF metadata from capture for screen detection
    @Published var lastPhotoMetadata: [String: Any]? = nil
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
                
                // Attach LiDAR depth output to this session
                if LiDARDepthScanner.shared.isAvailable {
                    // Remove first in case it's already attached
                    self.session.removeOutput(LiDARDepthScanner.shared.depthOutput)
                    if self.session.canAddOutput(LiDARDepthScanner.shared.depthOutput) {
                        self.session.addOutput(LiDARDepthScanner.shared.depthOutput)
                        // Check if depth data is actually being delivered
                        if let connection = LiDARDepthScanner.shared.depthOutput.connection(with: .depthData) {
                            connection.isEnabled = true
                            print("📐 LiDAR depth output attached + connected")
                        } else {
                            print("⚠️ LiDAR depth output added but no depth connection available for this lens")
                        }
                    } else {
                        print("⚠️ Could not add LiDAR depth output to session")
                    }
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
        
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            return
        }
        
        // Store photo metadata for screen detection
        self.lastPhotoMetadata = photo.metadata
        
        // Also capture the current lens position (focus distance indicator)
        if let device = currentDevice {
            let lensPos = device.lensPosition  // 0.0 (far) to 1.0 (near)
            print("📐 Lens position at capture: \(String(format: "%.3f", lensPos))")
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
            OrientationManager.lockOrientation(.portrait)
            locationService.requestPermission()
            camera.checkPermissions()
        }
        .onDisappear {
            camera.stopSession()
            OrientationManager.unlockOrientation()
            // Don't stop LiDAR — keeps running for next camera open
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
        
        // LiDAR depth check — is the scene flat (screen)?
        let isFlat = LiDARDepthScanner.shared.isSceneFlat()
        
        isCheckingContent = false
        
        if isFlat {
            contentRejected = true
            rejectionMessage = "Photos of screens, screenshots, and downloaded images are not allowed. Please take a photo of a real subject."
            print("🚫 Image rejected: flat surface detected by LiDAR")
        } else {
            contentCheckedImage = image
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
