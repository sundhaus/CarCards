//
//  BattleArenaView.swift
//  CarCardCollector
//
//  Battle Arena landing — mode selection, ranked/casual queue,
//  rank badge, season stats, and match history.
//  Inspired by Clash Royale's battle screen and EA Sports FC matchmaking.
//

import SwiftUI

struct BattleArenaView: View {
    var isLandscape: Bool = false
    
    @StateObject private var battleService = BattleService.shared
    @ObservedObject private var cardService = CardService.shared
    
    @State private var selectedMode: BattleMode = .topTrumps
    @State private var selectedQueue: BattleQueueType = .casual
    @State private var showMatchmaking = false
    @State private var showBattle = false
    @State private var showHistory = false
    @State private var showModeInfo = false
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.02, green: 0.02, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Rank Card
                        rankCard
                        
                        // Season Stats
                        seasonStats
                        
                        // Queue Type Toggle
                        queueToggle
                        
                        // Battle Mode Selector
                        modeSelector
                        
                        // BATTLE Button
                        battleButton
                        
                        // Recent Matches
                        recentMatches
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            
            // Matchmaking overlay
            if showMatchmaking {
                matchmakingOverlay
            }
        }
        .onAppear {
            Task {
                await battleService.syncRankFromCloud()
                await battleService.loadMatchHistory(limit: 5)
            }
        }
        .fullScreenCover(isPresented: $showBattle) {
            if let battle = battleService.currentBattle {
                BattleLiveView(battle: battle)
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Battle Arena")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button(action: { showHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - Rank Card
    
    private var rankCard: some View {
        HStack(spacing: 16) {
            // Rank icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: rankGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                Image(systemName: battleService.currentRank.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(battleService.currentRank.rawValue)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("\(battleService.rankPoints) RP")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                
                // Progress to next rank
                let nextRank = nextRankTarget
                if let next = nextRank {
                    let progress = Double(battleService.rankPoints - battleService.currentRank.minPoints)
                        / Double(next.minPoints - battleService.currentRank.minPoints)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: rankGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * max(0, min(1, progress)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: rankGradient.map { $0.opacity(0.4) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Season Stats
    
    private var seasonStats: some View {
        HStack(spacing: 0) {
            statBox(
                label: "Wins",
                value: "\(battleService.seasonWins)",
                color: .green
            )
            
            Divider()
                .frame(width: 1, height: 36)
                .background(Color.white.opacity(0.15))
            
            statBox(
                label: "Losses",
                value: "\(battleService.seasonLosses)",
                color: .red
            )
            
            Divider()
                .frame(width: 1, height: 36)
                .background(Color.white.opacity(0.15))
            
            statBox(
                label: "Win Rate",
                value: winRateText,
                color: .cyan
            )
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }
    
    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Queue Toggle
    
    private var queueToggle: some View {
        HStack(spacing: 0) {
            queueButton(type: .casual, label: "Casual", icon: "gamecontroller.fill")
            queueButton(type: .ranked, label: "Ranked", icon: "trophy.fill")
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func queueButton(type: BattleQueueType, label: String, icon: String) -> some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { selectedQueue = type } }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(selectedQueue == type ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                selectedQueue == type
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: type == .ranked ? [.orange, .red] : [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                      )
                    : AnyShapeStyle(Color.clear)
            )
        }
    }
    
    // MARK: - Mode Selector
    
    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BATTLE MODE")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
            
            ForEach(BattleMode.allCases, id: \.rawValue) { mode in
                modeCard(mode: mode)
            }
        }
    }
    
    private func modeCard(mode: BattleMode) -> some View {
        let isSelected = selectedMode == mode
        let isLocked = mode.requiredLevel > (UserService.shared.currentProfile?.level ?? 1)
        
        return Button(action: {
            if !isLocked {
                withAnimation(.spring(response: 0.3)) {
                    selectedMode = mode
                }
            }
        }) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isLocked ? "lock.fill" : mode.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isLocked ? .white.opacity(0.3) : isSelected ? .cyan : .white.opacity(0.6))
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(mode.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isLocked ? .white.opacity(0.3) : .white)
                        
                        if isLocked {
                            Text("Lv.\(mode.requiredLevel)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(mode.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Spacer()
                
                // Rounds badge
                if !isLocked {
                    Text(mode == .topTrumps ? "Quick" : "Bo\(mode.roundCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.cyan.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .disabled(isLocked)
    }
    
    // MARK: - Battle Button
    
    private var battleButton: some View {
        Button(action: { startMatchmaking() }) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22))
                
                Text("FIND BATTLE")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: selectedQueue == .ranked
                        ? [Color.orange, Color.red]
                        : [Color.blue, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: (selectedQueue == .ranked ? Color.orange : Color.blue).opacity(0.4), radius: 12, y: 4)
        }
        .disabled(cardService.myCards.filter { $0.cardType == "vehicle" }.count < selectedMode.handSize)
    }
    
    // MARK: - Recent Matches
    
    private var recentMatches: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT BATTLES")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)
                
                Spacer()
                
                if !battleService.matchHistory.isEmpty {
                    Button("See All") {
                        showHistory = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.cyan)
                }
            }
            
            if battleService.matchHistory.isEmpty {
                Text("No battles yet. Jump in!")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(battleService.matchHistory.prefix(3)) { result in
                    matchResultRow(result)
                }
            }
        }
    }
    
    private func matchResultRow(_ result: BattleResult) -> some View {
        HStack(spacing: 12) {
            // Win/Loss badge
            ZStack {
                Circle()
                    .fill(result.won ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Text(result.won ? "W" : "L")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(result.won ? .green : .red)
            }
            
            // Opponent + mode
            VStack(alignment: .leading, spacing: 2) {
                Text("vs \(result.opponentUsername)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(result.mode)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Score
            Text("\(result.myScore)-\(result.opponentScore)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            
            // Rank change
            if result.rankPointsChange != 0 {
                Text(result.rankPointsChange > 0 ? "+\(result.rankPointsChange)" : "\(result.rankPointsChange)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(result.rankPointsChange > 0 ? .green : .red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((result.rankPointsChange > 0 ? Color.green : Color.red).opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
    }
    
    // MARK: - Matchmaking Overlay
    
    private var matchmakingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated searching indicator
                ZStack {
                    Circle()
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 3)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.cyan, lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(Double.random(in: 0...360)))
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: showMatchmaking)
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.cyan)
                }
                
                Text("Finding Opponent...")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("\(selectedMode.rawValue) • \(selectedQueue == .ranked ? "Ranked" : "Casual")")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    Task { await battleService.cancelSearch() }
                    showMatchmaking = false
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startMatchmaking() {
        showMatchmaking = true
        errorMessage = nil
        
        Task {
            do {
                let _ = try await battleService.findMatch(mode: selectedMode, queueType: selectedQueue)
                showMatchmaking = false
                showBattle = true
            } catch let error as BattleError {
                errorMessage = error.localizedDescription
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showMatchmaking = false
            } catch {
                errorMessage = "Something went wrong"
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showMatchmaking = false
            }
        }
    }
    
    // MARK: - Helpers
    
    private var winRateText: String {
        let total = battleService.seasonWins + battleService.seasonLosses
        guard total > 0 else { return "—" }
        let rate = Double(battleService.seasonWins) / Double(total) * 100
        return String(format: "%.0f%%", rate)
    }
    
    private var nextRankTarget: BattleRank? {
        let all = BattleRank.allCases
        guard let currentIndex = all.firstIndex(of: battleService.currentRank),
              currentIndex + 1 < all.count else { return nil }
        return all[currentIndex + 1]
    }
    
    private var rankGradient: [Color] {
        switch battleService.currentRank.tier {
        case "Bronze":   return [Color(red: 0.7, green: 0.45, blue: 0.2), Color(red: 0.5, green: 0.3, blue: 0.1)]
        case "Silver":   return [Color.gray, Color(white: 0.6)]
        case "Gold":     return [Color.yellow, Color.orange]
        case "Platinum": return [Color.cyan, Color.teal]
        case "Diamond":  return [Color.blue, Color.purple]
        default:         return [Color.orange, Color.red]
        }
    }
}

#Preview {
    BattleArenaView()
}
