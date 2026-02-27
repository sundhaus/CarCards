//
//  DailyChallengeView.swift
//  Car Collector
//
//  Full-screen daily challenge hub showing:
//  • Today's 3 daily challenges with progress bars
//  • Weekly featured challenge with category theme
//  • Streak cosmetic milestones with unlock progress
//  • Time remaining countdown
//
//  Matches the app's Liquid Glass / solid glass aesthetic.
//

import SwiftUI

struct DailyChallengeView: View {
    @ObservedObject private var challengeService = DailyChallengeService.shared
    @ObservedObject private var loginService = DailyLoginService.shared
    @ObservedObject private var userService = UserService.shared
    
    var onDismiss: (() -> Void)? = nil
    
    @State private var animateIn = false
    @State private var claimingId: String? = nil
    @State private var showClaimConfetti = false
    
    var body: some View {
        ZStack {
            // Background
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: DeviceScale.h(16)) {
                        // Time remaining banner
                        timeRemainingBanner
                        
                        // Daily challenges
                        dailyChallengesSection
                        
                        // Weekly featured challenge
                        weeklyFeaturedSection
                        
                        // Streak cosmetic milestones
                        streakCosmeticsSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            
            // Confetti overlay
            if showClaimConfetti {
                confettiOverlay
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animateIn = true
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .solidGlassCircle()
                }
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
            
            Spacer()
            
            Text("DAILY CHALLENGES")
                .font(.pTitle3)
                .fontWeight(.bold)
            
            Spacer()
            
            // Coin counter
            HStack(spacing: 4) {
                HeatCheckCoin(size: 14)
                Text("\(userService.coins)")
                    .font(.poppins(13))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .solidGlassCapsule()
        }
        .padding(.horizontal)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
    
    // MARK: - Time Remaining
    
    private var timeRemainingBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.system(size: 16))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Challenges reset daily at midnight")
                    .font(.poppins(12))
                    .foregroundStyle(.secondary)
                
                Text(timeRemainingText)
                    .font(.poppins(14))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Streak indicator
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                Text("\(loginService.currentStreak)")
                    .font(.poppins(14))
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .solidGlass(cornerRadius: 14)
        .opacity(animateIn ? 1 : 0)
    }
    
    private var timeRemainingText: String {
        let calendar = Calendar.current
        let now = Date()
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let remaining = endOfDay.timeIntervalSince(now)
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        return "\(hours)h \(minutes)m remaining"
    }
    
    // MARK: - Daily Challenges
    
