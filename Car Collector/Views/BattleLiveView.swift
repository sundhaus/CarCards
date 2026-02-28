//
//  BattleLiveView.swift
//  CarCardCollector
//
//  Core battle gameplay UI — handles all battle modes from hand selection
//  through round resolution and final results. This is where strategy lives.
//
//  Flow:
//    1. Hand Selection (Draft/Class/Budget) — pick cards from garage
//    2. Round Play — attacker picks category, defender responds
//    3. Round Reveal — animated stat comparison
//    4. Battle Result — winner, rewards, rank change
//

import SwiftUI

// MARK: - Battle Phase

enum BattlePhase: Equatable {
    case handSelection          // Picking cards from garage
    case waitingForOpponent     // Opponent still selecting hand
    case pickCard               // Choose which card to play this round
    case pickCategory           // Attacker chooses stat category
    case waitingForDefender     // Async: waiting for opponent's card
    case roundReveal            // Animated stat comparison
    case battleComplete         // Show final results
}

// MARK: - BattleLiveView

struct BattleLiveView: View {
    let battle: BattleMatch
    
    @StateObject private var battleService = BattleService.shared
    @ObservedObject private var cardService = CardService.shared
    
    // Phase tracking
    @State private var phase: BattlePhase = .handSelection
    
    // Hand selection
    @State private var selectedHandIds: Set<String> = []
    @State private var handSubmitted = false
    
    // Round play
    @State private var selectedCardId: String?
    @State private var selectedCategory: BattleCategory?
    @State private var myPlayedCardId: String?
    @State private var opponentPlayedCardId: String?
    
    // Round reveal animation
    @State private var showReveal = false
    @State private var revealMyValue: Int = 0
    @State private var revealOpponentValue: Int = 0
    @State private var revealCategory: BattleCategory = .power
    @State private var roundWinnerId: String?
    @State private var revealScale: CGFloat = 0.5
    @State private var showVsText = false
    @State private var showStatBars = false
    @State private var showRoundResult = false
    
    // Synergies
    @State private var activeSynergies: SynergyResult = .none
    @State private var showSynergyBanner = false
    
    // Battle result
    @State private var showResults = false
    @State private var resultCoins = 0
    @State private var resultXP = 0
    @State private var resultRankChange = 0
    
    // Used cards tracking (Draft mode — can't reuse)
    @State private var usedCardIds: Set<String> = []
    
    @Environment(\.dismiss) private var dismiss
    
    // Computed
    private var myUserId: String { FirebaseManager.shared.currentUserId ?? "" }
    private var isPlayer1: Bool { battle.player1.userId == myUserId }
    private var myPlayer: BattlePlayer? { battle.player(for: myUserId) }
    private var opponent: BattlePlayer? { battle.opponent(of: myUserId) }
    private var isMyTurn: Bool { battleService.currentBattle?.currentAttackerId == myUserId }
    private var currentMatch: BattleMatch? { battleService.currentBattle }
    
    private var vehicleCards: [CloudCard] {
        cardService.myCards.filter { $0.cardType == "vehicle" }
    }
    
    private var handCards: [CloudCard] {
        vehicleCards.filter { selectedHandIds.contains($0.id) }
    }
    
    private var availableCardsForRound: [CloudCard] {
        handCards.filter { !usedCardIds.contains($0.id) }
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            VStack(spacing: 0) {
                // Top bar with scores
                battleTopBar
                
                // Main content based on phase
                switch phase {
                case .handSelection:
                    handSelectionView
                case .waitingForOpponent:
                    waitingView(message: "Waiting for opponent to pick cards...")
                case .pickCard:
                    cardPickView
                case .pickCategory:
                    categoryPickView
                case .waitingForDefender:
                    waitingView(message: "Waiting for opponent's move...")
                case .roundReveal:
                    roundRevealView
                case .battleComplete:
                    battleCompleteView
                }
            }
            
            // Synergy banner overlay
            if showSynergyBanner {
                synergyBannerOverlay
            }
        }
        .onAppear {
            setupPhase()
            battleService.listenToBattle(battle.id)
        }
        .onChange(of: battleService.currentBattle?.status) { _, newStatus in
            handleStatusChange(newStatus)
        }
        .onChange(of: battleService.currentBattle?.currentRound) { _, _ in
            handleRoundChange()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.04, blue: 0.12),
                Color(red: 0.02, green: 0.02, blue: 0.06)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Top Bar
    
