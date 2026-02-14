//
//  PhotoCaptureView.swift
//  CarCardCollector
//
//  Simple photo capture without AI identification
//

import SwiftUI
import AVFoundation

struct PhotoCaptureView: View {
    @Binding var isPresented: Bool
    var onPhotoCaptured: ((UIImage) -> Void)?
    
    @State private var capturedImage: UIImage?
    @State private var showComposer = false
    @StateObject private var camera = CameraController()
    
    var body: some View {
        ZStack {
            // Camera preview
            SimpleCameraPreview(camera: camera)
                .ignoresSafeArea()
            
            // Camera controls
            VStack {
                Spacer()
                
                HStack(spacing: 40) {
                    // Close button
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    // Capture button
                    Button(action: {
                        camera.capturePhoto { image in
                            capturedImage = image
                            showComposer = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 75, height: 75)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 65, height: 65)
                        }
                    }
                    
                    // Flip camera
                    Button(action: {
                        camera.flipCamera()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            camera.setupCamera()
        }
        .fullScreenCover(isPresented: $showComposer) {
            if let image = capturedImage {
                PhotoComposerView(
                    capturedImage: image,
                    onComplete: { composedImage in
                        onPhotoCaptured?(composedImage)
                        showComposer = false
                        isPresented = false
                    },
                    onCancel: {
                        showComposer = false
                        capturedImage = nil
                    }
                )
            }
        }
    }
}

// Simple photo composer (no AI identification)
struct PhotoComposerView: View {
    let capturedImage: UIImage
    var onComplete: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?
    
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        onCancel?()
                    }
                    .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text("Edit Photo")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button("Done") {
                        onComplete?(adjustedImage())
                    }
                    .foregroundStyle(.blue)
                }
                .padding()
                
                // Image preview
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .brightness(brightness)
                    .contrast(contrast)
                    .saturation(saturation)
                    .frame(maxHeight: .infinity)
                
                // Adjustment controls
                VStack(spacing: 16) {
                    // Brightness
                    HStack {
                        Image(systemName: "sun.max")
                            .foregroundStyle(.white)
                        Slider(value: $brightness, in: -0.5...0.5)
                        Text("\(Int(brightness * 100))")
                            .foregroundStyle(.white)
                            .frame(width: 40)
                    }
                    
                    // Contrast
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(.white)
                        Slider(value: $contrast, in: 0.5...2.0)
                        Text("\(Int(contrast * 100))")
                            .foregroundStyle(.white)
                            .frame(width: 40)
                    }
                    
                    // Saturation
                    HStack {
                        Image(systemName: "paintpalette")
                            .foregroundStyle(.white)
                        Slider(value: $saturation, in: 0...2.0)
                        Text("\(Int(saturation * 100))")
                            .foregroundStyle(.white)
                            .frame(width: 40)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
            }
        }
    }
    
    private func adjustedImage() -> UIImage {
        let context = CIContext()
        guard let ciImage = CIImage(image: capturedImage) else { return capturedImage }
        
        var outputImage = ciImage
        
        // Apply filters
        if let brightnessFilter = CIFilter(name: "CIColorControls") {
            brightnessFilter.setValue(outputImage, forKey: kCIInputImageKey)
            brightnessFilter.setValue(brightness, forKey: kCIInputBrightnessKey)
            brightnessFilter.setValue(contrast, forKey: kCIInputContrastKey)
            brightnessFilter.setValue(saturation, forKey: kCIInputSaturationKey)
            
            if let output = brightnessFilter.outputImage {
                outputImage = output
            }
        }
        
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return capturedImage
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// Simple camera controller
class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentCamera: AVCaptureDevice?
    private var photoCaptureCompletion: ((UIImage) -> Void)?
    
    func setupCamera() {
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        currentCamera = camera
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        photoCaptureCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func flipCamera() {
        session.beginConfiguration()
        
        // Remove current input
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        session.removeInput(currentInput)
        
        // Get opposite camera
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else { return }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                currentCamera = newCamera
            }
        } catch {
            print("Error flipping camera: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        
        DispatchQueue.main.async {
            self.photoCaptureCompletion?(image)
        }
    }
}

// Simple camera preview view
struct SimpleCameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraController
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

#Preview {
    PhotoCaptureView(isPresented: .constant(true))
}
