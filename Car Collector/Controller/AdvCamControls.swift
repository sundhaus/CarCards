//
//  AdvancedCameraControls.swift
//  CarCardCollector
//
//  Snapchat-style camera controls interface
//

import SwiftUI
import AVFoundation

struct AdvancedCameraControls: View {
    @ObservedObject var camera: CameraService
    @State private var showExposureSlider = false
    @State private var showDropdown = false
    @State private var currentFilterIndex = 0
    
    let filters: [(name: String, filter: CIFilter?)] = [
        ("None", nil),
        ("Vivid", CIFilter(name: "CIVibrance")),
        ("Chrome", CIFilter(name: "CIPhotoEffectChrome")),
        ("Noir", CIFilter(name: "CIPhotoEffectNoir")),
        ("Mono", CIFilter(name: "CIPhotoEffectMono"))
    ]
    
    var body: some View {
        ZStack {
            // Swipe gesture for filters
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { gesture in
                            if abs(gesture.translation.width) > abs(gesture.translation.height) {
                                if gesture.translation.width < 0 {
                                    // Swipe left - next filter
                                    nextFilter()
                                } else {
                                    // Swipe right - previous filter
                                    previousFilter()
                                }
                            }
                        }
                )
            
            VStack {
                HStack(alignment: .top) {
                    Spacer()
                    
                    // Right side vertical controls - positioned at very top
                    VStack(spacing: 12) {
                        // Flash
                        Button(action: { camera.toggleFlash() }) {
                            Image(systemName: flashIcon)
                                .font(.title2)
                                .foregroundStyle(flashColor)
                                .frame(width: 44, height: 44)
                        }
                        
                        // Exposure control with slider
                        VStack(spacing: 0) {
                            Button(action: {
                                withAnimation {
                                    showExposureSlider.toggle()
                                }
                            }) {
                                Image(systemName: "sun.max")
                                    .font(.title2)
                                    .foregroundStyle(showExposureSlider ? .yellow : .white)
                                    .frame(width: 44, height: 44)
                            }
                            
                            // Exposure slider (shows when sun tapped)
                            if showExposureSlider {
                                VStack(spacing: 8) {
                                    Text("+2.0")
                                        .font(.pCaption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.top, 8)
                                    
                                    // Vertical slider container
                                    GeometryReader { geometry in
                                        Slider(value: Binding(
                                            get: { camera.exposureValue },
                                            set: { camera.setExposure($0) }
                                        ), in: -2...2)
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: geometry.size.height, height: 40)
                                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                                        .accentColor(.yellow)
                                    }
                                    .frame(width: 40, height: 150)
                                    
                                    Text("-2.0")
                                        .font(.pCaption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.bottom, 8)
                                    
                                    // Current value indicator
                                    Text(String(format: "%.1f", camera.exposureValue))
                                        .font(.pCaption)
                                        .foregroundStyle(.yellow)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.black.opacity(0.6))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Dropdown options (appear first)
                        if showDropdown {
                            VStack(spacing: 12) {
                                // Capture mode toggle
                                Button(action: { toggleCaptureMode() }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: captureModeIcon)
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                        Text(camera.captureMode.rawValue)
                                            .font(.poppins(8))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: 44, height: 44)
                                }
                            }
                        }
                        
                        // Dropdown toggle (appears after dropdown content)
                        Button(action: {
                            withAnimation {
                                showDropdown.toggle()
                            }
                        }) {
                            Image(systemName: showDropdown ? "chevron.up" : "chevron.down")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer() // Pushes controls to top, prevents them from moving other elements
                    }
                    .padding(.trailing, 15)
                    .padding(.top, 15)
                }
                
                Spacer()
                
                // Filter indicator at bottom
                if currentFilterIndex != 0 {
                    Text(filters[currentFilterIndex].name)
                        .font(.pCaption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .cornerRadius(15)
                        .padding(.bottom, 100)
                }
                
                // Zoom control removed — LiDAR requires staying on primary camera device
                // Users can pinch-zoom in the composer after capture
            }
        }
        .onAppear {
            camera.selectedFilter = filters[0].filter
        }
    }
    
