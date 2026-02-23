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
    @State private var showChallengeFlow = false
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
            // Full-screen drag strip background
            dragStripBackground
            
            VStack(spacing: 0) {
                // Top bar: back button, challenge button, streak, pending count
                topBar
                
                Spacer()
                
                // Finish line area
                finishLine
                
                // Race track with car progress indicators
                raceTrack
                
                // Two cards at the bottom
                cardMatchup
                    .padding(.bottom, 20)
            }
            
            // Winner celebration overlay
            if showWinnerCelebration, let side = winnerSide {
                winnerOverlay(side: side)
            }
            
            // No races available
            if showNoRacesMessage && h2hService.currentFeedRace == nil {
                noRacesOverlay
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            h2hService.startListening()
            // Check for expired races
            Task { await h2hService.checkExpiredRaces() }
        }
        .onDisappear {
            raceTimer.upstream.connect().cancel()
        }
        .onReceive(raceTimer) { _ in
            updateTimer()
        }
        .sheet(isPresented: $showChallengeFlow) {
            ChallengeFlowView()
        }
        .sheet(isPresented: $showPendingChallenges) {
            PendingChallengesView()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Streak indicator
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
            
            // Pending challenges badge
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
            
            // Challenge button
            Button(action: { showChallengeFlow = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                    Text("CHALLENGE")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Drag Strip Background
    
    private var dragStripBackground: some View {
        ZStack {
            // Base dark background
            Color.black.ignoresSafeArea()
            
            // Placeholder drag strip art (replace with James's custom asset)
            // For now, we draw a stylized track
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let laneWidth = width * 0.12
                let centerX = width / 2
                
                // Track surface
                Rectangle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.18))
                    .frame(width: laneWidth * 3.5)
                    .position(x: centerX, y: height / 2)
                
                // Lane divider (dashed center line)
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: height * 0.12))
                    path.addLine(to: CGPoint(x: centerX, y: height * 0.65))
                }
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [12, 8]))
                .foregroundStyle(.yellow.opacity(0.6))
                
                // Left lane line
                Path { path in
                    path.move(to: CGPoint(x: centerX - laneWidth * 0.8, y: height * 0.12))
                    path.addLine(to: CGPoint(x: centerX - laneWidth * 0.8, y: height * 0.65))
                }
                .stroke(.white.opacity(0.3), lineWidth: 1.5)
                
                // Right lane line
                Path { path in
                    path.move(to: CGPoint(x: centerX + laneWidth * 0.8, y: height * 0.12))
                    path.addLine(to: CGPoint(x: centerX + laneWidth * 0.8, y: height * 0.65))
                }
                .stroke(.white.opacity(0.3), lineWidth: 1.5)
            }
            .ignoresSafeArea()
            
            // TODO: Replace above with custom drag strip image:
            // Image("dragStripAerial")
            //     .resizable()
            //     .aspectRatio(contentMode: .fill)
            //     .ignoresSafeArea()
        }
    }
    
    // MARK: - Finish Line
    
    private var finishLine: some View {
        VStack(spacing: 4) {
            // Checkered pattern
            HStack(spacing: 0) {
                ForEach(0..<20, id: \.self) { i in
                    Rectangle()
                        .fill(i % 2 == 0 ? Color.white : Color.black)
                        .frame(width: 18, height: 12)
                }
            }
            
            HStack(spacing: 0) {
                ForEach(0..<20, id: \.self) { i in
                    Rectangle()
                        .fill(i % 2 == 0 ? Color.black : Color.white)
                        .frame(width: 18, height: 12)
                }
            }
            
            // Timer
            if let race = h2hService.currentFeedRace {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(timeRemainingText)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    
                    Text("•")
                    
                    Text("\(race.totalVotes)/\(race.voteThreshold) votes")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
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
            // Small car icon
            Image(systemName: "car.fill")
                .font(.system(size: 24))
                .foregroundStyle(side == .left ? .red : .blue)
                .rotationEffect(.degrees(-90)) // Point upward
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
                        // Left card owner
                        Text(race.challengerUsername)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text("VS")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.yellow)
                        
                        Spacer()
                        
                        // Right card owner
                        Text(race.defenderUsername)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    
                    // Two cards side by side — tap to vote
                    HStack(spacing: 16) {
                        // Left card (challenger)
                        raceCardView(
                            imageURL: race.challengerCardImageURL,
                            make: race.challengerCardMake,
                            model: race.challengerCardModel,
                            year: race.challengerCardYear,
                            votes: race.challengerVotes,
                            side: .left,
                            cardId: race.challengerCardId
                        )
                        
                        // Right card (defender)
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
                    
                    // Tap instruction
                    Text("TAP YOUR PICK TO ADD HEAT 🔥")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 4)
                }
            } else {
                // Loading or no races
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Finding a race...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if h2hService.currentFeedRace == nil {
                            showNoRacesMessage = true
                        }
                    }
                }
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
            VStack(spacing: 0) {
                // Card image
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
                .clipped()
                
                // Card info bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(make) \(model)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(year)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
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
    
    private var noRacesOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.4))
            
            Text("No races right now")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            Text("Challenge a friend to get one started!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            
            Button(action: { showChallengeFlow = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                    Text("Issue a Challenge")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(25)
            }
        }
    }
    
    // MARK: - Timer Update
    
    private func updateTimer() {
        guard let race = h2hService.currentFeedRace else {
            timeRemainingText = "--:--"
            return
        }
        timeRemainingText = race.timeRemainingString
    }
}

