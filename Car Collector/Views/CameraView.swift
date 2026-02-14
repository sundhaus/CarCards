//
//  CameraView.swift
//  CarCardCollector
//
//  Advanced custom camera with professional features
//

import SwiftUI
import AVFoundation

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
    
    var body: some View {
        ZStack {
            if let image = camera.capturedImage {
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
                        camera.capturedImage = nil
                        camera.startSession()
                    },
                    captureType: captureType
                )
            } else {
                ZStack {
                    CameraPreview(camera: camera)
                        .ignoresSafeArea()
                    
                    VStack {
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
                .gesture(
                    MagnificationGesture(minimumScaleDelta: 0.0)
                        .onChanged { value in
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
