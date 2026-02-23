//
//  HeadToHeadView.swift
//  CarCardCollector
//
//  Head-to-Head drag race page — aerial drag strip with card matchups
//  Users tap cards to vote ("add heat"), cars race to the finish line
//

import SwiftUI

struct HeadToHeadView: View {
    var isLandscape: Bool = false
    
    @StateObject private var h2hService = HeadToHeadService.shared
    @ObservedObject private var cardService = CardService.shared
    
    // UI State
    @State private var showChallenge = false
    @State private var showPendingChallenges = false
    @State private var voteAnimation: VoteSide? = nil
    @State private var showWinnerCelebration = false
    @State private var winnerSide: VoteSide? = nil
    @State private var isVoting = false
    @State private var showNoRacesMessage = false
    @State private var raceTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeRemainingText = "--:--"
    
    @Environment(\.dismiss) private var dismiss
    
    enum VoteSide {
        case left, right
    }
    
    var body: some View {
        ZStack {
            dragStripBackground
            
            VStack(spacing: 0) {
                topBar
                
                Spacer()
                
                finishLine
                
                raceTrack
                
                cardMatchup
                    .padding(.bottom, 20)
            }
            
            if showWinnerCelebration, let side = winnerSide {
                winnerOverlay(side: side)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            h2hService.startListening()
            Task { await h2hService.checkExpiredRaces() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if h2hService.currentFeedRace == nil {
                    showNoRacesMessage = true
                }
            }
        }
        .onDisappear {
            raceTimer.upstream.connect().cancel()
        }
        .onReceive(raceTimer) { _ in
            updateTimer()
        }
        .sheet(isPresented: $showChallenge) {
            ChallengeView()
        }
        .sheet(isPresented: $showPendingChallenges) {
            PendingChallengesView()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            if h2hService.myStreak.currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(h2hService.myStreak.currentStreak)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    if h2hService.myStreak.coinMultiplier > 1.0 {
                        Text("\(Int(h2hService.myStreak.coinMultiplier))x")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
            
            if !h2hService.myPendingChallenges.isEmpty {
                Button(action: { showPendingChallenges = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                        
                        Text("\(h2hService.myPendingChallenges.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
            }
            
            Button(action: { showChallenge = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                    Text("CHALLENGE")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Drag Strip Background
    
    private var dragStripBackground: some View {
        GeometryReader { geo in
            Image("dragStripTrack")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
    
    // MARK: - Finish Line
    
    private var finishLine: some View {
        // Timer + vote count overlay (finish line is in the background art)
        Group {
            if let race = h2hService.currentFeedRace {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(timeRemainingText)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    
                    Text("•")
                    
                    Text("\(race.totalVotes)/\(race.voteThreshold)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Race Track (Car Progress)
    
    private var raceTrack: some View {
        GeometryReader { geo in
            let trackHeight = geo.size.height
            let centerX = geo.size.width / 2
            let laneOffset: CGFloat = geo.size.width * 0.15
            
            if let race = h2hService.currentFeedRace {
                // Left car (challenger) — starts at bottom, moves up
                let leftY = trackHeight * (1.0 - race.challengerProgress * 0.85)
                carIndicator(
                    votes: race.challengerVotes,
                    side: .left
                )
                .position(x: centerX - laneOffset, y: leftY)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: race.challengerVotes)
                
                // Right car (defender) — starts at bottom, moves up
                let rightY = trackHeight * (1.0 - race.defenderProgress * 0.85)
                carIndicator(
                    votes: race.defenderVotes,
                    side: .right
                )
                .position(x: centerX + laneOffset, y: rightY)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: race.defenderVotes)
            }
        }
        .frame(height: 200)
    }
    
    private func carIndicator(votes: Int, side: VoteSide) -> some View {
        VStack(spacing: 2) {
            Text("🔥")
                .font(.system(size: 28))
                .scaleEffect(voteAnimation == side ? 1.3 : 1.0)
            
            // Vote count
            Text("\(votes)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.6))
                .cornerRadius(4)
        }
    }
    
    // MARK: - Card Matchup (Bottom)
    
    private var cardMatchup: some View {
        Group {
            if let race = h2hService.currentFeedRace {
                VStack(spacing: 8) {
                    // VS label
                    HStack {
                        Text(race.challengerUsername)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text("VS")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.yellow)
                        
                        Spacer()
                        
                        Text(race.defenderUsername)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    
                    // Two cards side by side — tap to vote
                    HStack(spacing: 16) {
                        raceCardView(
                            imageURL: race.challengerCardImageURL,
                            make: race.challengerCardMake,
                            model: race.challengerCardModel,
                            year: race.challengerCardYear,
                            votes: race.challengerVotes,
                            side: .left,
                            cardId: race.challengerCardId
                        )
                        
                        raceCardView(
                            imageURL: race.defenderCardImageURL,
                            make: race.defenderCardMake,
                            model: race.defenderCardModel,
                            year: race.defenderCardYear,
                            votes: race.defenderVotes,
                            side: .right,
                            cardId: race.defenderCardId
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    Text("TAP YOUR PICK TO ADD HEAT 🔥")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 4)
                }
            } else if showNoRacesMessage {
                VStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No active races")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Tap Challenge to enter the queue")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.vertical, 40)
            } else {
                // Loading
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Finding a race...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 30)
            }
        }
    }
    
    // MARK: - Individual Race Card
    
    private func raceCardView(
        imageURL: String,
        make: String,
        model: String,
        year: String,
        votes: Int,
        side: VoteSide,
        cardId: String
    ) -> some View {
        Button(action: {
            guard !isVoting else { return }
            voteForCard(cardId: cardId, side: side)
        }) {
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "car.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.3))
                        )
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView().tint(.white))
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        voteAnimation == side ? Color.orange : Color.white.opacity(0.2),
                        lineWidth: voteAnimation == side ? 3 : 1
                    )
            )
            .scaleEffect(voteAnimation == side ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: voteAnimation)
        }
        .buttonStyle(.plain)
        .disabled(isVoting)
    }
    
    // MARK: - Vote Action
    
    private func voteForCard(cardId: String, side: VoteSide) {
        guard let race = h2hService.currentFeedRace else { return }
        isVoting = true
        
        // Animate the vote
        withAnimation(.spring(response: 0.3)) {
            voteAnimation = side
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            do {
                let updatedRace = try await h2hService.castVote(
                    raceId: race.id,
                    votedForCardId: cardId
                )
                
                // Check if race just finished
                if updatedRace.status == .finished || updatedRace.winnerId != nil {
                    // Show winner celebration
                    let winSide: VoteSide = (updatedRace.winnerId == updatedRace.challengerId) ? .left : .right
                    withAnimation {
                        winnerSide = winSide
                        showWinnerCelebration = true
                    }
                    
                    // Auto-dismiss and load next
                    try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
                    withAnimation {
                        showWinnerCelebration = false
                        winnerSide = nil
                    }
                }
                
                // Brief delay then load next race
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                withAnimation {
                    voteAnimation = nil
                }
                h2hService.loadNextFeedRace()
                isVoting = false
                
            } catch {
                print("❌ Vote failed: \(error.localizedDescription)")
                withAnimation { voteAnimation = nil }
                isVoting = false
            }
        }
    }
    
    // MARK: - Winner Overlay
    
    private func winnerOverlay(side: VoteSide) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                
                Text("WINNER!")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)
                
                if let race = h2hService.currentFeedRace {
                    let winnerName = side == .left
                        ? "\(race.challengerCardMake) \(race.challengerCardModel)"
                        : "\(race.defenderCardMake) \(race.defenderCardModel)"
                    Text(winnerName)
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                }
            }
            .scaleEffect(showWinnerCelebration ? 1.0 : 0.5)
            .opacity(showWinnerCelebration ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showWinnerCelebration)
        }
    }
    
    // MARK: - No Races Overlay
    
    // MARK: - Timer Update
    
    private func updateTimer() {
        guard let race = h2hService.currentFeedRace else {
            timeRemainingText = "--:--"
            return
        }
        timeRemainingText = race.timeRemainingString
    }
}



// MARK: - Challenge View (Pick Card → Pick Limit → Auto-Match or Queue)

struct ChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cardService = CardService.shared
    @ObservedObject private var h2hService = HeadToHeadService.shared
    
    @State private var step: ChallengeStep = .pickCard
    @State private var selectedCard: CloudCard?
    @State private var selectedThreshold: Int = 50
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cooldownMessage: String?
    @State private var matchResult: MatchResult?
    
    enum ChallengeStep {
        case pickCard
        case pickLimit
        case result
    }
    
    enum MatchResult {
        case matched(Race)   // Found an opponent, race started
        case queued          // No match, posted to queue
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch step {
                case .pickCard:
                    pickCardView
                case .pickLimit:
                    pickLimitView
                case .result:
                    resultView
                }
            }
            .navigationTitle("Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: Step 1 - Pick a Card
    
    private var pickCardView: some View {
        VStack(spacing: 16) {
            Text("Pick a Card")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.top)
            
            if cardService.myCards.filter({ $0.cardType == "vehicle" }).isEmpty {
                Spacer()
                Text("No vehicle cards available")
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(cardService.myCards.filter { $0.cardType == "vehicle" }) { card in
                            Button(action: {
                                Task {
                                    cooldownMessage = nil
                                    let ok = try await HeadToHeadService.shared.checkCardCooldown(cardId: card.id)
                                    if ok {
                                        selectedCard = card
                                        step = .pickLimit
                                    } else {
                                        let expiry = try await HeadToHeadService.shared.getCooldownExpiry(cardId: card.id)
                                        if let expiry = expiry {
                                            let remaining = expiry.timeIntervalSince(Date())
                                            let hours = Int(remaining) / 3600
                                            let mins = (Int(remaining) % 3600) / 60
                                            cooldownMessage = "\(card.make) \(card.model): cooldown \(hours)h \(mins)m"
                                        }
                                    }
                                }
                            }) {
                                cardCell(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            
            if let msg = cooldownMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: Step 2 - Pick Vote Limit + Challenge
    
    private var pickLimitView: some View {
        VStack(spacing: 20) {
            // Selected card preview
            if let card = selectedCard {
                VStack(spacing: 6) {
                    AsyncImage(url: URL(string: card.flatImageURL ?? card.imageURL)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 140, height: 90)
                    .cornerRadius(10)
                    
                    Text("\(card.make) \(card.model)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                .padding(.top, 20)
            }
            
            Text("Vote Limit")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                ForEach([25, 50, 100], id: \.self) { threshold in
                    Button(action: { selectedThreshold = threshold }) {
                        HStack {
                            Text("\(threshold)")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("votes")
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text(thresholdLabel(threshold))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            Image(systemName: selectedThreshold == threshold ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedThreshold == threshold ? .orange : .white.opacity(0.3))
                        }
                        .padding()
                        .background(selectedThreshold == threshold ? Color.orange.opacity(0.2) : Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Challenge button
            Button(action: submitChallenge) {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "flag.checkered")
                    }
                    Text("CHALLENGE")
                        .font(.headline.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            .disabled(isLoading)
        }
    }
    
    // MARK: Step 3 - Result (Matched or Queued)
    
    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            switch matchResult {
            case .matched(let race):
                Image(systemName: "car.2.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                
                Text("MATCHED!")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text("Racing against \(race.defenderUsername.isEmpty ? race.challengerUsername : race.defenderUsername)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                Text("Your race is live — go vote!")
                    .font(.caption)
                    .foregroundStyle(.green)
                
            case .queued:
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
                
                Text("IN THE QUEUE")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text("Your card is waiting for an opponent with the same vote limit.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("You'll be matched automatically!")
                    .font(.caption)
                    .foregroundStyle(.orange)
                
            case .none:
                EmptyView()
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("DONE")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white.opacity(0.15))
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Actions
    
    private func submitChallenge() {
        guard let card = selectedCard else { return }
        isLoading = true
        
        Task {
            do {
                let result = try await HeadToHeadService.shared.challengeWithMatchmaking(
                    myCard: card,
                    voteThreshold: selectedThreshold
                )
                
                isLoading = false
                matchResult = result
                step = .result
                
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Helpers
    
    private func thresholdLabel(_ threshold: Int) -> String {
        switch threshold {
        case 25: return "Quick Race"
        case 50: return "Standard"
        case 100: return "Marathon"
        default: return ""
        }
    }
    
    private func cardCell(card: CloudCard) -> some View {
        VStack(spacing: 0) {
            AsyncImage(url: URL(string: card.flatImageURL ?? card.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(Color.gray.opacity(0.3))
                        .overlay(Image(systemName: "car.fill").foregroundStyle(.white.opacity(0.3)))
                }
            }
            .frame(height: 100)
            .clipped()
            
            Text("\(card.make) \(card.model)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(6)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.7))
        }
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Pending Challenges Sheet

struct PendingChallengesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var h2hService = HeadToHeadService.shared
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if h2hService.myPendingChallenges.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No pending challenges")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(h2hService.myPendingChallenges) { race in
                                pendingChallengeCard(race: race)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func pendingChallengeCard(race: Race) -> some View {
        VStack(spacing: 12) {
            // Challenger info
            HStack {
                Text("\(race.challengerUsername) challenges you!")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(race.voteThreshold) votes")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Matchup
            HStack(spacing: 16) {
                VStack {
                    AsyncImage(url: URL(string: race.challengerCardImageURL)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 100, height: 65)
                    .cornerRadius(8)
                    
                    Text("\(race.challengerCardMake)")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                
                Text("VS")
                    .font(.title3.bold())
                    .foregroundStyle(.yellow)
                
                VStack {
                    AsyncImage(url: URL(string: race.defenderCardImageURL)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 100, height: 65)
                    .cornerRadius(8)
                    
                    Text("\(race.defenderCardMake)")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            
            // Accept / Decline buttons
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        isProcessing = true
                        try? await h2hService.declineChallenge(raceId: race.id)
                        isProcessing = false
                    }
                }) {
                    Text("Decline")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.6))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    Task {
                        isProcessing = true
                        try? await h2hService.acceptChallenge(raceId: race.id)
                        isProcessing = false
                        dismiss()
                    }
                }) {
                    Text("Accept")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(10)
                }
            }
            .disabled(isProcessing)
        }
        .padding()
        .background(.white.opacity(0.05))
        .cornerRadius(16)
    }
}


// MARK: - Preview

#Preview {
    HeadToHeadView()
}
