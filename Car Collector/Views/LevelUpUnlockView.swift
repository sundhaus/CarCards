//
//  LevelUpUnlockView.swift
//  Car Collector
//
//  Full-screen celebration overlay shown when the user levels up
//  and unlocks a new feature or hits a milestone.
//

import SwiftUI

struct LevelUpUnlockView: View {
    let newLevel: Int
    let unlockedFeatures: [GatedFeature]
    let milestone: LevelMilestone?
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var showFeatures = false
    @State private var showMilestone = false
    @State private var particlePhase = 0.0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: 24) {
                Spacer()
                
                // Level badge
                if showContent {
                    VStack(spacing: 12) {
                        Text("LEVEL UP!")
                            .font(.poppins(14))
                            .fontWeight(.bold)
                            .tracking(4)
                            .foregroundStyle(.secondary)
                        
                        Text("\(newLevel)")
                            .font(.poppins(72))
                            .fontWeight(.black)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.appAccent, Color(red: 1.0, green: 0.18, blue: 0.26)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .appAccent.opacity(0.5), radius: 20)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Unlocked features
                if showFeatures && !unlockedFeatures.isEmpty {
                    VStack(spacing: 16) {
                        Text("NEW UNLOCK")
                            .font(.poppins(12))
                            .fontWeight(.semibold)
                            .tracking(2)
                            .foregroundStyle(.yellow)
                        
                        ForEach(unlockedFeatures) { feature in
                            featureRow(feature)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Milestone reward
                if showMilestone, let milestone = milestone {
                    VStack(spacing: 12) {
                        Text("MILESTONE REWARD")
                            .font(.poppins(12))
                            .fontWeight(.semibold)
                            .tracking(2)
                            .foregroundStyle(.cyan)
                        
                        HStack(spacing: 20) {
                            if milestone.rewardCoins > 0 {
                                HStack(spacing: 4) {
                                    HeatCheckCoin(size: 20)
                                    Text("+\(milestone.rewardCoins)")
                                        .font(.poppins(18))
                                        .fontWeight(.bold)
                                        .foregroundStyle(.yellow)
                                }
                            }
                            
                            if milestone.rewardGems > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "diamond.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.cyan)
                                    Text("+\(milestone.rewardGems)")
                                        .font(.poppins(18))
                                        .fontWeight(.bold)
                                        .foregroundStyle(.cyan)
                                }
                            }
                        }
                        
                        // Crate label
                        HStack(spacing: 8) {
                            Image(systemName: "gift.fill")
                                .foregroundStyle(milestone.guaranteedMinRarity.color)
                            Text(milestone.crateLabel)
                                .font(.poppins(14))
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(milestone.guaranteedMinRarity.color.opacity(0.5), lineWidth: 1)
                                )
                        )
                        
                        Text("Guaranteed \(milestone.guaranteedMinRarity.rawValue.capitalized)+ cosmetic")
                            .font(.poppins(11))
                            .foregroundStyle(.secondary)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // Dismiss button
                if showContent {
                    Button(action: dismiss) {
                        Text("Continue")
                            .font(.poppins(16))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [.appAccent, Color(red: 1.0, green: 0.18, blue: 0.26)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
                showFeatures = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.7)) {
                showMilestone = true
            }
        }
    }
    
    private func featureRow(_ feature: GatedFeature) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: feature.themeColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: feature.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(.poppins(16))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text(feature.unlockDescription)
                    .font(.poppins(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "lock.open.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 24)
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            showContent = false
            showFeatures = false
            showMilestone = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Locked Feature Overlay

/// Overlay shown on gated content when the user hasn't reached the required level.
struct LockedFeatureOverlay: View {
    let feature: GatedFeature
    let currentLevel: Int
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.gray)
                
                Text(feature.displayName)
                    .font(.poppins(20))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Unlocks at Level \(feature.requiredLevel)")
                    .font(.poppins(14))
                    .foregroundStyle(.secondary)
                
                // Progress indicator
                let levelsToGo = feature.requiredLevel - currentLevel
                Text("\(levelsToGo) level\(levelsToGo == 1 ? "" : "s") to go")
                    .font(.poppins(12))
                    .foregroundStyle(
                        LinearGradient(
                            colors: feature.themeColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Mini progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: feature.themeColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * (Double(currentLevel) / Double(feature.requiredLevel)),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
                .frame(maxWidth: 200)
            }
            .padding(32)
        }
    }
}

// MARK: - Compact Locked Badge

/// Small lock badge shown on tab icons or buttons for locked features.
struct LockedBadge: View {
    let requiredLevel: Int
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8))
            Text("Lv.\(requiredLevel)")
                .font(.poppins(9))
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.85))
        )
    }
}

#Preview("Level Up - Feature Unlock") {
    LevelUpUnlockView(
        newLevel: 5,
        unlockedFeatures: [.headToHead],
        milestone: nil,
        onDismiss: {}
    )
}

#Preview("Level Up - Milestone") {
    LevelUpUnlockView(
        newLevel: 10,
        unlockedFeatures: [.customBackgrounds],
        milestone: LevelMilestone.milestone(for: 10),
        onDismiss: {}
    )
}

#Preview("Locked Overlay") {
    LockedFeatureOverlay(feature: .marketplace, currentLevel: 1)
}
