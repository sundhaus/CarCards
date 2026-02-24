//
//  HeadToHeadView.swift
//  CarCardCollector
//
//  Head-to-Head drag race page — aerial drag strip with card matchups
//  Users tap cards to vote ("add heat"), cars race to the finish line
//

import SwiftUI
import FirebaseFirestore

import SwiftUI

struct HeadToHeadView: View {
    var isLandscape: Bool = false
    
    @StateObject private var h2hService = HeadToHeadService.shared
    @ObservedObject private var cardService = CardService.shared
    
    // UI State
    @State private var showChallenge = false
    @State private var showHistory = false
    @State private var showPendingChallenges = false
    @State private var voteAnimation: VoteSide? = nil
    @State private var showWinnerCelebration = false
    @State private var winnerSide: VoteSide? = nil
    @State private var isVoting = false
    @State private var showNoRacesMessage = false
    @State private var raceTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeRemainingText = "--:--"
    @State private var unavailableCardIds: Set<String> = []
    
    @Environment(\.dismiss) private var dismiss
    
    enum VoteSide {
        case left, right
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image("dragStripTrack")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .allowsHitTesting(false)
            
            VStack(spacing: 0) {
                topBar
                
                // Timer directly under challenge button
                finishLine
                    .padding(.top, 8)
                
                // The race track with sliding cards
                if let race = h2hService.currentFeedRace {
                    raceTrackView(race: race)
                } else if showNoRacesMessage {
                    Spacer()
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
                    Spacer()
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Finding a race...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
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
            Task {
                await h2hService.checkExpiredRaces()
                unavailableCardIds = await loadUnavailableCardIds()
            }
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
        .sheet(isPresented: $showChallenge, onDismiss: {
            // Refresh feed to show newly matched race
            h2hService.votedRaceIds.removeAll()
            hasVoted = false
            cardsVisible = true
            h2hService.loadNextFeedRace()
            // Refresh blocked cards
            Task { unavailableCardIds = await loadUnavailableCardIds() }
        }) {
            ChallengeView(unavailableCardIds: unavailableCardIds)
        }
        .sheet(isPresented: $showHistory) {
            RaceHistoryView()
        }
        .sheet(isPresented: $showPendingChallenges) {
            PendingChallengesView()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        ZStack {
            // Center: Challenge + History buttons
            HStack(spacing: 10) {
                Button(action: { showChallenge = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14, weight: .bold))
                        Text("CHALLENGE")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(25)
                }
                
                Button(action: { showHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            
            // Left/Right: back, streak, bell
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
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
    
    // MARK: - Race Track with Sliding Cards
    
    @State private var hasVoted = false
    @State private var cardsVisible = true
    
    private func raceTrackView(race: Race) -> some View {
        let cardH: CGFloat = 100
        let cardW: CGFloat = cardH * (16.0 / 9.0)
        let steps = stepMarkers(for: race.voteThreshold)
        
        return GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom
            let trackTop: CGFloat = 20
            let trackBottom: CGFloat = geo.size.height - bottomInset - 130
            let trackHeight = trackBottom - trackTop
            
            // Step markers along both lanes — only visible after voting
            if hasVoted {
                ForEach(steps, id: \.self) { step in
                    let progress = CGFloat(step) / CGFloat(race.voteThreshold)
                    let y = trackBottom - (progress * trackHeight)
                    
                    // Left lane marker
                    Text("\(step)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .position(x: geo.size.width * 0.5 - cardW * 0.5 - 20, y: y)
                    
                    // Right lane marker
                    Text("\(step)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .position(x: geo.size.width * 0.5 + cardW * 0.5 + 20, y: y)
                    
                    // Dashed line across
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(width: cardW * 2 + 40, height: 1)
                        .position(x: geo.size.width / 2, y: y)
                }
                
                // Finish line at top
                HStack(spacing: 2) {
                    Text("🏁")
                        .font(.system(size: 14))
                    Text("FINISH")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("🏁")
                        .font(.system(size: 14))
                }
                .position(x: geo.size.width / 2, y: trackTop - 5)
                .transition(.opacity)
            }
            
            // Left card (challenger)
            let leftProgress = CGFloat(race.challengerVotes) / CGFloat(max(race.voteThreshold, 1))
            let leftY = trackBottom - (min(leftProgress, 1.0) * trackHeight) - cardH / 2
            
            VStack(spacing: 4) {
                Text(race.challengerUsername)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                
                slidingCard(
                    imageURL: race.challengerCardImageURL,
                    votes: race.challengerVotes,
                    threshold: race.voteThreshold,
                    side: .left,
                    cardId: race.challengerCardId,
                    cardW: cardW,
                    cardH: cardH
                )
            }
            .position(
                x: geo.size.width / 2 - cardW * 0.5 - 8,
                y: hasVoted ? leftY : trackBottom - cardH / 2
            )
            .opacity(cardsVisible ? 1 : 0)
            .animation(
                hasVoted ? .spring(response: 0.8, dampingFraction: 0.7) : .none,
                value: race.challengerVotes
            )
            
            // Right card (defender)
            let rightProgress = CGFloat(race.defenderVotes) / CGFloat(max(race.voteThreshold, 1))
            let rightY = trackBottom - (min(rightProgress, 1.0) * trackHeight) - cardH / 2
            
            VStack(spacing: 4) {
                Text(race.defenderUsername)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                
                slidingCard(
                    imageURL: race.defenderCardImageURL,
                    votes: race.defenderVotes,
                    threshold: race.voteThreshold,
                    side: .right,
                    cardId: race.defenderCardId,
                    cardW: cardW,
                    cardH: cardH
                )
            }
            .position(
                x: geo.size.width / 2 + cardW * 0.5 + 8,
                y: hasVoted ? rightY : trackBottom - cardH / 2
            )
            .opacity(cardsVisible ? 1 : 0)
            .animation(
                hasVoted ? .spring(response: 0.8, dampingFraction: 0.7) : .none,
                value: race.defenderVotes
            )
            
            // VS badge centered between cards
            Text("VS")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.yellow)
                .position(x: geo.size.width / 2, y: trackBottom - cardH / 2 + 10)
                .opacity(cardsVisible && !hasVoted ? 1 : 0)
            
            // Bottom text below cards
            Text("TAP YOUR PICK TO ADD HEAT 🔥")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .position(x: geo.size.width / 2, y: trackBottom + 20)
                .opacity(!hasVoted ? 1 : 0)
        }
    }
    
    // Step markers based on race threshold
    private func stepMarkers(for threshold: Int) -> [Int] {
        switch threshold {
        case 25:
            return [5, 10, 15, 20, 25]
        case 50:
            return [10, 20, 30, 40, 50]
        case 100:
            return [20, 40, 60, 80, 100]
        default:
            let step = max(threshold / 5, 1)
            return stride(from: step, through: threshold, by: step).map { $0 }
        }
    }
    
    // Individual sliding card (tappable to vote)
    private func slidingCard(
        imageURL: String,
        votes: Int,
        threshold: Int,
        side: VoteSide,
        cardId: String,
        cardW: CGFloat,
        cardH: CGFloat
    ) -> some View {
        Button(action: {
            guard !isVoting else { return }
            voteForCard(cardId: cardId, side: side)
        }) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure(_):
                        Rectangle().fill(Color.gray.opacity(0.3))
                            .overlay(Image(systemName: "car.fill").font(.title2).foregroundStyle(.white.opacity(0.3)))
                    default:
                        Rectangle().fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView().tint(.white))
                    }
                }
                .frame(width: cardW, height: cardH)
                .clipped()
                .cornerRadius(cardH * 0.09)
                
                // Vote count pill — only visible after user votes
                if hasVoted {
                    Text("\(votes)/\(threshold)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, 4)
                        .transition(.opacity)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cardH * 0.09)
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
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        isVoting = true
        
        // Animate the vote
        withAnimation(.spring(response: 0.3)) {
            voteAnimation = side
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        let isParticipant = race.challengerId == uid || race.defenderId == uid
        
        // Trigger sliding animation
        hasVoted = true
        
        Task {
            do {
                let updatedRace = try await h2hService.castVote(
                    raceId: race.id,
                    votedForCardId: cardId
                )
                
                // Immediately update the displayed race with new vote counts
                await MainActor.run {
                    h2hService.currentFeedRace = updatedRace
                }
                
                // Check if race just finished
                if updatedRace.status == .finished || updatedRace.winnerId != nil {
                    let winSide: VoteSide = (updatedRace.winnerId == updatedRace.challengerId) ? .left : .right
                    withAnimation {
                        winnerSide = winSide
                        showWinnerCelebration = true
                    }
                    
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    withAnimation {
                        showWinnerCelebration = false
                        winnerSide = nil
                    }
                }
                
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation {
                    voteAnimation = nil
                }
                
                // Wait 2 seconds for user to see the updated positions, then advance
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                // Mark this race as voted so we don't cycle back to it
                h2hService.markRaceVoted(race.id)
                
                // Fade out cards
                withAnimation(.easeOut(duration: 0.3)) {
                    cardsVisible = false
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                
                // Reset position to bottom (no animation)
                hasVoted = false
                
                // Load next race
                h2hService.loadNextFeedRace()
                
                // Fade in new cards at bottom
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(.easeIn(duration: 0.3)) {
                    cardsVisible = true
                }
                isVoting = false
                
            } catch {
                print("❌ Vote failed: \(error.localizedDescription)")
                withAnimation { voteAnimation = nil }
                
                // Mark as voted so we skip this race
                h2hService.markRaceVoted(race.id)
                
                // Fade out and advance to next race
                withAnimation(.easeOut(duration: 0.3)) {
                    cardsVisible = false
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                hasVoted = false
                h2hService.loadNextFeedRace()
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(.easeIn(duration: 0.3)) {
                    cardsVisible = true
                }
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
    
    private func loadUnavailableCardIds() async -> Set<String> {
        guard let uid = FirebaseManager.shared.currentUserId else { return [] }
        var blocked = Set<String>()
        
        let db = FirebaseManager.shared.db
        do {
            let activeSnap = try await db.collection("races")
                .whereField("status", isEqualTo: "active")
                .getDocuments()
            let openSnap = try await db.collection("races")
                .whereField("status", isEqualTo: "open")
                .getDocuments()
            
            for doc in activeSnap.documents + openSnap.documents {
                let data = doc.data()
                if let cId = data["challengerId"] as? String, cId == uid,
                   let cardId = data["challengerCardId"] as? String {
                    blocked.insert(cardId)
                }
                if let dId = data["defenderId"] as? String, dId == uid,
                   let cardId = data["defenderCardId"] as? String {
                    blocked.insert(cardId)
                }
            }
            
            // Also block cards in pending duo invites
            let pendingInvites = try await db.collection("duoInvites")
                .whereField("inviterId", isEqualTo: uid)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            for doc in pendingInvites.documents {
                if let cardId = doc.data()["inviterCardId"] as? String {
                    blocked.insert(cardId)
                }
            }
        } catch {
            print("⚠️ Error fetching active races for card filter: \(error)")
        }
        
        for card in cardService.myCards where card.cardType == "vehicle" {
            if let ok = try? await HeadToHeadService.shared.checkCardCooldown(cardId: card.id), !ok {
                blocked.insert(card.id)
            }
        }
        
        return blocked
    }
}



// MARK: - Challenge View (Mode → Pick Card → Pick Limit → Auto-Match or Queue)

struct ChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cardService = CardService.shared
    @ObservedObject private var h2hService = HeadToHeadService.shared
    
    let unavailableCardIds: Set<String>
    
    @State private var step: ChallengeStep = .pickMode
    @State private var challengeMode: ChallengeMode = .solo
    @State private var selectedCard: CloudCard?
    @State private var selectedThreshold: Int = 50
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cooldownMessage: String?
    @State private var matchResult: MatchResult?
    @State private var inviteListener: ListenerRegistration?
    @State private var teammateAccepted = false
    @State private var acceptedInvite: DuoInvite?
    
    enum ChallengeMode {
        case solo, duo
    }
    
    enum ChallengeStep {
        case pickMode
        case pickCard
        case pickLimit
        case pickTeammate
        case result
    }
    
    enum MatchResult {
        case matched(Race)   // Found an opponent, race started
        case queued          // No match, posted to queue
        case waitingForTeammate(String) // Waiting for duo partner to accept (inviteId)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch step {
                case .pickMode:
                    pickModeView
                case .pickCard:
                    pickCardView
                case .pickLimit:
                    pickLimitView
                case .pickTeammate:
                    pickTeammateView
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
    
    // MARK: Step 1 - Pick Mode (Solo or Duo)
    
    private var pickModeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Choose Your Mode")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("How do you want to race?")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            
            VStack(spacing: 16) {
                // Solo button
                Button(action: {
                    challengeMode = .solo
                    withAnimation { step = .pickCard }
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 28))
                            .frame(width: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Solo")
                                .font(.title3.bold())
                            Text("1v1 — your card vs an opponent")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                    )
                }
                
                // Duo button
                Button(action: {
                    challengeMode = .duo
                    withAnimation { step = .pickCard }
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 28))
                            .frame(width: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duo")
                                .font(.title3.bold())
                            Text("2v2 — team up with a friend")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: Step 2 - Pick a Card
    
    private var pickCardView: some View {
        VStack(spacing: 16) {
            Text("Pick a Card")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.top)
            
            if availableCards.isEmpty {
                Spacer()
                Text("No vehicle cards available")
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(availableCards) { card in
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
    
    private var availableCards: [CloudCard] {
        cardService.myCards.filter { card in
            card.cardType == "vehicle" && !unavailableCardIds.contains(card.id)
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
    
    // MARK: Step 4 - Pick Teammate (Duo only)
    
    @State private var friends: [(id: String, username: String, pfpURL: String?)] = []
    @State private var selectedTeammate: (id: String, username: String)?
    @State private var loadingFriends = true
    
    private var pickTeammateView: some View {
        VStack(spacing: 16) {
            Text("Pick a Teammate")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.top)
            
            Text("Choose a friend to team up with")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            
            if loadingFriends {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if friends.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No friends yet")
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Follow people to team up!")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(friends, id: \.id) { friend in
                            Button(action: {
                                selectedTeammate = (id: friend.id, username: friend.username)
                            }) {
                                HStack(spacing: 12) {
                                    // PFP
                                    if let urlString = friend.pfpURL, let url = URL(string: urlString) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Circle().fill(Color(.systemGray4))
                                                .overlay(
                                                    Text(String(friend.username.prefix(1)).uppercased())
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundStyle(.white)
                                                )
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color(.systemGray4))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Text(String(friend.username.prefix(1)).uppercased())
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(.white)
                                            )
                                    }
                                    
                                    Text(friend.username)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    
                                    if selectedTeammate?.id == friend.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.title3)
                                    } else {
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                                            .frame(width: 24, height: 24)
                                    }
                                }
                                .padding(12)
                                .background(
                                    selectedTeammate?.id == friend.id
                                    ? Color.orange.opacity(0.15)
                                    : Color.white.opacity(0.05)
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Send invite button
                Button(action: sendDuoInvite) {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text("SEND INVITE")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        selectedTeammate != nil
                        ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray, .gray.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                }
                .disabled(selectedTeammate == nil || isLoading)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .task {
            await loadFriends()
        }
    }
    
    private func loadFriends() async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        let db = FirebaseManager.shared.db
        
        do {
            let followSnap = try await db.collection("follows")
                .whereField("followerId", isEqualTo: uid)
                .getDocuments()
            
            var result: [(id: String, username: String, pfpURL: String?)] = []
            
            for doc in followSnap.documents {
                guard let followedId = doc.data()["followingId"] as? String else { continue }
                if let userDoc = try? await db.collection("users").document(followedId).getDocument(),
                   let data = userDoc.data() {
                    let username = data["username"] as? String ?? "Unknown"
                    let pfp = data["profilePictureURL"] as? String
                    result.append((id: followedId, username: username, pfpURL: pfp))
                }
            }
            
            friends = result.sorted { $0.username.lowercased() < $1.username.lowercased() }
        } catch {
            print("⚠️ Error loading friends: \(error)")
        }
        loadingFriends = false
    }
    
    // MARK: Step 5 - Result (Matched or Queued)
    
    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            switch matchResult {
            case .matched(let race):
                let uid = FirebaseManager.shared.currentUserId ?? ""
                let opponentName = race.challengerId == uid ? race.defenderUsername : race.challengerUsername
                
                Image(systemName: "car.2.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                
                Text("MATCHED!")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                
                Text("Racing against \(opponentName)")
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
                
            case .waitingForTeammate(let inviteId):
                if teammateAccepted, let accepted = acceptedInvite {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    
                    Text("TEAM READY!")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    
                    Text("\(accepted.teammateUsername) joined with their card")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    // Show teammate's card
                    if !accepted.teammateCardImageURL.isEmpty {
                        AsyncImage(url: URL(string: accepted.teammateCardImageURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 140, height: 90)
                        .cornerRadius(10)
                    }
                    
                    Text("Your duo is entering matchmaking...")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    Text("INVITE SENT")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    
                    if let teammate = selectedTeammate {
                        Text("Waiting for \(teammate.username) to pick a card...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    ProgressView()
                        .tint(.blue)
                        .scaleEffect(1.2)
                    
                    Text("They have 5 minutes to accept")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    // Start listening for acceptance
                    Color.clear.frame(height: 0)
                        .onAppear {
                            listenForInviteAcceptance(inviteId: inviteId)
                        }
                        .onDisappear {
                            inviteListener?.remove()
                            inviteListener = nil
                        }
                }
                
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
        
        // Duo mode: go to teammate selection first
        if challengeMode == .duo {
            withAnimation { step = .pickTeammate }
            return
        }
        
        // Solo mode: matchmake immediately
        startMatchmaking(card: card)
    }
    
    private func startMatchmaking(card: CloudCard) {
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
    
    private func sendDuoInvite() {
        guard let card = selectedCard,
              let teammate = selectedTeammate else { return }
        isLoading = true
        
        Task {
            do {
                let inviteId = try await HeadToHeadService.shared.sendDuoInvite(
                    myCard: card,
                    teammateId: teammate.id,
                    teammateUsername: teammate.username,
                    voteThreshold: selectedThreshold
                )
                
                isLoading = false
                matchResult = .waitingForTeammate(inviteId)
                step = .result
                
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func listenForInviteAcceptance(inviteId: String) {
        inviteListener?.remove()
        
        inviteListener = FirebaseManager.shared.db.collection("duoInvites")
            .document(inviteId)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(),
                      let status = data["status"] as? String else { return }
                
                if status == "accepted" {
                    let invite = DuoInvite(document: snapshot!)
                    withAnimation {
                        acceptedInvite = invite
                        teammateAccepted = true
                    }
                    
                    // Auto-proceed to matchmaking after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        guard let card = selectedCard else { return }
                        inviteListener?.remove()
                        inviteListener = nil
                        // TODO: Duo matchmaking - for now fall through to solo
                        startMatchmaking(card: card)
                    }
                } else if status == "declined" || status == "expired" {
                    inviteListener?.remove()
                    inviteListener = nil
                    errorMessage = "Your teammate \(status) the invite"
                    // Go back to mode selection
                    step = .pickMode
                    matchResult = nil
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

// MARK: - Race History View

struct RaceHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var votedRaces: [(race: Race, votedForCardId: String)] = []
    @State private var isLoading = true
    @State private var pfpURLs: [String: String] = [:] // userId -> profilePictureURL
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    ProgressView().tint(.white)
                } else if votedRaces.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No votes yet")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Vote on races to track your picks!")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(votedRaces.enumerated()), id: \.offset) { _, entry in
                                voteHistoryRow(race: entry.race, myPickCardId: entry.votedForCardId)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Votes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                do {
                    votedRaces = try await HeadToHeadService.shared.fetchVotedRaces()
                    
                    // Fetch PFP URLs for all users in races
                    var userIds = Set<String>()
                    for entry in votedRaces {
                        userIds.insert(entry.race.challengerId)
                        userIds.insert(entry.race.defenderId)
                    }
                    
                    let db = FirebaseManager.shared.db
                    for userId in userIds where !userId.isEmpty {
                        if let doc = try? await db.collection("users").document(userId).getDocument(),
                           let url = doc.data()?["profilePictureURL"] as? String {
                            pfpURLs[userId] = url
                        }
                    }
                } catch {
                    print("❌ Failed to load vote history: \(error)")
                }
                isLoading = false
            }
        }
    }
    
    // MARK: - Vote History Row
    
    private func voteHistoryRow(race: Race, myPickCardId: String) -> some View {
        let isFinished = race.status == .finished
        let iPickedChallenger = myPickCardId == race.challengerCardId
        let challengerWon = race.winnerId == race.challengerId
        let defenderWon = race.winnerId == race.defenderId
        let myPickWon = isFinished && ((iPickedChallenger && challengerWon) || (!iPickedChallenger && defenderWon))
        let myPickLost = isFinished && !myPickWon && race.winnerId != nil
        
        let totalVotes = max(race.challengerVotes + race.defenderVotes, 1)
        let challengerRatio = CGFloat(race.challengerVotes) / CGFloat(totalVotes)
        
        return VStack(spacing: 10) {
            // Time remaining / status at top center
            if isFinished {
                Text("FINISHED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(race.timeRemainingString)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.orange)
            }
            
            // Progress bar with PFPs and usernames
            HStack(spacing: 8) {
                // Left: challenger PFP + name
                HStack(spacing: 6) {
                    pfpImage(userId: race.challengerId, username: race.challengerUsername)
                    Text(race.challengerUsername)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Right: name + defender PFP
                HStack(spacing: 6) {
                    Text(race.defenderUsername)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    pfpImage(userId: race.defenderId, username: race.defenderUsername)
                }
            }
            
            // Progress bar with flame at meeting point
            GeometryReader { geo in
                let leftWidth = max(geo.size.width * challengerRatio, 4)
                let rightWidth = max(geo.size.width * (1 - challengerRatio), 4)
                let challengerLeading = race.challengerVotes >= race.defenderVotes
                
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08)).frame(height: 6)
                    
                    // Left side (challenger)
                    Capsule()
                        .fill(challengerLeading ? Color.orange : Color.white.opacity(0.3))
                        .frame(width: leftWidth, height: 6)
                    
                    // Right side (defender)
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(!challengerLeading ? Color.orange : Color.white.opacity(0.3))
                            .frame(width: rightWidth, height: 6)
                    }
                    
                    // Flame at meeting point
                    Text("🔥")
                        .font(.system(size: 14))
                        .offset(x: leftWidth - 10, y: -1)
                }
            }
            .frame(height: 14)
            
            // Vote counts
            HStack {
                Text("\(race.challengerVotes)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(race.defenderVotes)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Cards side by side
            HStack(spacing: 12) {
                voteCard(
                    imageURL: race.challengerCardImageURL,
                    isMyPick: iPickedChallenger,
                    isWinner: challengerWon && isFinished,
                    isLoser: defenderWon && isFinished
                )
                
                Text("VS")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.3))
                
                voteCard(
                    imageURL: race.defenderCardImageURL,
                    isMyPick: !iPickedChallenger,
                    isWinner: defenderWon && isFinished,
                    isLoser: challengerWon && isFinished
                )
            }
        }
        .padding(14)
        .background(.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Vote Card
    
    private func voteCard(imageURL: String, isMyPick: Bool, isWinner: Bool, isLoser: Bool) -> some View {
        let cardH: CGFloat = 80
        let cardW: CGFloat = cardH * (16.0 / 9.0)
        let borderColor: Color = isMyPick ? .orange : .white.opacity(0.1)
        
        return ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(Color.gray.opacity(0.2))
                        .overlay(Image(systemName: "car.fill").foregroundStyle(.white.opacity(0.2)))
                }
            }
            .frame(width: cardW, height: cardH)
            .clipped()
            .cornerRadius(cardH * 0.09)
            .overlay(
                RoundedRectangle(cornerRadius: cardH * 0.09)
                    .stroke(borderColor, lineWidth: isMyPick ? 2 : 1)
            )
            
            if isMyPick {
                Text("MY PICK")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(borderColor)
                    .cornerRadius(4)
                    .padding(4)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - PFP Image
    
    @ViewBuilder
    private func pfpImage(userId: String, username: String) -> some View {
        if let urlString = pfpURLs[userId], let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(.systemGray4))
                    .overlay(
                        Text(String(username.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(username.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                )
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

// MARK: - Duo Invite Popup (Teammate receives this)

struct DuoInvitePopupView: View {
    let invite: DuoInvite
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cardService = CardService.shared
    @State private var selectedCard: CloudCard?
    @State private var isProcessing = false
    @State private var step: InviteStep = .review
    @State private var unavailableCardIds: Set<String> = []
    
    enum InviteStep {
        case review
        case pickCard
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch step {
                case .review:
                    reviewView
                case .pickCard:
                    pickCardForDuoView
                }
            }
            .navigationTitle("Duo Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var reviewView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            
            Text("DUO INVITE")
                .font(.title.bold())
                .foregroundStyle(.white)
            
            Text("\(invite.inviterUsername) wants to team up!")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            
            // Show inviter's card
            VStack(spacing: 8) {
                AsyncImage(url: URL(string: invite.inviterCardImageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 160, height: 100)
                .cornerRadius(10)
                
                Text("\(invite.inviterCardMake) \(invite.inviterCardModel)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                
                Text("\(invite.voteThreshold) vote race")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding()
            .background(.white.opacity(0.05))
            .cornerRadius(16)
            
            Spacer()
            
            // Accept / Decline buttons
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        isProcessing = true
                        try? await HeadToHeadService.shared.declineDuoInvite(inviteId: invite.id)
                        isProcessing = false
                        dismiss()
                    }
                }) {
                    Text("DECLINE")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.15))
                        .cornerRadius(16)
                }
                
                Button(action: {
                    withAnimation { step = .pickCard }
                }) {
                    Text("ACCEPT")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            .disabled(isProcessing)
        }
    }
    
    private var pickCardForDuoView: some View {
        let availableCards = cardService.myCards.filter { card in
            card.cardType == "vehicle" && !unavailableCardIds.contains(card.id)
        }
        
        return VStack(spacing: 16) {
            Text("Pick Your Card")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.top)
            
            Text("Choose a card to race alongside \(invite.inviterUsername)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if availableCards.isEmpty {
                Spacer()
                Text("No vehicle cards available")
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(availableCards) { card in
                            Button(action: {
                                selectedCard = card
                            }) {
                                VStack(spacing: 4) {
                                    AsyncImage(url: URL(string: card.flatImageURL ?? card.imageURL)) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(height: 80)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedCard?.id == card.id ? Color.blue : Color.white.opacity(0.1), lineWidth: selectedCard?.id == card.id ? 2 : 1)
                                    )
                                    
                                    Text("\(card.make) \(card.model)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Confirm button
                Button(action: {
                    guard let card = selectedCard else { return }
                    isProcessing = true
                    Task {
                        do {
                            try await HeadToHeadService.shared.acceptDuoInvite(
                                inviteId: invite.id,
                                myCard: card
                            )
                            isProcessing = false
                            dismiss()
                        } catch {
                            print("❌ Failed to accept duo invite: \(error)")
                            isProcessing = false
                        }
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                        }
                        Text("JOIN TEAM")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        selectedCard != nil
                        ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray, .gray.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                }
                .disabled(selectedCard == nil || isProcessing)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .task {
            await loadBlockedCards()
        }
    }
    
    private func loadBlockedCards() async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        var blocked = Set<String>()
        let db = FirebaseManager.shared.db
        
        do {
            // Cards in active/open races
            let activeSnap = try await db.collection("races")
                .whereField("status", isEqualTo: "active")
                .getDocuments()
            let openSnap = try await db.collection("races")
                .whereField("status", isEqualTo: "open")
                .getDocuments()
            
            for doc in activeSnap.documents + openSnap.documents {
                let data = doc.data()
                if let cId = data["challengerId"] as? String, cId == uid,
                   let cardId = data["challengerCardId"] as? String {
                    blocked.insert(cardId)
                }
                if let dId = data["defenderId"] as? String, dId == uid,
                   let cardId = data["defenderCardId"] as? String {
                    blocked.insert(cardId)
                }
            }
            
            // Cards in pending duo invites
            let pendingInvites = try await db.collection("duoInvites")
                .whereField("teammateId", isEqualTo: uid)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            for doc in pendingInvites.documents {
                if let cardId = doc.data()["teammateCardId"] as? String, !cardId.isEmpty {
                    blocked.insert(cardId)
                }
            }
        } catch {
            print("⚠️ Error loading blocked cards for duo: \(error)")
        }
        
        // Cards on cooldown
        for card in cardService.myCards where card.cardType == "vehicle" {
            if let ok = try? await HeadToHeadService.shared.checkCardCooldown(cardId: card.id), !ok {
                blocked.insert(card.id)
            }
        }
        
        unavailableCardIds = blocked
    }
}


// MARK: - Preview

#Preview {
    HeadToHeadView()
}
