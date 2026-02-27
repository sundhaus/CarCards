//
//  CardTiltEffect.swift
//  Car Collector
//
//  Gyroscope-driven 3D tilt effect for cards.
//  Reads device attitude via CoreMotion and applies
//  rotation3DEffect so cards feel like physical objects.
//

import SwiftUI
import Combine
import CoreMotion

// MARK: - Motion Manager (Singleton)

@MainActor
final class CardMotionManager: ObservableObject {
    static let shared = CardMotionManager()
    
    @Published var pitch: Double = 0  // Forward/back tilt (nose up/down)
    @Published var roll: Double = 0   // Left/right tilt
    
    /// Whether the device is actively being tilted (delta-based, not absolute).
    /// True when pitch/roll are changing between frames; false when held steady
    /// at any angle. Smoothed with a short cooldown so it doesn't flicker.
    @Published var isMoving: Bool = false
    
    private let motionManager = CMMotionManager()
    private var referenceAttitude: CMAttitude?
    private var observerCount = 0
    
    // Delta tracking for isMoving
    private var previousPitch: Double = 0
    private var previousRoll: Double = 0
    private var stillFrameCount: Int = 0
    /// How many consecutive "still" frames before isMoving goes false.
    /// At 15fps update rate, 8 frames ≈ 0.5 seconds of stillness.
    private let stillThresholdFrames: Int = 8
    /// Minimum per-frame delta to count as "moving" (in radians, after smoothing).
    private let movementDeltaThreshold: Double = 0.0008
    
    private init() {}
    
    func startIfNeeded() {
        observerCount += 1
        guard observerCount == 1 else { return }
        
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Device motion not available (simulator?)")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 10.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Capture reference on first reading so "neutral" = however you're holding it
            if self.referenceAttitude == nil {
                self.referenceAttitude = motion.attitude.copy() as? CMAttitude
            }
            
            // Get attitude relative to initial hold position
            let attitude = motion.attitude
            if let ref = self.referenceAttitude {
                attitude.multiply(byInverseOf: ref)
            }
            
            // Clamp to reasonable range and apply smoothing
            let maxAngle = 0.15  // ~8.5 degrees max tilt
            let smoothing = 0.12  // Lower = smoother, higher = more responsive
            
            let targetPitch = max(-maxAngle, min(maxAngle, attitude.pitch))
            let targetRoll = max(-maxAngle, min(maxAngle, attitude.roll))
            
            Task { @MainActor in
                let newPitch = self.pitch + (targetPitch - self.pitch) * smoothing
                let newRoll = self.roll + (targetRoll - self.roll) * smoothing
                
                // Delta detection: compare against previous frame values
                let deltaPitch = abs(newPitch - self.previousPitch)
                let deltaRoll = abs(newRoll - self.previousRoll)
                let totalDelta = deltaPitch + deltaRoll
                
                if totalDelta > self.movementDeltaThreshold {
                    // Phone is actively moving
                    self.stillFrameCount = 0
                    if !self.isMoving {
                        withAnimation(.easeIn(duration: 0.15)) {
                            self.isMoving = true
                        }
                    }
                } else {
                    // Phone is steady at current angle
                    self.stillFrameCount += 1
                    if self.stillFrameCount >= self.stillThresholdFrames && self.isMoving {
                        withAnimation(.easeOut(duration: 0.4)) {
                            self.isMoving = false
                        }
                    }
                }
                
                // Store for next frame's delta comparison
                self.previousPitch = newPitch
                self.previousRoll = newRoll
                
                // Update published values
                self.pitch = newPitch
                self.roll = newRoll
            }
        }
        
        print("🔄 CardMotionManager started")
    }
    
    func stopIfNeeded() {
        observerCount -= 1
        guard observerCount <= 0 else { return }
        observerCount = 0
        
        motionManager.stopDeviceMotionUpdates()
        referenceAttitude = nil
        pitch = 0
        roll = 0
        previousPitch = 0
        previousRoll = 0
        stillFrameCount = 0
        isMoving = false
        
        print("⏹️ CardMotionManager stopped")
    }
    
    /// Reset the reference attitude to current position
    func recalibrate() {
        referenceAttitude = nil
    }
}

// MARK: - Tilt View Modifier

struct CardTiltModifier: ViewModifier {
    @ObservedObject private var motion = CardMotionManager.shared
    
    /// How strongly the card responds to tilt (1.0 = default, 2.0 = double)
    var intensity: Double
    
    /// Perspective for 3D effect (smaller = more dramatic)
    var perspective: CGFloat
    
    init(intensity: Double = 1.0, perspective: CGFloat = 0.5) {
        self.intensity = intensity
        self.perspective = perspective
    }
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(motion.pitch * 45 * intensity),
                axis: (x: -1, y: 0, z: 0),
                perspective: perspective
            )
            .rotation3DEffect(
                .degrees(motion.roll * 45 * intensity),
                axis: (x: 0, y: 1, z: 0),
                perspective: perspective
            )
            .onAppear {
                motion.startIfNeeded()
            }
            .onDisappear {
                motion.stopIfNeeded()
            }
    }
}

// MARK: - View Extension

extension View {
    /// Adds gyroscope-driven 3D tilt to a view.
    /// - Parameters:
    ///   - intensity: Multiplier for tilt amount (default 1.0)
    ///   - perspective: 3D perspective depth (default 0.5, smaller = more dramatic)
    func cardTilt(intensity: Double = 1.0, perspective: CGFloat = 0.5) -> some View {
        modifier(CardTiltModifier(intensity: intensity, perspective: perspective))
    }
    
    /// Rarity-aware tilt — automatically adjusts intensity based on rarity tier.
    /// Higher rarity = more dramatic tilt response.
    func cardTilt(for rarity: CardRarity?, perspective: CGFloat = 0.5) -> some View {
        let intensity = rarity?.tiltIntensity ?? 1.0
        return modifier(CardTiltModifier(intensity: intensity, perspective: perspective))
    }
}