    private var flashIcon: String {
        switch camera.flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        @unknown default: return "bolt.slash"
        }
    }
    
    private var flashColor: Color {
        switch camera.flashMode {
        case .off: return .white
        case .on: return .yellow
        case .auto: return .orange
        @unknown default: return .white
        }
    }
    
    private var captureModeIcon: String {
        switch camera.captureMode {
        case .heif: return "photo"
        case .raw: return "camera.aperture"
        case .heifRaw: return "photo.stack"
        }
    }
    
    private func toggleCaptureMode() {
        let modes = CameraService.CaptureMode.allCases
        if let currentIndex = modes.firstIndex(of: camera.captureMode) {
            let nextIndex = (currentIndex + 1) % modes.count
            camera.setCaptureMode(modes[nextIndex])
        }
    }
    
    private func nextFilter() {
        currentFilterIndex = (currentFilterIndex + 1) % filters.count
        camera.selectedFilter = filters[currentFilterIndex].filter
    }
    
    private func previousFilter() {
        currentFilterIndex = (currentFilterIndex - 1 + filters.count) % filters.count
        camera.selectedFilter = filters[currentFilterIndex].filter
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// Simple zoom control - 3 bubbles + pinch to zoom
struct ZoomControl: View {
    @ObservedObject var camera: CameraService
    
    let zoomLevels: [CGFloat] = [0.5, 1, 5]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(zoomLevels, id: \.self) { level in
                ZoomBubble(
                    level: level,
                    currentZoom: camera.zoomFactor,
                    displayText: bubbleText(for: level)
                )
                .onTapGesture {
                    print("Bubble tapped: \(level)x, current zoom: \(camera.zoomFactor)")
                    camera.setZoom(level)
                    switchToLens(for: level)
                    print("After tap, zoom should be: \(level)")
                }
            }
        }
        .frame(height: 50)
    }
    
    private func bubbleText(for level: CGFloat) -> String {
        let zoom = camera.zoomFactor
        
        // Show current zoom in 1x bubble if not at exactly 0.5, 1, or 5
        if level == 1 {
            if abs(zoom - 0.5) < 0.01 || abs(zoom - 1.0) < 0.01 || abs(zoom - 5.0) < 0.01 {
                return "1"
            }
            // Display current zoom in 1x bubble
            if zoom == floor(zoom) {
                return "\(Int(zoom))"
            }
            return String(format: "%.1f", zoom)
        }
        
        // Default labels for 0.5x and 5x
        return level == floor(level) ? "\(Int(level))" : String(format: "%.1f", level)
    }
    
    private func switchToLens(for zoom: CGFloat) {
        // Auto-switch lenses based on zoom level
        if zoom < 1 && camera.availableLenses.count > 0 {
            camera.switchLens(to: 0) // Ultra-wide
        } else if zoom >= 1 && zoom < 2.5 && camera.availableLenses.count > 1 {
            camera.switchLens(to: 1) // Wide
        } else if zoom >= 2.5 && camera.availableLenses.count > 2 {
            camera.switchLens(to: 2) // Telephoto
        }
    }
}

struct ZoomBubble: View {
    let level: CGFloat
    let currentZoom: CGFloat
    let displayText: String
    
    var isActive: Bool {
        let active: Bool
        if level == 0.5 {
            active = currentZoom < 1
        } else if level == 1 {
            active = currentZoom >= 1 && currentZoom < 5
        } else if level == 5 {
            active = currentZoom >= 5
        } else {
            active = false
        }
        
        print("Bubble \(level)x: currentZoom=\(currentZoom), isActive=\(active)")
        return active
    }
    
    var body: some View {
        Text(displayText + "×")
            .font(.poppins(13))
            .foregroundStyle(isActive ? .yellow : .white.opacity(0.85))
            .frame(width: 44, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive ? Color.white.opacity(0.25) : Color.black.opacity(0.4))
            )
    }
}
