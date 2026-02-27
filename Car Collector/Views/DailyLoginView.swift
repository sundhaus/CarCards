//
//  DailyLoginView.swift
//  Car Collector
//
//  Daily login streak tracker with 7-day reward calendar.
//  Shows current streak, today's reward, and upcoming milestones.
//  Designed to match the app's glass-effect / Liquid Glass aesthetic.
//

import SwiftUI

struct DailyLoginView: View {
    @ObservedObject private var loginService = DailyLoginService.shared
    @ObservedObject private var userService = UserService.shared
    
    @State private var animateIn = false
    @State private var showRewardPulse = false
    @State private var claimedToday = false
    
    /// External dismiss (for when used as a sheet/fullScreenCover)
    var onDismiss: (() -> Void)? = nil
    
    // The 7-day window: past days + today + future days
    private var weekDays: [DaySlot] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let currentStreak = loginService.currentStreak
        
        return (0..<7).map { index in
            let date = cal.date(byAdding: .day, value: index - 3, to: today)!
            let dayNumber = cal.component(.day, from: date)
            let weekdaySymbol = cal.shortWeekdaySymbols[cal.component(.weekday, from: date) - 1].uppercased()
            let isToday = index == 3
            
            // Days in the past within current streak are "completed"
            let daysAgo = 3 - index
            let isCompleted: Bool
            if daysAgo > 0 {
                isCompleted = daysAgo <= currentStreak - (claimedToday ? 1 : 0)
            } else if isToday {
                isCompleted = claimedToday
            } else {
                isCompleted = false
            }
            
            // Streak day number for this slot
            let streakDay: Int?
            if isCompleted || isToday {
                let offset = currentStreak - daysAgo
                streakDay = offset > 0 ? offset : nil
            } else {
                streakDay = nil
            }
            
            // Is this a milestone day?
            let futureStreak = currentStreak + (index - 3) + (claimedToday ? 0 : 1)
            let isMilestone = futureStreak == 3 || futureStreak == 7 || (futureStreak > 0 && futureStreak % 7 == 0) || (futureStreak > 0 && futureStreak % 30 == 0)
            
            return DaySlot(
                dayNumber: dayNumber,
                weekday: weekdaySymbol,
                isToday: isToday,
                isCompleted: isCompleted,
                isFuture: index > 3,
                isMilestone: isMilestone && index >= 3,
                streakDay: streakDay
            )
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: DeviceScale.h(20)) {
                        // Streak flame + count
                        streakHero
                        
                        // 7-day calendar strip
                        weekCalendarStrip
                        
                        // Today's reward card
                        todayRewardCard
                        
                        // Upcoming milestones
                        milestonesSection
                        
                        // Stats row
                        statsRow
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            claimedToday = loginService.todayRewardClaimed
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
            
            Text("DAILY LOGIN")
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
    
    // MARK: - Streak Hero
    
    private var streakHero: some View {
        VStack(spacing: DeviceScale.h(8)) {
            // Flame icon with glow
            ZStack {
                // Glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                streakColor.opacity(0.3),
                                streakColor.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(showRewardPulse ? 1.2 : 1.0)
                    .opacity(animateIn ? 1 : 0)
                
                // Flame
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: streakGradient,
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .scaleEffect(animateIn ? 1.0 : 0.3)
                    .opacity(animateIn ? 1 : 0)
            }
            
            // Streak count
            Text("\(loginService.currentStreak)")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: streakGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .scaleEffect(animateIn ? 1.0 : 0.5)
                .opacity(animateIn ? 1 : 0)
            
            Text("DAY STREAK")
                .font(.poppins(14))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(2)
                .opacity(animateIn ? 1 : 0)
        }
        .padding(.top, DeviceScale.h(8))
    }
    
    // MARK: - Week Calendar Strip
    
    private var weekCalendarStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                dayCell(day, index: index)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .solidGlass(cornerRadius: 16)
    }
    
