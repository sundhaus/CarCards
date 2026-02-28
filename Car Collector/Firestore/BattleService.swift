//
//  BattleService.swift
//  CarCardCollector
//
//  Firebase service for the stat-based battle system.
//  Handles: matchmaking (ranked + casual), battle lifecycle, async turns,
//  rank point calculations, match history, and reward distribution.
//
//  Firestore collections:
//    battles/         — Active and recent battle documents
//    battleResults/   — Per-user match history (subcollection of users)
//    battleQueue/     — Temporary matchmaking queue entries
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class BattleService: ObservableObject {
    static let shared = BattleService()
    
    // MARK: - Published State
    
    @Published var currentBattle: BattleMatch?
    @Published var isSearching = false
    @Published var matchHistory: [BattleResult] = []
    @Published var rankPoints: Int = 0
    @Published var currentRank: BattleRank = .bronze1
    @Published var seasonWins: Int = 0
    @Published var seasonLosses: Int = 0
    
    // Card specs cache for battle stat calculations
    @Published var specsCache: [String: CarSpecs] = [:]
    
    // MARK: - Private
    
    private let db = FirebaseManager.shared.db
    private var battleListener: ListenerRegistration?
    private var queueListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    private var battlesCollection: CollectionReference { db.collection("battles") }
    private var queueCollection: CollectionReference { db.collection("battleQueue") }
    
    private init() {
        loadRankFromLocal()
    }
    
    deinit {
        battleListener?.remove()
        queueListener?.remove()
    }
    
    // MARK: - Rank Management
    
    private func loadRankFromLocal() {
        rankPoints = UserDefaults.standard.integer(forKey: "battleRankPoints")
        seasonWins = UserDefaults.standard.integer(forKey: "battleSeasonWins")
        seasonLosses = UserDefaults.standard.integer(forKey: "battleSeasonLosses")
        currentRank = BattleRank.from(points: rankPoints)
    }
    
    private func saveRankLocally() {
        UserDefaults.standard.set(rankPoints, forKey: "battleRankPoints")
        UserDefaults.standard.set(seasonWins, forKey: "battleSeasonWins")
        UserDefaults.standard.set(seasonLosses, forKey: "battleSeasonLosses")
    }
    
    /// Sync rank data from Firestore (called on login)
    func syncRankFromCloud() async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if let data = doc.data() {
                rankPoints = data["battleRankPoints"] as? Int ?? 0
                seasonWins = data["battleSeasonWins"] as? Int ?? 0
                seasonLosses = data["battleSeasonLosses"] as? Int ?? 0
                currentRank = BattleRank.from(points: rankPoints)
                saveRankLocally()
                print("✅ Synced battle rank: \(currentRank.rawValue) (\(rankPoints) pts)")
            }
        } catch {
            print("⚠️ Failed to sync battle rank: \(error)")
        }
    }
    
    /// Update rank points after a battle
    private func updateRankPoints(change: Int) async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        rankPoints = max(0, rankPoints + change)
        currentRank = BattleRank.from(points: rankPoints)
        saveRankLocally()
        
        // Sync to Firestore
        do {
            try await db.collection("users").document(uid).updateData([
                "battleRankPoints": rankPoints,
                "battleSeasonWins": seasonWins,
                "battleSeasonLosses": seasonLosses
            ])
        } catch {
            print("⚠️ Failed to sync rank to cloud: \(error)")
        }
    }
    
    // MARK: - Matchmaking
    
    /// Join the matchmaking queue. Searches for an opponent with similar rank (ranked)
    /// or any opponent (casual). Returns when a match is found or timeout.
    func findMatch(mode: BattleMode, queueType: BattleQueueType) async throws -> BattleMatch {
        guard let uid = FirebaseManager.shared.currentUserId,
              let profile = UserService.shared.currentProfile else {
            throw BattleError.notAuthenticated
        }
        
        isSearching = true
        defer { isSearching = false }
        
        let player = BattlePlayer(
            userId: uid,
            username: profile.username,
            level: profile.level,
            rankPoints: rankPoints
        )
        
        // Step 1: Check if there's an existing match waiting for an opponent
        let existingMatch = try await findWaitingMatch(mode: mode, queueType: queueType, player: player)
        if let match = existingMatch {
            return match
        }
        
        // Step 2: No match found — create a new one and wait
        let matchId = UUID().uuidString
        let newMatch = BattleMatch(
            id: matchId,
            mode: mode,
            queueType: queueType,
            player1: player
        )
        
        try await battlesCollection.document(matchId).setData(newMatch.dictionary)
        print("🔍 Created battle \(matchId), waiting for opponent...")
        
        // Step 3: Listen for opponent to join
        return try await withCheckedThrowingContinuation { continuation in
            var resolved = false
            
            battleListener?.remove()
            battleListener = battlesCollection.document(matchId).addSnapshotListener { [weak self] snapshot, error in
                guard !resolved else { return }
                
                if let error = error {
                    resolved = true
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let snapshot = snapshot, let match = BattleMatch(document: snapshot) else { return }
                
                // Opponent joined!
                if match.player2 != nil && match.status != .searching {
                    resolved = true
                    Task { @MainActor in
                        self?.currentBattle = match
                    }
                    continuation.resume(returning: match)
                }
            }
            
            // Timeout after 5 minutes
            Task {
                try? await Task.sleep(nanoseconds: UInt64(AsyncTurnConfig.matchmakingTimeoutSeconds * 1_000_000_000))
                guard !resolved else { return }
                resolved = true
                
                // Clean up the waiting match
                try? await self.battlesCollection.document(matchId).updateData([
                    "status": BattleStatus.cancelled.rawValue
                ])
                self.battleListener?.remove()
                
                continuation.resume(throwing: BattleError.matchmakingTimeout)
            }
        }
    }
    
    /// Search for an existing battle that needs a player 2
    private func findWaitingMatch(mode: BattleMode, queueType: BattleQueueType, player: BattlePlayer) async throws -> BattleMatch? {
        let query: Query = battlesCollection
            .whereField("mode", isEqualTo: mode.rawValue)
            .whereField("queueType", isEqualTo: queueType.rawValue)
            .whereField("status", isEqualTo: BattleStatus.searching.rawValue)
            .limit(to: 10)
        
        let snapshot = try await query.getDocuments()
        let candidates = snapshot.documents
            .compactMap { BattleMatch(document: $0) }
            .filter { $0.player1.userId != player.userId }  // Don't match yourself
        
        // For ranked: find closest rank
        let match: BattleMatch?
        if queueType == .ranked {
            match = candidates
                .sorted(by: { abs($0.player1.rankPoints - player.rankPoints) < abs($1.player1.rankPoints - player.rankPoints) })
                .first(where: { abs($0.player1.rankPoints - player.rankPoints) < 500 })
        } else {
            match = candidates.first
        }
        
        guard var foundMatch = match else { return nil }
        
        // Join the match as player 2
        foundMatch.player2 = player
        foundMatch.status = mode == .topTrumps ? .inProgress : .handSelection
        foundMatch.startedAt = Date()
        foundMatch.turnDeadline = Date().addingTimeInterval(AsyncTurnConfig.turnTimeoutSeconds)
        
        // Alternate who attacks first (player 2 gets first pick in draft)
        if mode != .topTrumps {
            foundMatch.currentAttackerId = player.userId
        }
        
        try await battlesCollection.document(foundMatch.id).updateData([
            "player2": player.toDictionary,
            "player2Id": player.userId,
            "status": foundMatch.status.rawValue,
            "startedAt": Timestamp(date: foundMatch.startedAt!),
            "turnDeadline": Timestamp(date: foundMatch.turnDeadline!)
        ])
        
        currentBattle = foundMatch
        listenToBattle(foundMatch.id)
        
        print("✅ Joined battle \(foundMatch.id) vs \(foundMatch.player1.username)")
        return foundMatch
    }
    
    // MARK: - Battle Lifecycle
    
    /// Listen to real-time updates on a battle
    func listenToBattle(_ battleId: String) {
        battleListener?.remove()
        
        battleListener = battlesCollection.document(battleId).addSnapshotListener { [weak self] snapshot, error in
            guard let snapshot = snapshot, let match = BattleMatch(document: snapshot) else { return }
            
            Task { @MainActor in
                self?.currentBattle = match
                
                // Auto-process if battle just finished
                if match.status == .finished && match.winnerId != nil {
                    await self?.processMatchResult(match)
                }
            }
        }
    }
    
    /// Stop listening to the current battle
    func stopListening() {
        battleListener?.remove()
        battleListener = nil
    }
    
    // MARK: - Hand Selection (Draft / Class / Budget modes)
    
    /// Submit hand selection for draft-style battles
    func submitHand(cardIds: [String], for battleId: String) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw BattleError.notAuthenticated
        }
        
        guard var battle = currentBattle, battle.id == battleId else {
            throw BattleError.battleNotFound
        }
        
        let isPlayer1 = battle.player1.userId == uid
        let playerField = isPlayer1 ? "player1" : "player2"
        
        // Detect synergies for this hand
        let cards = CardService.shared.myCards.filter { cardIds.contains($0.id) }
        let synergies = SynergyDetector.detect(cards: cards, specsMap: specsCache)
        let synergyField = isPlayer1 ? "player1Synergies" : "player2Synergies"
        
        try await battlesCollection.document(battleId).updateData([
            "\(playerField).handCardIds": cardIds,
            "\(playerField).isReady": true,
            synergyField: synergies.activeSynergies.map { $0.0.rawValue }
        ])
        
        // Check if both players are ready
        if isPlayer1 {
            battle.player1.handCardIds = cardIds
            battle.player1.isReady = true
        } else {
            battle.player2?.handCardIds = cardIds
            battle.player2?.isReady = true
        }
        
        let bothReady = battle.player1.isReady && (battle.player2?.isReady ?? false)
        if bothReady {
            try await battlesCollection.document(battleId).updateData([
                "status": BattleStatus.inProgress.rawValue,
                "turnDeadline": Timestamp(date: Date().addingTimeInterval(AsyncTurnConfig.turnTimeoutSeconds))
            ])
        }
        
        print("✅ Submitted hand of \(cardIds.count) cards for battle \(battleId)")
    }
    
    // MARK: - Play a Turn (Top Trumps / Round)
    
    /// Play a card and choose a stat category. This is the core battle action.
    /// For Top Trumps: attacker picks card + category. Defender's card auto-selected (or pre-selected).
    /// For Draft: attacker picks category, both cards are revealed.
    func playTurn(
        battleId: String,
        cardId: String,
        category: BattleCategory,
        cardSpecs: CarSpecs,
        cardRarity: CardRarity
    ) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw BattleError.notAuthenticated
        }
        
        guard let battle = currentBattle, battle.id == battleId else {
            throw BattleError.battleNotFound
        }
        
        guard battle.currentAttackerId == uid else {
            throw BattleError.notYourTurn
        }
        
        let isPlayer1 = battle.player1.userId == uid
        let myStats = BattleStatsEngine.calculate(specs: cardSpecs, rarity: cardRarity)
        let myValue = myStats.value(for: category)
        
        // Update the attacker's card choice
        let playerField = isPlayer1 ? "player1" : "player2"
        
        // Build partial round data (opponent hasn't played yet in async)
        var roundData: [String: Any] = [
            "id": battle.currentRound,
            "attackerId": uid,
            "categoryChosen": category.rawValue
        ]
        
        if isPlayer1 {
            roundData["player1CardId"] = cardId
            roundData["player1StatValue"] = myValue
        } else {
            roundData["player2CardId"] = cardId
            roundData["player2StatValue"] = myValue
        }
        
        try await battlesCollection.document(battleId).updateData([
            "\(playerField).currentCardId": cardId,
            "turnDeadline": Timestamp(date: Date().addingTimeInterval(AsyncTurnConfig.turnTimeoutSeconds))
        ])
        
        print("⚔️ Played \(category.rawValue) with value \(myValue)")
    }
    
    /// Respond to opponent's category pick (defender plays their card)
    func respondToTurn(
        battleId: String,
        cardId: String,
        cardSpecs: CarSpecs,
        cardRarity: CardRarity
    ) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw BattleError.notAuthenticated
        }
        
        guard let battle = currentBattle, battle.id == battleId else {
            throw BattleError.battleNotFound
        }
        
        // The current attacker already chose a category — we're responding
        guard battle.currentAttackerId != uid else {
            throw BattleError.notYourTurn
        }
        
        let isPlayer1 = battle.player1.userId == uid
        let category = battle.rounds.last.flatMap { BattleCategory(rawValue: $0.categoryChosen) }
            ?? .power  // Fallback
        
        let myStats = BattleStatsEngine.calculate(specs: cardSpecs, rarity: cardRarity)
        let myValue = myStats.value(for: category)
        
        // Get attacker's value from the partial round
        let attackerValue: Int
        if isPlayer1 {
            // I'm player1, attacker is player2
            attackerValue = battle.rounds.last?.player2StatValue ?? 0
        } else {
            attackerValue = battle.rounds.last?.player1StatValue ?? 0
        }
        
        // Determine round winner
        let winnerId: String?
        if myValue > attackerValue {
            winnerId = uid
        } else if attackerValue > myValue {
            winnerId = battle.currentAttackerId
        } else {
            winnerId = nil  // Tie
        }
        
        // Build completed round
        let completedRound: [String: Any] = [
            "id": battle.currentRound,
            "attackerId": battle.currentAttackerId,
            "categoryChosen": category.rawValue,
            "player1CardId": isPlayer1 ? cardId : (battle.player1.currentCardId ?? ""),
            "player1StatValue": isPlayer1 ? myValue : attackerValue,
            "player2CardId": isPlayer1 ? (battle.player2?.currentCardId ?? "") : cardId,
            "player2StatValue": isPlayer1 ? attackerValue : myValue,
            "winnerId": winnerId ?? NSNull(),
            "completedAt": Timestamp(date: Date())
        ]
        
        // Update scores
        var p1Score = battle.player1.score
        var p2Score = battle.player2?.score ?? 0
        if winnerId == battle.player1.userId { p1Score += 1 }
        else if winnerId == battle.player2?.userId { p2Score += 1 }
        
        // Check if battle is over
        let maxRounds = battle.mode.roundCount
        let battleOver = battle.currentRound >= maxRounds || p1Score > maxRounds / 2 || p2Score > maxRounds / 2
        
        var updates: [String: Any] = [
            "rounds": FieldValue.arrayUnion([completedRound]),
            "player1.score": p1Score,
            "player2.score": p2Score,
            "player1.currentCardId": FieldValue.delete(),
            "player2.currentCardId": FieldValue.delete()
        ]
        
        if battleOver {
            let finalWinner: String?
            if p1Score > p2Score { finalWinner = battle.player1.userId }
            else if p2Score > p1Score { finalWinner = battle.player2?.userId }
            else { finalWinner = nil }
            
            updates["status"] = BattleStatus.finished.rawValue
            updates["finishedAt"] = Timestamp(date: Date())
            if let w = finalWinner { updates["winnerId"] = w }
        } else {
            // Next round: alternate attacker
            let nextAttacker = battle.currentAttackerId == battle.player1.userId
                ? battle.player2?.userId ?? battle.player1.userId
                : battle.player1.userId
            
            updates["currentRound"] = battle.currentRound + 1
            updates["currentAttackerId"] = nextAttacker
            updates["turnDeadline"] = Timestamp(date: Date().addingTimeInterval(AsyncTurnConfig.turnTimeoutSeconds))
        }
        
        try await battlesCollection.document(battleId).updateData(updates)
        
        print("🏁 Round \(battle.currentRound) complete: P1=\(p1Score), P2=\(p2Score)")
    }
    
    // MARK: - Quick Battle (Top Trumps — both cards resolved instantly)
    
    /// For Top Trumps: attacker plays card + picks category.
    /// If opponent has already selected their card, resolve immediately.
    /// Otherwise, store the move and wait.
    func playTopTrumps(
        battleId: String,
        myCardId: String,
        mySpecs: CarSpecs,
        myRarity: CardRarity,
        category: BattleCategory,
        opponentCardId: String,
        opponentSpecs: CarSpecs,
        opponentRarity: CardRarity
    ) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw BattleError.notAuthenticated
        }
        
        guard let battle = currentBattle, battle.id == battleId else {
            throw BattleError.battleNotFound
        }
        
        let isPlayer1 = battle.player1.userId == uid
        
        // Calculate both stats
        let myStats = BattleStatsEngine.calculate(specs: mySpecs, rarity: myRarity)
        let opponentStats = BattleStatsEngine.calculate(specs: opponentSpecs, rarity: opponentRarity)
        
        let myValue = myStats.value(for: category)
        let opponentValue = opponentStats.value(for: category)
        
        // Determine winner
        let winnerId: String?
        if myValue > opponentValue { winnerId = uid }
        else if opponentValue > myValue { winnerId = battle.opponent(of: uid)?.userId }
        else { winnerId = nil }
        
        let p1Score = winnerId == battle.player1.userId ? 1 : 0
        let p2Score = winnerId == battle.player2?.userId ? 1 : 0
        
        let roundData: [String: Any] = [
            "id": 1,
            "attackerId": uid,
            "categoryChosen": category.rawValue,
            "player1CardId": isPlayer1 ? myCardId : opponentCardId,
            "player1StatValue": isPlayer1 ? myValue : opponentValue,
            "player2CardId": isPlayer1 ? opponentCardId : myCardId,
            "player2StatValue": isPlayer1 ? opponentValue : myValue,
            "winnerId": winnerId ?? NSNull(),
            "completedAt": Timestamp(date: Date())
        ]
        
        try await battlesCollection.document(battleId).updateData([
            "rounds": [roundData],
            "player1.score": p1Score,
            "player2.score": p2Score,
            "player1.currentCardId": isPlayer1 ? myCardId : opponentCardId,
            "player2.currentCardId": isPlayer1 ? opponentCardId : myCardId,
            "status": BattleStatus.finished.rawValue,
            "winnerId": winnerId ?? NSNull(),
            "finishedAt": Timestamp(date: Date())
        ])
        
        print("⚡ Top Trumps resolved: \(category.rawValue) \(myValue) vs \(opponentValue)")
    }
    
    // MARK: - Process Match Result
    
    /// Called when a battle finishes. Distributes rewards and records history.
    private func processMatchResult(_ match: BattleMatch) async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        guard match.status == .finished else { return }
        
        let won = match.winnerId == uid
        let opponent = match.opponent(of: uid)
        
        // Calculate rewards
        let rewards = BattleRewards.calculate(
            won: won,
            mode: match.mode,
            queueType: match.queueType,
            currentRank: currentRank
        )
        
        // Update rank
        if match.queueType == .ranked {
            await updateRankPoints(change: rewards.rankChange)
            if won { seasonWins += 1 } else { seasonLosses += 1 }
            saveRankLocally()
        }
        
        // Award coins and XP
        let levelSystem = LevelSystem()
        levelSystem.addCoins(rewards.coins)
        levelSystem.addXP(rewards.xp)
        
        // Record match result
        let result = BattleResult(
            id: UUID().uuidString,
            matchId: match.id,
            mode: match.mode.rawValue,
            queueType: match.queueType.rawValue,
            opponentId: opponent?.userId ?? "",
            opponentUsername: opponent?.username ?? "Unknown",
            won: won,
            myScore: match.player(for: uid)?.score ?? 0,
            opponentScore: opponent?.score ?? 0,
            rankPointsChange: rewards.rankChange,
            coinsEarned: rewards.coins,
            xpEarned: rewards.xp,
            completedAt: Date()
        )
        
        // Save to Firestore
        do {
            try await db.collection("users").document(uid)
                .collection("battleResults").document(result.id)
                .setData(result.dictionary)
        } catch {
            print("⚠️ Failed to save battle result: \(error)")
        }
        
        print("🏆 Battle complete: \(won ? "WIN" : "LOSS") — +\(rewards.coins) coins, +\(rewards.xp) XP, rank \(rewards.rankChange > 0 ? "+" : "")\(rewards.rankChange)")
    }
    
    // MARK: - Match History
    
    /// Load recent match history for the current user
    func loadMatchHistory(limit: Int = 20) async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("battleResults")
                .order(by: "completedAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            matchHistory = snapshot.documents.compactMap { BattleResult(document: $0) }
            print("✅ Loaded \(matchHistory.count) battle results")
        } catch {
            print("❌ Failed to load match history: \(error)")
        }
    }
    
    // MARK: - Cancel / Forfeit
    
    /// Cancel matchmaking (before opponent joins)
    func cancelSearch() async {
        guard let battle = currentBattle, battle.status == .searching else { return }
        
        do {
            try await battlesCollection.document(battle.id).updateData([
                "status": BattleStatus.cancelled.rawValue
            ])
        } catch {
            print("⚠️ Failed to cancel search: \(error)")
        }
        
        battleListener?.remove()
        currentBattle = nil
        isSearching = false
    }
    
    /// Forfeit an in-progress battle (counts as a loss)
    func forfeit(battleId: String) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        guard let battle = currentBattle, battle.id == battleId else { return }
        
        let winnerId = battle.opponent(of: uid)?.userId
        
        try await battlesCollection.document(battleId).updateData([
            "status": BattleStatus.finished.rawValue,
            "winnerId": winnerId ?? NSNull(),
            "finishedAt": Timestamp(date: Date())
        ])
        
        print("🏳️ Forfeited battle \(battleId)")
    }
    
    // MARK: - Specs Loading
    
    /// Pre-load specs for a set of card IDs (for battle stat calculation)
    func loadSpecs(for cards: [CloudCard]) async {
        for card in cards where card.cardType == "vehicle" {
            if specsCache[card.id] == nil {
                let specs = await fetchSpecsFromFirestore(make: card.make, model: card.model, year: card.year)
                specsCache[card.id] = specs
            }
        }
    }
    
    /// Fetch CarSpecs from the shared vehicleSpecs Firestore collection
    private func fetchSpecsFromFirestore(make: String, model: String, year: String) async -> CarSpecs {
        let docId = "\(make)_\(model)_\(year)"
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        
        do {
            let doc = try await db.collection("vehicleSpecs").document(docId).getDocument()
            if let data = doc.data() {
                return CarSpecs.fromDictionary(data)
            }
        } catch {
            print("⚠️ Failed to load specs for \(make) \(model): \(error)")
        }
        return .empty
    }
    
    /// Get battle stats for a card (using cached specs)
    func battleStats(for card: CloudCard) -> BattleStats {
        let specs = specsCache[card.id] ?? .empty
        let rarity = CardRarity(rawValue: card.rarity ?? "Common") ?? .common
        return BattleStatsEngine.calculate(specs: specs, rarity: rarity, category: specs.category)
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        battleListener?.remove()
        queueListener?.remove()
        currentBattle = nil
        isSearching = false
    }
}

