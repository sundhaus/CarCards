//
//  DailyLoginPopup.swift
//  Car Collector
//
//  Minimal, transparent daily login popup that appears automatically on first login.
//  Designed to feel integrated with the app rather than disruptive.
//

import SwiftUI

struct DailyLoginPopup: View {
    @ObservedObject private var loginService = DailyLoginService.shared
    @ObservedObject private var userService = UserService.shared
    @Binding var isPresented: Bool
    
    @State private var animateIn = false
    @State private var showRewardPulse = false
    @State private var claimedToday = false
    @State private var isClaiming = false
    
    // Streak gradient that shifts from cool to warm as streak grows
    private var streakGradient: [Color] {
        let streak = loginService.currentStreak
        if streak >= 30 {
            return [Color.yellow, Color.red]
        } else if streak >= 14 {
            return [Color.orange, Color.red]
        } else if streak >= 7 {
            return [Color.orange, Color.yellow]
        } else if streak >= 3 {
            return [Color.cyan, Color.orange]
        } else {
            return [Color.blue, Color.cyan]
        }
    }
    
    var body: some View {
        ZStack {
            // Minimal dark transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main reward card - compact and minimal
                VStack(spacing: DeviceScale.h(16)) {
                    // Flame icon with subtle glow
                    ZStack {
                        // Subtle glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        streakGradient[0].opacity(0.2),
                                        streakGradient[0].opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(showRewardPulse ? 1.15 : 1.0)
                            .opacity(animateIn ? 1 : 0)
                        
                        // Flame icon
                        Image(systemName: "flame.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: streakGradient,
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .scaleEffect(animateIn ? 1.0 : 0.5)
                            .opacity(animateIn ? 1 : 0)
                    }
                    
                    // Streak count
                    Text("\(loginService.currentStreak) Day Streak")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(animateIn ? 1 : 0)
                    
                    if !claimedToday {
                        // Rewards preview
                        HStack(spacing: DeviceScale.w(24)) {
                            rewardBubble(
                                icon: "star.fill",
                                value: "+\(RewardConfig.dailyLoginXP)",
                                label: "XP",
                                colors: [.cyan, .blue]
                            )
                            
                            rewardBubble(
                                icon: "dollarsign.circle.fill",
                                value: "+\(RewardConfig.dailyLoginCoins)",
                                label: "Coins",
                                colors: [.yellow, .orange]
                            )
                        }
                        .padding(.vertical, DeviceScale.h(8))
                        .opacity(animateIn ? 1 : 0)
                        
                        // Claim button
                        Button(action: {
                            claimReward()
                        }) {
                            Group {
                                if isClaiming {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Claim Reward")
                                        .font(.poppins(16))
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: streakGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isClaiming)
                        .opacity(animateIn ? 1 : 0)
                    } else {
                        // Already claimed
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.green)
                            
                            Text("Reward Claimed!")
                                .font(.poppins(16))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 14)
                        .opacity(animateIn ? 1 : 0)
                    }
                    
                    // Tap to dismiss hint
                    Text("Tap anywhere to continue")
                        .font(.poppins(12))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 4)
                        .opacity(animateIn ? 1 : 0)
                }
                .padding(DeviceScale.w(24))
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                }
                .padding(.horizontal, DeviceScale.w(32))
                .scaleEffect(animateIn ? 1.0 : 0.85)
                .opacity(animateIn ? 1 : 0)
                
                Spacer()
            }
        }
        .onAppear {
            claimedToday = loginService.todayRewardClaimed
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                animateIn = true
            }
        }
    }
    
    private func rewardBubble(icon: String, value: String, label: String, colors: [Color]) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colors.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(value)
                .font(.poppins(16))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(label)
                .font(.poppins(10))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
    
    private func claimReward() {
        guard !isClaiming else { return }
        isClaiming = true
        
        Task {
            guard let uid = FirebaseManager.shared.currentUserId else {
                await MainActor.run {
                    isClaiming = false
                }
                return
            }
            
            let reward = await loginService.checkIn(uid: uid)
            
            await MainActor.run {
                if reward != nil {
                    claimedToday = true
                    
                    // Pulse animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        showRewardPulse = true
                    }
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Reset pulse
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation { showRewardPulse = false }
                    }
                    
                    // Auto-dismiss after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
                isClaiming = false
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            animateIn = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

#Preview("Fresh User") {
    DailyLoginPopup(isPresented: .constant(true))
}

#Preview("Claimed") {
    let service = DailyLoginService.shared
    service.currentStreak = 7
    service.todayRewardClaimed = true
    
    return DailyLoginPopup(isPresented: .constant(true))
}