    private func dayCell(_ day: DaySlot, index: Int) -> some View {
        VStack(spacing: 6) {
            // Weekday label
            Text(day.weekday)
                .font(.poppins(10))
                .fontWeight(.medium)
                .foregroundStyle(day.isToday ? .primary : .secondary)
            
            // Day circle
            ZStack {
                if day.isCompleted {
                    // Completed — filled gradient circle with check
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: streakGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    
                } else if day.isToday {
                    // Today — pulsing ring
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: streakGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 36, height: 36)
                    
                    Text("\(day.dayNumber)")
                        .font(.poppins(14))
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                } else if day.isFuture {
                    // Future — dimmed
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 36, height: 36)
                    
                    if day.isMilestone {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow.opacity(0.5))
                    } else {
                        Text("\(day.dayNumber)")
                            .font(.poppins(14))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    
                } else {
                    // Past (not in streak) — empty
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 36, height: 36)
                    
                    Text("\(day.dayNumber)")
                        .font(.poppins(14))
                        .foregroundStyle(.secondary.opacity(0.3))
                }
            }
            .scaleEffect(animateIn ? 1.0 : 0.5)
            .opacity(animateIn ? 1.0 : 0.0)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.7)
                    .delay(Double(index) * 0.05 + 0.2),
                value: animateIn
            )
            
            // Milestone dot
            if day.isMilestone && day.isToday {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 5, height: 5)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
    }
    
    // MARK: - Today's Reward Card
    
    private var todayRewardCard: some View {
        let reward = loginService.calculateReward(for: max(loginService.currentStreak, 1))
        
        return VStack(spacing: 14) {
            HStack {
                Text("TODAY'S REWARD")
                    .font(.poppins(12))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                
                Spacer()
                
                if claimedToday {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text("Claimed")
                            .font(.poppins(12))
                            .foregroundStyle(.green)
                    }
                }
            }
            
            HStack(spacing: 20) {
                // XP reward
                rewardBubble(
                    icon: "star.fill",
                    value: "+\(reward.totalXP)",
                    label: "XP",
                    colors: [.blue, .cyan]
                )
                
                // Coins reward
                rewardBubble(
                    icon: "dollarsign.circle.fill",
                    value: "+\(reward.totalCoins)",
                    label: "Coins",
                    colors: [.yellow, .orange]
                )
                
                // Bonus indicator (if milestone)
                if reward.isMilestone, let label = reward.milestoneLabel {
                    VStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundStyle(.yellow)
                        Text(label)
                            .font(.poppins(11))
                            .fontWeight(.semibold)
                            .foregroundStyle(.yellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Claim button (for testing / manual claim)
            if !claimedToday {
                Button(action: {
                    Task {
                        if let uid = FirebaseManager.shared.currentUserId {
                            await loginService.checkIn(uid: uid)
                            withAnimation(.spring(response: 0.4)) {
                                claimedToday = true
                                showRewardPulse = true
                            }
                            // Reset pulse
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                withAnimation { showRewardPulse = false }
                            }
                        }
                    }
                }) {
                    Text("Claim Reward")
                        .font(.poppins(16))
                        .fontWeight(.semibold)
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
            }
        }
        .padding(16)
        .solidGlass(cornerRadius: 16)
    }
    
    private func rewardBubble(icon: String, value: String, label: String, colors: [Color]) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: colors.map { $0.opacity(0.2) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(value)
                .font(.poppins(18))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.poppins(11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Milestones Section
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STREAK MILESTONES")
                .font(.poppins(12))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(1.5)
            
            VStack(spacing: 8) {
                milestoneRow(days: 3, bonusXP: RewardConfig.streak3BonusXP, bonusCoins: 0, cosmetic: nil)
                milestoneRow(days: 7, bonusXP: RewardConfig.streak7BonusXP, bonusCoins: RewardConfig.streak7BonusCoins, cosmetic: "Streak Flame Border")
                milestoneRow(days: 14, bonusXP: 0, bonusCoins: 0, cosmetic: "Hot Streak Badge")
                milestoneRow(days: 30, bonusXP: RewardConfig.streak30BonusXP, bonusCoins: RewardConfig.streak30BonusCoins, cosmetic: "Inferno Effect")
            }
        }
        .padding(16)
        .solidGlass(cornerRadius: 16)
    }
    
    private func milestoneRow(days: Int, bonusXP: Int, bonusCoins: Int, cosmetic: String?) -> some View {
        let reached = loginService.currentStreak >= days
        
        return HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(reached ? Color.yellow.opacity(0.2) : Color.primary.opacity(0.05))
                    .frame(width: 36, height: 36)
                
                if reached {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.yellow)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            
            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text("\(days)-Day Streak")
                    .font(.poppins(14))
                    .fontWeight(.semibold)
                    .foregroundStyle(reached ? .primary : .secondary)
                
                HStack(spacing: 8) {
                    if bonusXP > 0 {
                        Text("+\(bonusXP) XP")
                            .font(.poppins(12))
                            .foregroundStyle(.cyan)
                    }
                    
                    if bonusCoins > 0 {
                        Text("+\(bonusCoins) Coins")
                            .font(.poppins(12))
                            .foregroundStyle(.yellow)
                    }
                    
                    if let cosmeticName = cosmetic {
                        Text(cosmeticName)
                            .font(.poppins(12))
                            .foregroundStyle(.purple)
                    }
                }
            }
            
            Spacer()
            
            // Progress
            if !reached {
                Text("\(loginService.currentStreak)/\(days)")
                    .font(.poppins(12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 16) {
            statItem(label: "Current", value: "\(loginService.currentStreak)", icon: "flame.fill")
            statItem(label: "Longest", value: "\(loginService.longestStreak)", icon: "trophy.fill")
        }
        .padding(16)
        .solidGlass(cornerRadius: 16)
    }
    
    private func statItem(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(
                    LinearGradient(
                        colors: streakGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.poppins(20))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(label)
                    .font(.poppins(11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Color Helpers
    
    /// Streak gradient shifts from cool to warm as streak grows
    private var streakGradient: [Color] {
        let streak = loginService.currentStreak
        if streak >= 30 {
            return [Color.yellow, Color.red]           // 🔥 On fire
        } else if streak >= 14 {
            return [Color.orange, Color.red]            // Hot
        } else if streak >= 7 {
            return [Color.orange, Color.yellow]         // Warming up
        } else if streak >= 3 {
            return [Color.cyan, Color.orange]           // Getting going
        } else {
            return [Color.blue, Color.cyan]             // Just starting
        }
    }
    
    private var streakColor: Color {
        let streak = loginService.currentStreak
        if streak >= 30 { return .red }
        else if streak >= 14 { return .orange }
        else if streak >= 7 { return .orange }
        else if streak >= 3 { return .cyan }
        else { return .blue }
    }
}

// MARK: - Day Slot Model

private struct DaySlot {
    let dayNumber: Int
    let weekday: String
    let isToday: Bool
    let isCompleted: Bool
    let isFuture: Bool
    let isMilestone: Bool
    let streakDay: Int?
}

// MARK: - Preview

#Preview("Fresh User") {
    DailyLoginView()
}

#Preview("7-Day Streak") {
    let service = DailyLoginService.shared
    service.currentStreak = 7
    service.longestStreak = 12
    service.todayRewardClaimed = false
    
    return DailyLoginView()
}