// MARK: - Init extension for programmatic BattleResult

extension BattleResult {
    init(id: String, matchId: String, mode: String, queueType: String,
         opponentId: String, opponentUsername: String, won: Bool,
         myScore: Int, opponentScore: Int, rankPointsChange: Int,
         coinsEarned: Int, xpEarned: Int, completedAt: Date) {
        self.id = id
        self.matchId = matchId
        self.mode = mode
        self.queueType = queueType
        self.opponentId = opponentId
        self.opponentUsername = opponentUsername
        self.won = won
        self.myScore = myScore
        self.opponentScore = opponentScore
        self.rankPointsChange = rankPointsChange
        self.coinsEarned = coinsEarned
        self.xpEarned = xpEarned
        self.completedAt = completedAt
    }
}

// MARK: - Errors

enum BattleError: LocalizedError {
    case notAuthenticated
    case battleNotFound
    case notYourTurn
    case matchmakingTimeout
    case invalidHand
    case alreadyInBattle
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:   return "Not signed in"
        case .battleNotFound:     return "Battle not found"
        case .notYourTurn:        return "It's not your turn"
        case .matchmakingTimeout: return "No opponents found. Try again later."
        case .invalidHand:        return "Invalid card selection"
        case .alreadyInBattle:    return "You're already in a battle"
        }
    }
}
