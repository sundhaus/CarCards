//
//  CameraView.swift
//  CarCardCollector
//
//  Advanced custom camera with professional features
//  Now captures username and location metadata
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Binding var isPresented: Bool
    let onCardSaved: (SavedCard) -> Void
    @StateObject private var camera = CameraService()
    @State private var lastZoomFactor: CGFloat = 1.0
    @ObservedObject private var locationService = LocationService.shared
    
    var body: some View {
        ZStack {
            if let image = camera.capturedImage {
                // Show card composer after capture
                CardComposerView(
                    image: image,
                    onSave: { image, make, model, color, year, specs in
                        // Get username from UserService
                        let username = UserService.shared.currentProfile?.username
                        
                        // Get location from LocationService
                        let location = locationService.currentCity
                        
                        let card = SavedCard(
                            image: image,
                            make: make,
                            model: model,
                            color: color,
                            year: year,
                            specs: specs,
                            capturedBy: username,
                            capturedLocation: location,
                            previousOwners: 0
                        )
                        onCardSaved(card)
                    },
                    onRetake: {
                        camera.capturedImage = nil
                        camera.startSession()
                    }
                )
            } else {
                ZStack {
                    // Camera preview
                    CameraPreview(camera: camera)
                        .ignoresSafeArea()
                    
                    VStack {
                        // Close button
                        HStack {
                            Button(action: {
                                OrientationManager.unlockOrientation()
                                isPresented = false
                            }) {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding()
                            
                            Spacer()
                        }
                        
                        // Advanced camera controls
                        AdvancedCameraControls(camera: camera)
                        
                        // Capture button
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
                .gesture(
                    MagnificationGesture(minimumScaleDelta: 0.0)
                        .onChanged { value in
                            print("Pinch detected: \(value)")
                            let delta = value / lastZoomFactor
                            lastZoomFactor = value
                            let newZoom = camera.zoomFactor * delta
                            print("Setting zoom to: \(newZoom)")
                            camera.setZoom(newZoom)
                            
                            // Auto-switch lenses
                            if newZoom < 1 && camera.availableLenses.count > 0 {
                                camera.switchLens(to: 0)
                            } else if newZoom >= 1 && newZoom < 2.5 && camera.availableLenses.count > 1 {
                                camera.switchLens(to: 1)
                            } else if newZoom >= 2.5 && camera.availableLenses.count > 2 {
                                camera.switchLens(to: 2)
                            }
                        }
                        .onEnded { _ in
                            print("Pinch ended")
                            lastZoomFactor = 1.0
                        }
                )
            }
        }
        .onAppear {
            camera.checkPermissions()
            OrientationManager.lockOrientation(.portrait)
            
            // Request location permission - authorization callback will handle the rest
            locationService.requestPermission()
        }
        .onDisappear {
            camera.stopSession()
            OrientationManager.unlockOrientation()
        }
    }
}

// Camera preview with filter support
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraService
    
    func makeUIView(context: Context) -> FilterPreviewView {
        let view = FilterPreviewView()
        
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview?.frame = view.bounds
        // Use .resizeAspect to show FULL camera frame (not cropped/zoomed)
        // This matches what actually gets captured
        camera.preview?.videoGravity = .resizeAspect
        
        if let preview = camera.preview {
            view.layer.addSublayer(preview)
        }
        
        // Add filter layer
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
            
            // Hide filter layer if no filter selected
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

// Camera service with all advanced features
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
    @Published var currentLensIndex = 1 // Start with wide (1x)
    
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
                
                // Discover all available cameras
                self.discoverLenses()
                
                // Start with wide angle (1x)
                guard self.currentLensIndex < self.availableLenses.count,
                      !self.availableLenses.isEmpty else {
                    print("No lenses available")
                    self.session.commitConfiguration()
                    return
                }
                
                let device = self.availableLenses[self.currentLensIndex]
                self.currentDevice = device
                
                let input = try AVCaptureDeviceInput(device: device)
                
                // Remove existing inputs
                self.session.inputs.forEach { self.session.removeInput($0) }
                
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                // Configure output for high quality
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                
                // Add video output for real-time filter preview
                self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }
                
                // Enable high resolution capture
                self.session.sessionPreset = .photo
                self.output.maxPhotoQualityPrioritization = .quality
                
                // Configure for RAW if supported
                if self.output.availableRawPhotoPixelFormatTypes.count > 0 {
                    self.output.isAppleProRAWEnabled = self.output.isAppleProRAWSupported
                }
                
                self.session.commitConfiguration()
                
                print("Camera setup complete")
                self.startSession()
            } catch {
                print("Camera setup error: \(error)")
            }
        }
    }
    
    func discoverLenses() {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,  // 0.5x
            .builtInWideAngleCamera,  // 1x
            .builtInTelephotoCamera,  // 2x-3x
        ]
        
        var lenses: [AVCaptureDevice] = []
        
        for deviceType in deviceTypes {
            if let device = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
                lenses.append(device)
                print("Found lens: \(deviceType.rawValue)")
            }
        }
        
        self.availableLenses = lenses
        print("Total lenses discovered: \(lenses.count)")
    }
    
    func startSession() {
        DispatchQueue.global(qos: .background).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .background).async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    func switchLens(to index: Int) {
        guard index < availableLenses.count else { return }
        
        // Don't switch if already on this lens
        if currentLensIndex == index { return }
        
        currentLensIndex = index
        let newDevice = availableLenses[index]
        
        do {
            session.beginConfiguration()
            
            // Remove old input
            if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
                session.removeInput(currentInput)
            }
            
            // Add new input
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
            
            currentDevice = newDevice
            session.commitConfiguration()
            
            // Don't reset zoom - maintain current zoom level
            print("Switched to lens \(index), maintaining zoom: \(zoomFactor)")
        } catch {
            print("Lens switch error: \(error)")
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            // Don't clamp to device min/max - we'll switch lenses instead
            let targetZoom = min(max(factor, 0.5), 15)
            
            // Use the device's actual zoom capabilities
            let clampedZoom = min(max(targetZoom, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.videoZoomFactor = clampedZoom
            device.unlockForConfiguration()
            
            print("setZoom called with: \(factor), target: \(targetZoom), clamped to: \(clampedZoom)")
            
            // Update published property on main thread with TARGET zoom, not clamped
            DispatchQueue.main.async {
                self.zoomFactor = targetZoom
                print("zoomFactor updated to: \(self.zoomFactor)")
            }
        } catch {
            print("Zoom error: \(error)")
        }
    }
    
    func setExposure(_ value: Float) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Value ranges from -2 to +2
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
        
        // Configure based on capture mode
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
        
        // Set flash mode
        if output.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        
        // Enable night mode if toggled
        if isNightModeEnabled {
            settings.photoQualityPrioritization = .quality
        }
        
        // Set max resolution
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
        
        // Fix orientation first - normalize to .up
        image = normalizeOrientation(image: image)
        
        // DO NOT CROP HERE - send full image to composer
        // User will zoom/pan/rotate in composer, then crop happens in renderFinalCard()
        
        // Apply filter if selected
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
        
        // Blur faces and license plates
        SubjectLifter.blurPrivacyRegions(in: image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let blurredImage):
                    self.capturedImage = blurredImage
                case .failure(let error):
                    print("Privacy blur error: \(error)")
                    // Use original image if blur fails
                    self.capturedImage = image
                }
            }
        }
    }
    
    // Normalize image orientation to .up
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
    
    private func cropToAspectRatio(image: UIImage, ratio: AspectRatio) -> UIImage {
        let size = image.size
        var cropRect: CGRect
        
        switch ratio {
        case .standard: // 4:3
            let targetRatio: CGFloat = 4.0 / 3.0
            let currentRatio = size.width / size.height
            
            if currentRatio > targetRatio {
                let newWidth = size.height * targetRatio
                cropRect = CGRect(x: (size.width - newWidth) / 2, y: 0, width: newWidth, height: size.height)
            } else {
                let newHeight = size.width / targetRatio
                cropRect = CGRect(x: 0, y: (size.height - newHeight) / 2, width: size.width, height: newHeight)
            }
            
        case .square: // 1:1
            let dimension = min(size.width, size.height)
            cropRect = CGRect(x: (size.width - dimension) / 2,
                            y: (size.height - dimension) / 2,
                            width: dimension,
                            height: dimension)
            
        case .wide: // 16:9
            let targetRatio: CGFloat = 16.0 / 9.0
            let currentRatio = size.width / size.height
            
            if currentRatio > targetRatio {
                let newWidth = size.height * targetRatio
                cropRect = CGRect(x: (size.width - newWidth) / 2, y: 0, width: newWidth, height: size.height)
            } else {
                let newHeight = size.width / targetRatio
                cropRect = CGRect(x: 0, y: (size.height - newHeight) / 2, width: size.width, height: newHeight)
            }
        }
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // MARK: - Real-time filter preview
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let filter = selectedFilter,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let previewLayer = previewLayer else {
            return
        }
        
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply proper orientation for portrait mode
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
            ciImage = ciImage.oriented(.right) // Default to portrait
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = filter.outputImage else {
            return
        }
        
        // Scale to fit the preview layer
        let scaleX = previewLayer.bounds.width / outputImage.extent.width
        let scaleY = previewLayer.bounds.height / outputImage.extent.height
        let scale = max(scaleX, scaleY)
        
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Center crop
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