    private var dailyChallengesSection: some View {
        VStack(alignment: .leading, spacing: DeviceScale.h(10)) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.orange)
                Text("TODAY'S CHALLENGES")
                    .font(.poppins(14))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                
                // Completion count
                let completed = challengeService.dailyChallenges.filter { $0.isComplete }.count
                let total = challengeService.dailyChallenges.count
                Text("\(completed)/\(total)")
                    .font(.poppins(13))
                    .foregroundStyle(completed == total ? .green : .secondary)
            }
            
            ForEach(Array(challengeService.dailyChallenges.enumerated()), id: \.element.id) { index, challenge in
                dailyChallengeCard(challenge, index: index)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                        .delay(Double(index) * 0.1),
                        value: animateIn
                    )
            }
        }
    }
    
    private func dailyChallengeCard(_ challenge: DailyChallenge, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row
            HStack(spacing: 10) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: challenge.isClaimed ? [.green.opacity(0.3)] : challenge.gradientColors.map { $0.opacity(0.3) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    if challenge.isClaimed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: challenge.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: challenge.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.poppins(14))
                        .foregroundStyle(challenge.isClaimed ? .secondary : .primary)
                    
                    Text(challenge.description)
                        .font(.poppins(11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Reward preview
                if !challenge.isClaimed {
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            HeatCheckCoin(size: 10)
                            Text("+\(challenge.rewardCoins)")
                                .font(.poppins(11))
                                .foregroundStyle(.yellow)
                        }
                        
                        if challenge.rewardXP > 0 {
                            Text("+\(challenge.rewardXP) XP")
                                .font(.poppins(10))
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(
                            challenge.isClaimed
                            ? LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: challenge.gradientColors, startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(geo.size.width * challenge.progressFraction, challenge.progress > 0 ? 8 : 0), height: 8)
                        .animation(.spring(response: 0.5), value: challenge.progress)
                }
            }
            .frame(height: 8)
            
            // Bottom row: progress text + claim button
            HStack {
                Text("\(challenge.progress)/\(challenge.target)")
                    .font(.poppins(12))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if challenge.isComplete && !challenge.isClaimed {
                    Button {
                        claimChallenge(challenge.id)
                    } label: {
                        HStack(spacing: 4) {
                            if claimingId == challenge.id {
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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: challenge.gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: challenge.gradientColors.last?.opacity(0.4) ?? .clear, radius: 6, y: 3)
                    }
                    .disabled(claimingId != nil)
                }
            }
        }
        .padding(14)
        .solidGlass(cornerRadius: 14)
    }
    
    // MARK: - Weekly Featured
    
    @ViewBuilder
    private var weeklyFeaturedSection: some View {
        if let weekly = challengeService.weeklyChallenge {
            VStack(alignment: .leading, spacing: DeviceScale.h(10)) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.purple)
                    Text("WEEKLY FEATURED")
                        .font(.poppins(14))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    
                    Text(weeklyTimeRemaining)
                        .font(.poppins(11))
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    // Title row with gradient accent
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: weekly.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(weekly.title)
                                .font(.poppins(16))
                                .foregroundStyle(.primary)
                            
                            Text(weekly.description)
                                .font(.poppins(12))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    // Reward banner
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            HeatCheckCoin(size: 12)
                            Text("+\(weekly.rewardCoins)")
                                .font(.poppins(13))
                                .foregroundStyle(.yellow)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.cyan)
                            Text("+\(weekly.rewardXP) XP")
                                .font(.poppins(13))
                                .foregroundStyle(.cyan)
                        }
                        
                        if weekly.rewardBorder != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "square.dashed")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.purple)
                                Text("Exclusive Border")
                                    .font(.poppins(13))
                                    .foregroundStyle(.purple)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 10)
                            
                            Capsule()
                                .fill(
                                    weekly.isClaimed
                                    ? LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(geo.size.width * weekly.progressFraction, weekly.progress > 0 ? 10 : 0), height: 10)
                                .animation(.spring(response: 0.5), value: weekly.progress)
                        }
                    }
                    .frame(height: 10)
                    
                    // Bottom row
                    HStack {
                        Text("\(weekly.progress)/\(weekly.target)")
                            .font(.poppins(13))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if weekly.isComplete && !weekly.isClaimed {
                            Button {
                                claimChallenge(weekly.id)
                            } label: {
                                HStack(spacing: 4) {
                                    if claimingId == weekly.id {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.7)
                                    } else {
                                        Text("Claim Rewards")
                                            .font(.poppins(14))
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                            }
                            .disabled(claimingId != nil)
                        } else if weekly.isClaimed {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Completed!")
                                    .font(.poppins(13))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .padding(16)
                .solidGlass(cornerRadius: 16)
            }
            .opacity(animateIn ? 1 : 0)
            .animation(.spring(response: 0.6).delay(0.3), value: animateIn)
        }
    }
    
    private var weeklyTimeRemaining: String {
        guard let weekly = challengeService.weeklyChallenge else { return "" }
        let remaining = weekly.expiresAt.timeIntervalSince(Date())
        let days = Int(remaining) / 86400
        if days > 0 { return "\(days)d left" }
        let hours = Int(remaining) / 3600
        return "\(hours)h left"
    }
    
    // MARK: - Streak Cosmetics
    
    private var streakCosmeticsSection: some View {
        VStack(alignment: .leading, spacing: DeviceScale.h(10)) {
            HStack {
                Image(systemName: "paintbrush.pointed.fill")
                    .foregroundStyle(.pink)
                Text("STREAK REWARDS")
                    .font(.poppins(14))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(DailyChallengeService.streakCosmetics, id: \.streakDay) { cosmetic in
                    streakCosmeticRow(cosmetic)
                }
            }
            .padding(14)
            .solidGlass(cornerRadius: 14)
        }
        .opacity(animateIn ? 1 : 0)
        .animation(.spring(response: 0.6).delay(0.5), value: animateIn)
    }
    
    private func streakCosmeticRow(_ cosmetic: StreakCosmeticReward) -> some View {
        let isUnlocked = loginService.currentStreak >= cosmetic.streakDay
        let cosmeticId = "streak_\(cosmetic.streakDay)_\(cosmetic.type.rawValue)"
        let isOwned = challengeService.unlockedCosmetics.contains(cosmeticId)
        
        return HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                        ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40, height: 40)
                
                if isOwned {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.yellow)
                } else if isUnlocked {
                    Image(systemName: cosmetic.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(cosmetic.name)
                    .font(.poppins(13))
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                
                Text("Day \(cosmetic.streakDay) • \(cosmetic.type.rawValue.capitalized)")
                    .font(.poppins(11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Progress
            if !isUnlocked {
                Text("\(loginService.currentStreak)/\(cosmetic.streakDay)")
                    .font(.poppins(12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Claim Action
    
    private func claimChallenge(_ challengeId: String) {
        guard claimingId == nil else { return }
        claimingId = challengeId
        
        Task {
            guard let uid = FirebaseManager.shared.currentUserId else {
                claimingId = nil
                return
            }
            
            let success = await challengeService.claimReward(challengeId: challengeId, uid: uid)
            
            if success {
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Brief confetti
                showClaimConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showClaimConfetti = false
                }
            }
            
            claimingId = nil
        }
    }
    
    // MARK: - Confetti Overlay
    
    private var confettiOverlay: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<20, id: \.self) { i in
                    ConfettiPiece(
                        color: [Color.yellow, .orange, .cyan, .green, .purple, .pink].randomElement()!,
                        size: CGFloat.random(in: 4...8),
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: -20,
                        rotation: Double.random(in: -180...180),
                        delay: Double(i) * 0.03
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview("With Challenges") {
    DailyChallengeView()
}
