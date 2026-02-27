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
    @State private var animateCheckmarks: [Bool] = Array(repeating: false, count: 7)
    @State private var showConfetti = false
    @State private var waveOffset: CGFloat = 0
    
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
    
    // Calculate which days in the 7-day cycle are completed
    private var weekProgress: [DayProgress] {
        let currentDay = (loginService.currentStreak % 7)
        let cycleNumber = loginService.currentStreak / 7
        
        return (0..<7).map { index in
            let dayNumber = index + 1
            let isCompleted = index < currentDay
            let isToday = index == currentDay && !claimedToday
            let isMilestone = dayNumber == 7
            
            return DayProgress(
                dayNumber: dayNumber,
                isCompleted: isCompleted,
                isToday: isToday,
                isMilestone: isMilestone
            )
        }
    }
    
    private struct DayProgress {
        let dayNumber: Int
        let isCompleted: Bool
        let isToday: Bool
        let isMilestone: Bool
    }
    
    var body: some View {
        ZStack {
            // Darker transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main reward card with animated checkered background
                ZStack {
                    // Animated checkered flag background
                    checkeredBackground
                    
                    // Confetti overlay
                    if showConfetti {
                        confettiOverlay
                    }
                    
                    // Content
                    VStack(spacing: 6) {
                        // Flame icon - very small
                        ZStack {
                            // Simplified glow
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            streakGradient[0].opacity(0.3),
                                            streakGradient[0].opacity(0.0)
                                        ],
                                        center: .center,
                                        startRadius: 5,
                                        endRadius: 25
                                    )
                                )
                                .frame(width: 50, height: 50)
                                .scaleEffect(showRewardPulse ? 1.15 : 1.0)
                                .opacity(animateIn ? 1 : 0)
                            
                            // Flame icon
                            Image(systemName: "flame.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: streakGradient,
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .scaleEffect(animateIn ? 1.0 : 0.5)
                                .opacity(animateIn ? 1 : 0)
                                .shadow(color: streakGradient[1].opacity(0.5), radius: 3, y: 1)
                        }
                        
                        // Streak count - compact
                        Text("\(loginService.currentStreak) Day Streak")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .opacity(animateIn ? 1 : 0)
                        
                        // 7-Day progress tracker - minimal
                        HStack(spacing: 3) {
                            ForEach(Array(weekProgress.enumerated()), id: \.offset) { index, day in
                                miniDayCircle(day, index: index)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.2))
                        }
                        .opacity(animateIn ? 1 : 0)
                        
                        if !claimedToday {
                            // Rewards preview - very compact
                            HStack(spacing: 10) {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.cyan)
                                    Text("+\(RewardConfig.dailyLoginXP)")
                                        .font(.poppins(11))
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                                
                                HStack(spacing: 3) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.yellow)
                                    Text("+\(RewardConfig.dailyLoginCoins)")
                                        .font(.poppins(11))
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.vertical, 2)
                            .opacity(animateIn ? 1 : 0)
                            
                            // Claim button - minimal
                            Button(action: {
                                claimReward()
                            }) {
                                Group {
                                    if isClaiming {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.7)
                                    } else {
                                        Text("Claim")
                                            .font(.poppins(13))
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: streakGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: streakGradient[1].opacity(0.3), radius: 6, y: 3)
                            }
                            .disabled(isClaiming)
                            .opacity(animateIn ? 1 : 0)
                        } else {
                            // Already claimed - minimal
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.green)
                                
                                Text("Claimed!")
                                    .font(.poppins(12))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 6)
                            .opacity(animateIn ? 1 : 0)
                        }
                        
                        // Tap to dismiss hint - tiny
                        Text("Tap to dismiss")
                            .font(.poppins(8))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.top, 1)
                            .opacity(animateIn ? 1 : 0)
                        
                        // Next streak cosmetic milestone preview
                        if let milestone = DailyChallengeService.shared.nextStreakMilestone(currentStreak: loginService.currentStreak) {
                            HStack(spacing: 6) {
                                Image(systemName: milestone.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.yellow)
                                
                                Text("Day \(milestone.streakDay): \(milestone.name)")
                                    .font(.poppins(9))
                                    .foregroundStyle(.yellow.opacity(0.8))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.1))
                            .clipShape(Capsule())
                            .opacity(animateIn ? 1 : 0)
                        }
                    }
                    .padding(12)
                }
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            streakGradient[0].opacity(0.3),
                                            streakGradient[1].opacity(0.15),
                                            streakGradient[0].opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                }
                .frame(maxWidth: 220)  // Much smaller max width
                .padding(.horizontal, 60)
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
            
            // Stagger checkmark animations for completed days
            for (index, day) in weekProgress.enumerated() {
                if day.isCompleted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + (Double(index) * 0.08)) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            animateCheckmarks[index] = true
                        }
                    }
                }
            }
        }
    }
    
    // Animated checkered flag background
    private var checkeredBackground: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 140  // Larger squares for compact popup
            let columns = Int(size.width / squareSize) + 2
            let rows = Int(size.height / squareSize) + 2
            
            for row in 0..<rows {
                for col in 0..<columns {
                    let isChecked = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    
                    let baseOpacity = isChecked ? 0.03 : 0.15
                    let waveEffect = abs(sin((rect.minX + rect.minY + waveOffset) / 100)) * 0.3
                    let finalOpacity = baseOpacity * (1.0 - waveEffect)
                    
                    let color = isChecked
                        ? Color.white.opacity(finalOpacity)
                        : Color.black.opacity(finalOpacity)
                    
                    context.fill(
                        Path(rect),
                        with: .color(color)
                    )
                }
            }
        }
        .blur(radius: 0.5)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                waveOffset = 500
            }
        }
    }
    
    // Confetti overlay for celebration
    private var confettiOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<30, id: \.self) { index in
                    ConfettiPiece(
                        color: [Color.yellow, Color.orange, Color.red, Color.cyan, Color.blue].randomElement()!,
                        size: CGFloat.random(in: 4...10),
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: -20,
                        rotation: Double.random(in: 0...360),
                        delay: Double(index) * 0.03
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func miniDayCircle(_ day: DayProgress, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(
                    day.isCompleted || day.isToday
                        ? LinearGradient(
                            colors: day.isMilestone ? [.yellow, .orange] : streakGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 20, height: 20)
                .overlay {
                    Circle()
                        .strokeBorder(
                            day.isToday ? Color.white.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                }
                .scaleEffect(day.isToday ? 1.05 : 1.0)
                .shadow(
                    color: day.isCompleted || day.isToday ? streakGradient[1].opacity(0.3) : .clear,
                    radius: day.isToday ? 4 : 2,
                    y: 1
                )
            
            if day.isCompleted && animateCheckmarks[index] {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            } else if day.isMilestone && !day.isCompleted && !day.isToday {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.25))
            } else if !day.isCompleted && !day.isToday {
                Text("\(day.dayNumber)")
                    .font(.poppins(8))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.25))
            } else if day.isToday {
                Text("\(day.dayNumber)")
                    .font(.poppins(9))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
    }
    
    private func compactDayCircle(_ day: DayProgress, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(
                    day.isCompleted || day.isToday
                        ? LinearGradient(
                            colors: day.isMilestone ? [.yellow, .orange] : streakGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 26, height: 26)
                .overlay {
                    Circle()
                        .strokeBorder(
                            day.isToday ? Color.white.opacity(0.4) : Color.clear,
                            lineWidth: 1.5
                        )
                }
                .scaleEffect(day.isToday ? 1.1 : 1.0)
                .shadow(
                    color: day.isCompleted || day.isToday ? streakGradient[1].opacity(0.4) : .clear,
                    radius: day.isToday ? 6 : 3,
                    y: 2
                )
            
            if day.isCompleted && animateCheckmarks[index] {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            } else if day.isMilestone && !day.isCompleted && !day.isToday {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            } else if !day.isCompleted && !day.isToday {
                Text("\(day.dayNumber)")
                    .font(.poppins(10))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.3))
            } else if day.isToday {
                Text("\(day.dayNumber)")
                    .font(.poppins(11))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
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
    
    // 7-Day week progress tracker
    private var weekProgressTracker: some View {
        VStack(spacing: 8) {
            // "Week Progress" label
            Text("WEEKLY PROGRESS")
                .font(.poppins(10))
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))
                .tracking(1.2)
            
            // 7 day circles in a row
            HStack(spacing: 6) {
                ForEach(Array(weekProgress.enumerated()), id: \.offset) { index, day in
                    dayCircle(day, index: index)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.2))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                }
        }
    }
    
    private func dayCircle(_ day: DayProgress, index: Int) -> some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    day.isCompleted || day.isToday
                        ? LinearGradient(
                            colors: day.isMilestone ? [.yellow, .orange] : streakGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 36, height: 36)
                .overlay {
                    Circle()
                        .strokeBorder(
                            day.isToday ? Color.white.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                }
                .scaleEffect(day.isToday ? 1.1 : 1.0)
                .shadow(
                    color: day.isCompleted || day.isToday ? streakGradient[1].opacity(0.6) : .clear,
                    radius: day.isToday ? 8 : 4,
                    y: 2
                )
            
            // Content
            if day.isCompleted && animateCheckmarks[index] {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            } else if day.isMilestone && !day.isCompleted && !day.isToday {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.3))
            } else if !day.isCompleted && !day.isToday {
                Text("\(day.dayNumber)")
                    .font(.poppins(12))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.4))
            } else if day.isToday {
                Text("\(day.dayNumber)")
                    .font(.poppins(14))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
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
            
            // Check for streak cosmetic unlocks
            let _ = await loginService.checkStreakCosmetics(uid: uid)
            
            await MainActor.run {
                if reward != nil {
                    claimedToday = true
                    
                    // Trigger confetti celebration
                    showConfetti = true
                    
                    // Animate today's checkmark
                    let todayIndex = weekProgress.firstIndex(where: { $0.isToday }) ?? 0
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                        animateCheckmarks[todayIndex] = true
                    }
                    
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
                    
                    // Hide confetti
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        showConfetti = false
                    }
                    
                    // Auto-dismiss after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
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

// MARK: - Confetti Piece Animation

struct ConfettiPiece: View {
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let delay: Double
    
    @State private var yOffset: CGFloat = 0
    @State private var rotationAmount: Double = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotationAmount))
            .opacity(opacity)
            .position(x: x, y: y + yOffset)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.0)
                    .delay(delay)
                ) {
                    yOffset = 600
                    opacity = 0
                }
                
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatCount(3, autoreverses: false)
                    .delay(delay)
                ) {
                    rotationAmount = rotation + 720
                }
            }
    }
}

// MARK: - Floating Particle Animation

struct FloatingParticle: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    let duration: Double
    
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 1)
            .opacity(opacity)
            .offset(y: yOffset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    yOffset = -20
                    opacity = 0.6
                }
            }
    }
}