    private var battleTopBar: some View {
        VStack(spacing: 8) {
            HStack {
                // My info
                VStack(alignment: .leading, spacing: 2) {
                    Text(myPlayer?.username ?? "You")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Lv.\(myPlayer?.level ?? 1)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Score
                HStack(spacing: 8) {
                    Text("\(currentMatch?.player(for: myUserId)?.score ?? 0)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.cyan)
                    
                    Text("—")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text("\(currentMatch?.opponent(of: myUserId)?.score ?? 0)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                // Opponent info
                VStack(alignment: .trailing, spacing: 2) {
                    Text(opponent?.username ?? "Opponent")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Lv.\(opponent?.level ?? 1)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            // Round indicator
            if let match = currentMatch, match.mode != .topTrumps {
                roundIndicator(current: match.currentRound, total: match.mode.roundCount)
            }
            
            // Mode + Queue badge
            HStack(spacing: 8) {
                Text(battle.mode.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                
                if battle.queueType == .ranked {
                    Text("RANKED")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Turn indicator
                if phase == .pickCard || phase == .pickCategory {
                    Text(isMyTurn ? "YOUR TURN" : "OPPONENT'S TURN")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                        .foregroundStyle(isMyTurn ? .green : .yellow)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
    }
    
    private func roundIndicator(current: Int, total: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { round in
                let roundResult = currentMatch?.rounds.first(where: { $0.id == round })
                
                Circle()
                    .fill(roundColor(round: round, current: current, result: roundResult))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(round == current ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
            }
        }
    }
    
    private func roundColor(round: Int, current: Int, result: BattleRound?) -> Color {
        if let result = result {
            if result.winnerId == myUserId { return .green }
            if result.winnerId != nil { return .red }
            return .yellow // Tie
        }
        if round == current { return .cyan.opacity(0.6) }
        return Color.white.opacity(0.15)
    }
    
    // MARK: - Hand Selection
    
    private var handSelectionView: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("SELECT YOUR HAND")
                    .font(.system(size: 20, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white)
                
                Text("Pick \(battle.mode.handSize) cards for battle")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                
                Text("\(selectedHandIds.count) / \(battle.mode.handSize)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(selectedHandIds.count == battle.mode.handSize ? .green : .cyan)
            }
            .padding(.top, 12)
            
            // Card grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    ForEach(vehicleCards, id: \.id) { card in
                        handSelectionCard(card)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            
            Spacer()
            
            // Submit button
            Button(action: submitHand) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 18))
                    Text("LOCK IN")
                        .font(.system(size: 18, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: selectedHandIds.count == battle.mode.handSize
                            ? [.blue, .purple] : [.gray, .gray.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .disabled(selectedHandIds.count != battle.mode.handSize)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func handSelectionCard(_ card: CloudCard) -> some View {
        let isSelected = selectedHandIds.contains(card.id)
        let stats = battleService.battleStats(for: card)
        let rarity = CardRarity(rawValue: card.rarity ?? "Common") ?? .common
        
        return Button(action: {
            withAnimation(.spring(response: 0.25)) {
                if isSelected {
                    selectedHandIds.remove(card.id)
                } else if selectedHandIds.count < battle.mode.handSize {
                    selectedHandIds.insert(card.id)
                }
            }
        }) {
            VStack(spacing: 4) {
                // Card image placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: rarity.cardBackGradient,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 80)
                    
                    // Overlay card info
                    VStack(spacing: 2) {
                        Text(card.make)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(card.model)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(card.year)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    // Selection checkmark
                    if isSelected {
                        ZStack {
                            Color.cyan.opacity(0.3)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.cyan)
                        }
                        .cornerRadius(8)
                    }
                }
                
                // Overall rating
                Text("\(stats.overall)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? .cyan : .white.opacity(0.6))
                
                // Best stat icon
                HStack(spacing: 2) {
                    Image(systemName: stats.bestCategory.icon)
                        .font(.system(size: 8))
                    Text(stats.bestCategory.shortLabel)
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.4))
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.cyan.opacity(0.12) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
    
    // MARK: - Card Pick View (choose card for this round)
    
    private var cardPickView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(isMyTurn ? "CHOOSE YOUR CARD" : "OPPONENT IS PICKING...")
                    .font(.system(size: 18, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                
                if isMyTurn {
                    Text("Select a card to play this round")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.top, 16)
            
            if isMyTurn {
                // Show available cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(availableCardsForRound, id: \.id) { card in
                            battleCardTile(card, isSelected: selectedCardId == card.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.2)) {
                                        selectedCardId = card.id
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 220)
                
                // Selected card stats preview
                if let cardId = selectedCardId,
                   let card = availableCardsForRound.first(where: { $0.id == cardId }) {
                    selectedCardStatsPreview(card)
                }
                
                Spacer()
                
                // Confirm button — for Top Trumps goes straight to category,
                // for Draft goes to category pick if attacker
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        myPlayedCardId = selectedCardId
                        phase = .pickCategory
                    }
                }) {
                    Text("PLAY THIS CARD")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            selectedCardId != nil
                                ? AnyShapeStyle(LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color.gray.opacity(0.3))
                        )
                        .cornerRadius(12)
                }
                .disabled(selectedCardId == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            } else {
                // Waiting for opponent to pick
                waitingAnimation
                Spacer()
            }
        }
    }
    
    // MARK: - Category Pick View (attacker chooses stat)
    
    private var categoryPickView: some View {
        VStack(spacing: 20) {
            // My played card summary
            if let cardId = myPlayedCardId,
               let card = vehicleCards.first(where: { $0.id == cardId }) {
                let stats = battleService.battleStats(for: card)
                
                VStack(spacing: 4) {
                    Text("\(card.make) \(card.model)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Overall: \(stats.overall)")
                        .font(.system(size: 13))
                        .foregroundStyle(.cyan)
                }
                .padding(.top, 12)
            }
            
            Text("CHOOSE YOUR STAT")
                .font(.system(size: 22, weight: .black))
                .tracking(2)
                .foregroundStyle(.white)
            
            Text("Pick the category where your card is strongest")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            
            // Category buttons with stat values
            if let cardId = myPlayedCardId,
               let card = vehicleCards.first(where: { $0.id == cardId }) {
                let stats = battleService.battleStats(for: card)
                
                VStack(spacing: 10) {
                    ForEach(BattleCategory.allCases) { category in
                        categoryButton(
                            category: category,
                            value: stats.value(for: category),
                            isBest: category == stats.bestCategory,
                            isSelected: selectedCategory == category
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Confirm category
            Button(action: confirmCategoryAndPlay) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18))
                    Text("ATTACK!")
                        .font(.system(size: 18, weight: .black))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedCategory != nil
                        ? AnyShapeStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.gray.opacity(0.3))
                )
                .cornerRadius(14)
                .shadow(color: selectedCategory != nil ? .orange.opacity(0.3) : .clear, radius: 10, y: 4)
            }
            .disabled(selectedCategory == nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func categoryButton(category: BattleCategory, value: Int, isBest: Bool, isSelected: Bool) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.2)) {
                selectedCategory = category
            }
        }) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? categoryColor(category).opacity(0.3) : Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? categoryColor(category) : .white.opacity(0.5))
                }
                
                // Category name
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    if isBest {
                        Text("STRONGEST")
                            .font(.system(size: 9, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.green)
                    }
                }
                
                Spacer()
                
                // Stat bar
                statBar(value: value, category: category, width: 100)
                
                // Value
                Text("\(value)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? categoryColor(category) : .white)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? categoryColor(category).opacity(0.1) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? categoryColor(category).opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
    
    // MARK: - Round Reveal View
    
    private var roundRevealView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Category being compared
            VStack(spacing: 6) {
                Image(systemName: revealCategory.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(categoryColor(revealCategory))
                
                Text(revealCategory.rawValue.uppercased())
                    .font(.system(size: 14, weight: .black))
                    .tracking(2)
                    .foregroundStyle(categoryColor(revealCategory))
            }
            .scaleEffect(revealScale)
            
            // VS text
            if showVsText {
                Text("VS")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Stat comparison
            if showStatBars {
                HStack(spacing: 30) {
                    // My stat
                    VStack(spacing: 8) {
                        Text("\(revealMyValue)")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(revealMyValue >= revealOpponentValue ? .cyan : .white.opacity(0.4))
                        
                        Text(myPlayer?.username ?? "You")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 60)
                    
                    // Opponent stat
                    VStack(spacing: 8) {
                        Text("\(revealOpponentValue)")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(revealOpponentValue >= revealMyValue ? .red : .white.opacity(0.4))
                        
                        Text(opponent?.username ?? "Opponent")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            
            // Round result
            if showRoundResult {
                VStack(spacing: 8) {
                    if roundWinnerId == myUserId {
                        Text("YOU WIN THIS ROUND!")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.green)
                    } else if roundWinnerId != nil {
                        Text("OPPONENT WINS")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.red)
                    } else {
                        Text("TIE!")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.yellow)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // Continue button (after reveal)
            if showRoundResult {
                Button(action: advanceFromReveal) {
                    Text(isLastRound ? "SEE RESULTS" : "NEXT ROUND")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            runRevealAnimation()
        }
    }
    
    // MARK: - Battle Complete View
    
    private var battleCompleteView: some View {
        let won = currentMatch?.winnerId == myUserId
        let isTie = currentMatch?.winnerId == nil && currentMatch?.status == .finished
        
        return VStack(spacing: 24) {
            Spacer()
            
            // Victory / Defeat banner
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            won ? Color.green.opacity(0.15)
                            : isTie ? Color.yellow.opacity(0.15)
                            : Color.red.opacity(0.15)
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: won ? "trophy.fill" : isTie ? "equal.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(won ? .yellow : isTie ? .yellow : .red)
                }
                
                Text(won ? "VICTORY!" : isTie ? "DRAW" : "DEFEAT")
                    .font(.system(size: 32, weight: .black))
                    .tracking(3)
                    .foregroundStyle(won ? .green : isTie ? .yellow : .red)
                
                // Final score
                let myScore = currentMatch?.player(for: myUserId)?.score ?? 0
                let oppScore = currentMatch?.opponent(of: myUserId)?.score ?? 0
                Text("\(myScore) — \(oppScore)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            // Rewards
            VStack(spacing: 12) {
                Text("REWARDS")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.4))
                
                HStack(spacing: 24) {
                    rewardItem(icon: "dollarsign.circle.fill", value: "+\(resultCoins)", label: "Coins", color: .yellow)
                    rewardItem(icon: "star.fill", value: "+\(resultXP)", label: "XP", color: .cyan)
                    
                    if battle.queueType == .ranked {
                        rewardItem(
                            icon: "arrow.up.circle.fill",
                            value: resultRankChange >= 0 ? "+\(resultRankChange)" : "\(resultRankChange)",
                            label: "RP",
                            color: resultRankChange >= 0 ? .green : .red
                        )
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
            )
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 10) {
                Button(action: { dismiss() }) {
                    Text("BACK TO ARENA")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                
                Button(action: { dismiss() }) {
                    Text("Share Result")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Waiting View
    
    private func waitingView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            waitingAnimation
            Text(message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            
            // Forfeit option
            Button(action: {
                Task {
                    try? await battleService.forfeit(battleId: battle.id)
                    dismiss()
                }
            }) {
                Text("Leave Battle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .padding(.top, 20)
            Spacer()
        }
    }
    
    private var waitingAnimation: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.cyan.opacity(0.2), lineWidth: 2)
                    .frame(width: CGFloat(60 + i * 30), height: CGFloat(60 + i * 30))
                    .scaleEffect(showReveal ? 1.2 : 0.8)
                    .opacity(showReveal ? 0.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.5)
                            .repeatForever()
                            .delay(Double(i) * 0.3),
                        value: showReveal
                    )
            }
            
            Image(systemName: "hourglass")
                .font(.system(size: 28))
                .foregroundStyle(.cyan)
        }
        .onAppear { showReveal = true }
        .onDisappear { showReveal = false }
    }
    
    // MARK: - Shared Components
    
    private func battleCardTile(_ card: CloudCard, isSelected: Bool) -> some View {
        let stats = battleService.battleStats(for: card)
        let rarity = CardRarity(rawValue: card.rarity ?? "Common") ?? .common
        
        return VStack(spacing: 6) {
            // Card image area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: rarity.cardBackGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                
                VStack(spacing: 4) {
                    Text(card.make)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(card.model)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(card.year)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    // Rarity badge
                    Text(rarity.rawValue)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(rarity.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rarity.color.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            
            // Stats overview
            HStack(spacing: 4) {
                ForEach(BattleCategory.allCases) { cat in
                    VStack(spacing: 1) {
                        Text(cat.shortLabel)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("\(stats.value(for: cat))")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(cat == stats.bestCategory ? categoryColor(cat) : .white.opacity(0.6))
                    }
                }
            }
            
            // Overall
            Text("OVR \(stats.overall)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? .cyan : .white)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.cyan.opacity(0.1) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.clear, lineWidth: 2.5)
                )
        )
    }
    
    private func selectedCardStatsPreview(_ card: CloudCard) -> some View {
        let stats = battleService.battleStats(for: card)
        
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text("STAT BREAKDOWN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            HStack(spacing: 12) {
                ForEach(BattleCategory.allCases) { cat in
                    VStack(spacing: 4) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(categoryColor(cat))
                        
                        Text("\(stats.value(for: cat))")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(cat == stats.bestCategory ? categoryColor(cat) : .white)
                        
                        Text(cat.shortLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .padding(.horizontal, 20)
    }
    
    private func statBar(value: Int, category: BattleCategory, width: CGFloat) -> some View {
        GeometryReader { _ in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: width, height: 6)
                
                Capsule()
                    .fill(categoryColor(category))
                    .frame(width: width * CGFloat(value) / 99.0, height: 6)
            }
        }
        .frame(width: width, height: 6)
    }
    
    private func rewardItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Synergy Banner
    
    private var synergyBannerOverlay: some View {
        VStack {
            VStack(spacing: 8) {
                Text("SYNERGIES ACTIVE!")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.yellow)
                
                ForEach(Array(activeSynergies.activeSynergies.enumerated()), id: \.offset) { _, synergy in
                    HStack(spacing: 8) {
                        Image(systemName: synergy.0.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.yellow)
                        
                        Text("\(synergy.0.rawValue): \(synergy.1)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.yellow.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 120)
            .transition(.move(edge: .top).combined(with: .opacity))
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func setupPhase() {
        guard let match = battleService.currentBattle ?? Optional(battle) else { return }
        
        // Pre-load specs for all my vehicle cards
        Task {
            await battleService.loadSpecs(for: vehicleCards)
        }
        
        // Determine starting phase based on battle state
        switch match.status {
        case .handSelection:
            phase = .handSelection
        case .inProgress, .waitingForMove:
            if match.mode == .topTrumps {
                phase = .pickCard
            } else {
                let me = match.player(for: myUserId)
                if me?.isReady == true {
                    phase = isMyTurn ? .pickCard : .waitingForDefender
                } else {
                    phase = .handSelection
                }
            }
        case .finished:
            phase = .battleComplete
            calculateRewards()
        default:
            phase = .handSelection
        }
    }
    
    private func submitHand() {
        guard selectedHandIds.count == battle.mode.handSize else { return }
        handSubmitted = true
        
        // Detect synergies
        let cards = vehicleCards.filter { selectedHandIds.contains($0.id) }
        activeSynergies = SynergyDetector.detect(cards: cards, specsMap: battleService.specsCache)
        
        if !activeSynergies.activeSynergies.isEmpty {
            withAnimation(.spring(response: 0.4)) {
                showSynergyBanner = true
            }
            
            // Auto-dismiss after 2.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showSynergyBanner = false }
            }
        }
        
        Task {
            do {
                try await battleService.submitHand(cardIds: Array(selectedHandIds), for: battle.id)
                
                // Check if both ready
                if let match = battleService.currentBattle,
                   match.player1.isReady && match.player2?.isReady == true {
                    withAnimation {
                        phase = isMyTurn ? .pickCard : .waitingForDefender
                    }
                } else {
                    withAnimation {
                        phase = .waitingForOpponent
                    }
                }
            } catch {
                print("❌ Failed to submit hand: \(error)")
            }
        }
    }
    
    private func confirmCategoryAndPlay() {
        guard let cardId = myPlayedCardId,
              let category = selectedCategory,
              let card = vehicleCards.first(where: { $0.id == cardId }) else { return }
        
        let specs = battleService.specsCache[card.id] ?? .empty
        let rarity = CardRarity(rawValue: card.rarity ?? "Common") ?? .common
        
        // Mark card as used (for Draft mode)
        usedCardIds.insert(cardId)
        
        Task {
            do {
                if battle.mode == .topTrumps {
                    // Top Trumps: resolve immediately if we have opponent's card
                    // For now, submit our turn and wait
                    try await battleService.playTurn(
                        battleId: battle.id,
                        cardId: cardId,
                        category: category,
                        cardSpecs: specs,
                        cardRarity: rarity
                    )
                    withAnimation { phase = .waitingForDefender }
                } else {
                    // Draft/other modes: submit turn
                    try await battleService.playTurn(
                        battleId: battle.id,
                        cardId: cardId,
                        category: category,
                        cardSpecs: specs,
                        cardRarity: rarity
                    )
                    withAnimation { phase = .waitingForDefender }
                }
            } catch {
                print("❌ Failed to play turn: \(error)")
            }
        }
    }
    
    private func runRevealAnimation() {
        revealScale = 0.5
        showVsText = false
        showStatBars = false
        showRoundResult = false
        
        // Step 1: Category icon zooms in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            revealScale = 1.0
        }
        
        // Step 2: VS text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3)) {
                showVsText = true
            }
        }
        
        // Step 3: Stat values
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.4)) {
                showStatBars = true
            }
        }
        
        // Step 4: Winner
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.4)) {
                showRoundResult = true
            }
            // Haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(roundWinnerId == myUserId ? .success : .error)
        }
    }
    
    private func advanceFromReveal() {
        guard let match = currentMatch else { return }
        
        if match.status == .finished {
            calculateRewards()
            withAnimation(.spring(response: 0.4)) {
                phase = .battleComplete
            }
        } else {
            // Reset for next round
            selectedCardId = nil
            selectedCategory = nil
            myPlayedCardId = nil
            opponentPlayedCardId = nil
            showReveal = false
            
            withAnimation(.spring(response: 0.3)) {
                phase = isMyTurn ? .pickCard : .waitingForDefender
            }
        }
    }
    
    private func handleStatusChange(_ status: BattleStatus?) {
        guard let status = status else { return }
        
        switch status {
        case .inProgress:
            if phase == .waitingForOpponent {
                withAnimation {
                    phase = isMyTurn ? .pickCard : .waitingForDefender
                }
            }
        case .finished:
            calculateRewards()
            withAnimation(.spring(response: 0.4)) {
                phase = .battleComplete
            }
        default:
            break
        }
    }
    
    private func handleRoundChange() {
        guard let match = currentMatch else { return }
        
        // A new round was recorded — trigger reveal
        if let lastRound = match.rounds.last,
           lastRound.completedAt != nil,
           phase == .waitingForDefender || phase == .pickCard {
            
            // Set up reveal data
            let isP1 = isPlayer1
            revealMyValue = isP1 ? lastRound.player1StatValue : lastRound.player2StatValue
            revealOpponentValue = isP1 ? lastRound.player2StatValue : lastRound.player1StatValue
            revealCategory = BattleCategory(rawValue: lastRound.categoryChosen) ?? .power
            roundWinnerId = lastRound.winnerId
            
            withAnimation(.spring(response: 0.3)) {
                phase = .roundReveal
            }
        }
    }
    
    private func calculateRewards() {
        guard let match = currentMatch else { return }
        let won = match.winnerId == myUserId
        let rewards = BattleRewards.calculate(
            won: won,
            mode: match.mode,
            queueType: match.queueType,
            currentRank: battleService.currentRank
        )
        resultCoins = rewards.coins
        resultXP = rewards.xp
        resultRankChange = rewards.rankChange
    }
    
    private var isLastRound: Bool {
        guard let match = currentMatch else { return true }
        return match.currentRound >= match.mode.roundCount
    }
    
    // MARK: - Color Helpers
    
    private func categoryColor(_ category: BattleCategory) -> Color {
        switch category {
        case .speed:      return .cyan
        case .power:      return .orange
        case .handling:   return .green
        case .efficiency: return .mint
        case .rarity:     return .yellow
        }
    }
}

#Preview {
    BattleLiveView(
        battle: BattleMatch(
            id: "preview",
            mode: .draftBattle,
            queueType: .ranked,
            player1: BattlePlayer(userId: "me", username: "Player1", level: 12, rankPoints: 500)
        )
    )
}
