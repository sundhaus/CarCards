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
    @State private var showStartRace = false
    @State private var showFindRace = false
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
                // Top bar: back button, streak, pending count
                topBar
                
                Spacer()
                
                // Timer / vote count overlay
                finishLine
                
                // Race track with car progress indicators
                raceTrack
                
                // Two cards for voting (or no-race state)
                cardMatchup
                
                // Bottom action buttons: Find Race / Start Race
                bottomButtons
                    .padding(.bottom, 16)
            }
            
            // Winner celebration overlay
            if showWinnerCelebration, let side = winnerSide {
                winnerOverlay(side: side)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            h2hService.startListening()
            Task { await h2hService.checkExpiredRaces() }
            // Show no-races after brief delay if needed
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
        .sheet(isPresented: $showStartRace) {
            StartRaceView()
        }
        .sheet(isPresented: $showFindRace) {
            FindRaceView()
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Drag Strip Background
    
    private var dragStripBackground: some View {
        GeometryReader { geo in
            Image("dragStripTrack")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
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
                // No active races — prompt to find or start
                VStack(spacing: 8) {
                    Text("No active races")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Find a race or start your own below")
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
    
    // MARK: - Bottom Action Buttons
    
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            // Find Race
            Button(action: { showFindRace = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                    Text("FIND RACE")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            
            // Start Race
            Button(action: { showStartRace = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 14, weight: .bold))
                    Text("START RACE")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
        }
        .padding(.horizontal, 16)
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


// MARK: - Start Race (Pick Card → Pick Limit → Post Open Challenge)

struct StartRaceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cardService = CardService.shared
    
    @State private var step: StartStep = .pickCard
    @State private var selectedCard: CloudCard?
    @State private var selectedThreshold: Int = 50
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cooldownMessage: String?
    
    enum StartStep {
        case pickCard
        case pickLimit
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
                }
            }
            .navigationTitle("Start a Race")
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
    
    private var pickLimitView: some View {
        VStack(spacing: 20) {
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
            
            Text("Set Vote Limit")
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
            
            Button(action: postRace) {
                HStack {
                    Image(systemName: "flag.checkered")
                    Text("POST RACE")
                        .font(.headline.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            .disabled(isLoading)
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
    
    private func postRace() {
        guard let card = selectedCard else { return }
        isLoading = true
        Task {
            do {
                try await HeadToHeadService.shared.postOpenChallenge(myCard: card, voteThreshold: selectedThreshold)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
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

// MARK: - Find Race (Pick Limit → Match → Pick Your Card → Race Starts)

struct FindRaceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var h2hService = HeadToHeadService.shared
    @ObservedObject private var cardService = CardService.shared
    
    @State private var step: FindStep = .pickLimit
    @State private var selectedThreshold: Int = 50
    @State private var selectedOpenRace: Race?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cooldownMessage: String?
    
    enum FindStep {
        case pickLimit
        case pickCard
    }
    
    private var matchingRaces: [Race] {
        h2hService.openChallenges.filter {
            $0.voteThreshold == selectedThreshold &&
            $0.challengerId != FirebaseManager.shared.currentUserId
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch step {
                case .pickLimit:
                    pickLimitView
                case .pickCard:
                    pickMyCardView
                }
            }
            .navigationTitle("Find a Race")
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
    
    private var pickLimitView: some View {
        VStack(spacing: 20) {
            Text("Choose Vote Limit")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.top, 20)
            
            VStack(spacing: 12) {
                ForEach([25, 50, 100], id: \.self) { threshold in
                    let count = h2hService.openChallenges.filter {
                        $0.voteThreshold == threshold &&
                        $0.challengerId != FirebaseManager.shared.currentUserId
                    }.count
                    
                    Button(action: { selectedThreshold = threshold }) {
                        HStack {
                            Text("\(threshold)")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("votes")
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            if count > 0 {
                                Text("\(count) open")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(6)
                            } else {
                                Text("none")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            Image(systemName: selectedThreshold == threshold ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedThreshold == threshold ? .blue : .white.opacity(0.3))
                        }
                        .padding()
                        .background(selectedThreshold == threshold ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            // Preview matching races
            if !matchingRaces.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AVAILABLE RACES")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(matchingRaces) { race in
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: race.challengerCardImageURL)) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 50, height: 35)
                                    .cornerRadius(6)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(race.challengerUsername)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                        Text("\(race.challengerCardMake) \(race.challengerCardModel)")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(.white.opacity(0.05))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 160)
                }
            }
            
            Spacer()
            
            Button(action: findMatch) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(matchingRaces.isEmpty ? "NO RACES AT THIS LIMIT" : "FIND RACE")
                        .font(.headline.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: matchingRaces.isEmpty ? [.gray, .gray] : [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            .disabled(matchingRaces.isEmpty)
        }
    }
    
    private var pickMyCardView: some View {
        VStack(spacing: 16) {
            if let race = selectedOpenRace {
                VStack(spacing: 6) {
                    Text("Racing against \(race.challengerUsername)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    AsyncImage(url: URL(string: race.challengerCardImageURL)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 140, height: 90)
                    .cornerRadius(10)
                    Text("\(race.challengerCardMake) \(race.challengerCardModel)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                .padding(.top)
            }
            
            Divider().background(.white.opacity(0.2)).padding(.horizontal)
            
            Text("Pick your card")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(cardService.myCards.filter { $0.cardType == "vehicle" }) { card in
                        Button(action: { acceptWith(card: card) }) {
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
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal)
            }
            
            if let msg = cooldownMessage {
                Text(msg).font(.caption).foregroundStyle(.orange)
            }
            if isLoading {
                ProgressView().tint(.white).padding(.bottom)
            }
        }
    }
    
    private func findMatch() {
        guard let race = matchingRaces.randomElement() else { return }
        selectedOpenRace = race
        step = .pickCard
    }
    
    private func acceptWith(card: CloudCard) {
        guard let race = selectedOpenRace else { return }
        isLoading = true
        cooldownMessage = nil
        Task {
            do {
                let ok = try await HeadToHeadService.shared.checkCardCooldown(cardId: card.id)
                guard ok else {
                    let expiry = try await HeadToHeadService.shared.getCooldownExpiry(cardId: card.id)
                    if let expiry = expiry {
                        let remaining = expiry.timeIntervalSince(Date())
                        cooldownMessage = "\(card.make): cooldown \(Int(remaining) / 3600)h \((Int(remaining) % 3600) / 60)m"
                    }
                    isLoading = false
                    return
                }
                try await HeadToHeadService.shared.acceptOpenChallenge(raceId: race.id, myCard: card)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
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
