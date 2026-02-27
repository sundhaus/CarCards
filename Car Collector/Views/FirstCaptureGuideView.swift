//
//  FirstCaptureGuideView.swift
//  Car Collector
//
//  Guided first-capture experience shown immediately after onboarding.
//  The user sees a full-screen coach overlay that walks them through
//  capturing their very first car. After the card is saved, a celebration
//  reveal plays, then they land on the Home tab with tutorial quests visible.
//
//  Flow:
//    1. Welcome splash with pulsing camera button
//    2. Camera opens → user captures a car
//    3. Card saved → RarityRevealView plays
//    4. Dismiss → mark first capture complete → go to Home
//

import SwiftUI

struct FirstCaptureGuideView: View {
    let levelSystem: LevelSystem
    let onCardSaved: (SavedCard) -> Void
    let onComplete: () -> Void
    
    @State private var phase: GuidePhase = .welcome
    @State private var showCamera = false
    @State private var showRarityReveal = false
    @State private var savedCard: SavedCard?
    @State private var animateIn = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var showSkip = false
    
    enum GuidePhase {
        case welcome       // "Let's capture your first car!"
        case camera        // Camera is open
        case revealing     // Rarity reveal animation playing
        case done          // Transition to Home
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Subtle animated gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color(red: 0.02, green: 0.05, blue: 0.12),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if phase == .welcome {
                welcomeContent
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(
                isPresented: $showCamera,
                onCardSaved: { card in
                    savedCard = card
                    onCardSaved(card)
                    showCamera = false
                    phase = .revealing
                    
                    // Trigger rarity reveal after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showRarityReveal = true
                    }
                },
                captureType: .vehicle
            )
        }
        .fullScreenCover(isPresented: $showRarityReveal) {
            if let card = savedCard {
                RarityRevealView(card: card.asAnyCard) {
                    showRarityReveal = false
                    
                    // Mark first capture complete
                    TutorialQuestService.shared.completeFirstCapture()
                    
                    // Small delay before transitioning to Home
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        phase = .done
                        onComplete()
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateIn = true
            }
            // Show skip button after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation { showSkip = true }
            }
            // Start pulse animation
            startPulse()
        }
    }
    
    // MARK: - Welcome Content
    
    private var welcomeContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Coach content
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.6), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - Double(pulseScale))
                    
                    // Inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: .cyan.opacity(0.5), radius: 20)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
                .scaleEffect(animateIn ? 1.0 : 0.5)
                .opacity(animateIn ? 1.0 : 0.0)
                
                // Title
                VStack(spacing: 12) {
                    Text("SPOT YOUR FIRST CAR")
                        .font(.poppins(28))
                        .foregroundStyle(.white)
                        .opacity(animateIn ? 1.0 : 0.0)
                    
                    Text("Point your camera at any car to create\nyour first collector card")
                        .font(.poppins(16))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .opacity(animateIn ? 1.0 : 0.0)
                }
                
                // Feature hints
                VStack(spacing: 16) {
                    featureHint(icon: "sparkles", text: "AI identifies the car automatically")
                    featureHint(icon: "star.fill", text: "Every card gets a rarity — will you find a Legendary?")
                    featureHint(icon: "person.2.fill", text: "Trade and battle with friends")
                }
                .padding(.top, 8)
                .opacity(animateIn ? 1.0 : 0.0)
                .offset(y: animateIn ? 0 : 20)
            }
            
            Spacer()
            
            // CTA Button
            VStack(spacing: 16) {
                Button(action: {
                    phase = .camera
                    showCamera = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                        Text("Open Camera")
                            .font(.poppins(20))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: .cyan.opacity(0.4), radius: 12, y: 4)
                }
                .padding(.horizontal, 40)
                .scaleEffect(animateIn ? 1.0 : 0.9)
                .opacity(animateIn ? 1.0 : 0.0)
                
                // Skip option (appears after delay)
                if showSkip {
                    Button(action: {
                        // Skip first capture — mark as complete but don't record a capture
                        TutorialQuestService.shared.isFirstCaptureComplete = true
                        UserDefaults.standard.set(true, forKey: "firstCaptureGuideComplete")
                        onComplete()
                    }) {
                        Text("Skip for now")
                            .font(.poppins(14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .transition(.opacity)
                }
            }
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Feature Hint Row
    
    private func featureHint(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.cyan)
                .frame(width: 24)
            
            Text(text)
                .font(.poppins(14))
                .foregroundStyle(.white.opacity(0.8))
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Pulse Animation
    
    private func startPulse() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.15
        }
    }
}

#Preview {
    FirstCaptureGuideView(
        levelSystem: LevelSystem(),
        onCardSaved: { _ in },
        onComplete: {}
    )
}