// MARK: - Challenge Flow (Sheet)

struct ChallengeFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cardService = CardService.shared
    @ObservedObject private var friendsService = FriendsService.shared
    
    @State private var step: ChallengeStep = .selectMyCard
    @State private var selectedMyCard: CloudCard?
    @State private var selectedOpponent: (userId: String, username: String)?
    @State private var selectedOpponentCard: CloudCard?
    @State private var selectedThreshold: Int = 50
    @State private var opponentCards: [CloudCard] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cooldownMessage: String?
    
    enum ChallengeStep {
        case selectMyCard
        case selectOpponent
        case selectOpponentCard
        case selectThreshold
        case confirm
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch step {
                case .selectMyCard:
                    selectMyCardView
                case .selectOpponent:
                    selectOpponentView
                case .selectOpponentCard:
                    selectOpponentCardView
                case .selectThreshold:
                    selectThresholdView
                case .confirm:
                    confirmView
                }
            }
            .navigationTitle("Issue Challenge")
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
    
    // MARK: Step 1: Select My Card
    
    private var selectMyCardView: some View {
        VStack(spacing: 16) {
            Text("Pick your card for the race")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top)
            
            if cardService.myCards.isEmpty {
                Text("No cards available")
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(cardService.myCards.filter { $0.cardType == "vehicle" }) { card in
                            Button(action: {
                                // Check cooldown before selecting
                                Task {
                                    let ok = try await HeadToHeadService.shared.checkCardCooldown(cardId: card.id)
                                    if ok {
                                        selectedMyCard = card
                                        step = .selectOpponent
                                    } else {
                                        let expiry = try await HeadToHeadService.shared.getCooldownExpiry(cardId: card.id)
                                        if let expiry = expiry {
                                            let remaining = expiry.timeIntervalSince(Date())
                                            let hours = Int(remaining) / 3600
                                            let mins = (Int(remaining) % 3600) / 60
                                            cooldownMessage = "On cooldown: \(hours)h \(mins)m remaining"
                                        }
                                    }
                                }
                            }) {
                                challengeCardCell(card: card)
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
                    .padding(.bottom)
            }
        }
    }
    
    // MARK: Step 2: Select Opponent
    
    private var selectOpponentView: some View {
        VStack(spacing: 16) {
            Text("Who do you want to challenge?")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(friendsService.following, id: \.id) { user in
                        Button(action: {
                            selectedOpponent = (userId: user.id, username: user.username)
                            // Fetch their cards
                            Task {
                                isLoading = true
                                opponentCards = await fetchUserCards(userId: user.id)
                                isLoading = false
                                step = .selectOpponentCard
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text(user.username)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Level \(user.level)")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding()
                            .background(.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
    }
    
    // MARK: Step 3: Select Opponent's Card
    
    private var selectOpponentCardView: some View {
        VStack(spacing: 16) {
            Text("Pick \(selectedOpponent?.username ?? "their") card to race against")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top)
            
            if opponentCards.isEmpty {
                Text("No vehicle cards available")
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(opponentCards.filter { $0.cardType == "vehicle" }) { card in
                            Button(action: {
                                selectedOpponentCard = card
                                step = .selectThreshold
                            }) {
                                challengeCardCell(card: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: Step 4: Select Vote Threshold
    
    private var selectThresholdView: some View {
        VStack(spacing: 24) {
            Text("How many votes to win?")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top, 40)
            
            Text("First to reach the threshold wins, or whoever leads after 2 hours.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                ForEach([25, 50, 100], id: \.self) { threshold in
                    Button(action: {
                        selectedThreshold = threshold
                        step = .confirm
                    }) {
                        HStack {
                            Text("\(threshold) votes")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text(thresholdLabel(threshold))
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding()
                        .background(
                            selectedThreshold == threshold
                                ? Color.orange.opacity(0.3)
                                : Color.white.opacity(0.05)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            
            Spacer()
        }
    }
    
    private func thresholdLabel(_ threshold: Int) -> String {
        switch threshold {
        case 25: return "Quick Race"
        case 50: return "Standard"
        case 100: return "Marathon"
        default: return ""
        }
    }
    
    // MARK: Step 5: Confirm
    
    private var confirmView: some View {
        VStack(spacing: 24) {
            Text("Confirm Challenge")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding(.top, 30)
            
            // Matchup preview
            HStack(spacing: 20) {
                if let myCard = selectedMyCard {
                    VStack {
                        AsyncImage(url: URL(string: myCard.flatImageURL ?? myCard.imageURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 120, height: 80)
                        .cornerRadius(8)
                        
                        Text("\(myCard.make) \(myCard.model)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
                
                Text("VS")
                    .font(.title.bold())
                    .foregroundStyle(.yellow)
                
                if let oppCard = selectedOpponentCard {
                    VStack {
                        AsyncImage(url: URL(string: oppCard.flatImageURL ?? oppCard.imageURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 120, height: 80)
                        .cornerRadius(8)
                        
                        Text("\(oppCard.make) \(oppCard.model)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
            
            // Details
            VStack(spacing: 8) {
                detailRow("Opponent", selectedOpponent?.username ?? "")
                detailRow("Threshold", "\(selectedThreshold) votes")
                detailRow("Duration", "2 hours")
            }
            .padding()
            .background(.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Send challenge button
            Button(action: sendChallenge) {
                HStack {
                    Image(systemName: "flag.checkered")
                    Text("SEND CHALLENGE")
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
    
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
        }
    }
    
    // MARK: - Helpers
    
    private func challengeCardCell(card: CloudCard) -> some View {
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
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func sendChallenge() {
        guard let myCard = selectedMyCard,
              let opponent = selectedOpponent,
              let oppCard = selectedOpponentCard else { return }
        
        isLoading = true
        Task {
            do {
                try await HeadToHeadService.shared.issueChallenge(
                    myCard: myCard,
                    opponentUserId: opponent.userId,
                    opponentUsername: opponent.username,
                    opponentCard: oppCard,
                    voteThreshold: selectedThreshold
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func fetchUserCards(userId: String) async -> [CloudCard] {
        do {
            let snapshot = try await FirebaseManager.shared.db.collection("cards")
                .whereField("ownerId", isEqualTo: userId)
                .getDocuments()
            return snapshot.documents.compactMap { CloudCard(document: $0) }
        } catch {
            print("⚠️ Failed to fetch user cards: \(error)")
            return []
        }
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
