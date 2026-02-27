//
//  HeadToHeadService.swift
//  CarCardCollector
//
//  Head-to-Head drag race service — challenges, voting, rewards via Firestore
//  Manages race lifecycle: challenge → accept → vote → finish → reward
//

import Foundation
import FirebaseFirestore

// MARK: - Data Models

/// A head-to-head race between two cards
struct Race: Identifiable {
    var id: String                  // Firestore document ID
    var challengerId: String        // User who issued challenge
    var challengerUsername: String
    var challengerCardId: String    // Firebase card ID
    var challengerCardMake: String
    var challengerCardModel: String
    var challengerCardYear: String
    var challengerCardImageURL: String
    var challengerVotes: Int
    
    var defenderId: String          // User who was challenged
    var defenderUsername: String
    var defenderCardId: String
    var defenderCardMake: String
    var defenderCardModel: String
    var defenderCardYear: String
    var defenderCardImageURL: String
    var defenderVotes: Int
    
    var voteThreshold: Int          // 25, 50, or 100
    var durationSeconds: Int        // 7200 (2 hours)
    var status: RaceStatus
    var createdAt: Date
    var startedAt: Date?            // When defender accepted
    var expiresAt: Date?            // startedAt + duration
    var finishedAt: Date?
    var winnerId: String?           // Winner user ID
    var winnerCardId: String?       // Winner card ID
    
    var voters: [String]            // UIDs who have voted (prevents double voting)
    
    // Duo pairing
    var isDuo: Bool                 // Is this part of a duo matchup?
    var pairedRaceId: String?       // The other race in this duo pair
    var duoTeamSide: String?        // "challenger" or "defender" - which duo team this belongs to
    
    // Entry fee / pot
    var entryFee: Int               // Coins each player pays to enter
    
    enum RaceStatus: String, Codable {
        case open       // Open challenge, anyone can accept
        case pending    // Awaiting defender acceptance (direct challenge)
        case active     // Race is live, accepting votes
        case finished   // Race completed (threshold or timer)
        case declined   // Defender declined
        case expired    // Pending challenge expired (not accepted)
        case cancelled  // Challenger cancelled
    }
    
    // From Firestore
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.challengerId = data["challengerId"] as? String ?? ""
        self.challengerUsername = data["challengerUsername"] as? String ?? ""
        self.challengerCardId = data["challengerCardId"] as? String ?? ""
        self.challengerCardMake = data["challengerCardMake"] as? String ?? ""
        self.challengerCardModel = data["challengerCardModel"] as? String ?? ""
        self.challengerCardYear = data["challengerCardYear"] as? String ?? ""
        self.challengerCardImageURL = data["challengerCardImageURL"] as? String ?? ""
        self.challengerVotes = data["challengerVotes"] as? Int ?? 0
        
        self.defenderId = data["defenderId"] as? String ?? ""
        self.defenderUsername = data["defenderUsername"] as? String ?? ""
        self.defenderCardId = data["defenderCardId"] as? String ?? ""
        self.defenderCardMake = data["defenderCardMake"] as? String ?? ""
        self.defenderCardModel = data["defenderCardModel"] as? String ?? ""
        self.defenderCardYear = data["defenderCardYear"] as? String ?? ""
        self.defenderCardImageURL = data["defenderCardImageURL"] as? String ?? ""
        self.defenderVotes = data["defenderVotes"] as? Int ?? 0
        
        self.voteThreshold = data["voteThreshold"] as? Int ?? 50
        self.durationSeconds = data["durationSeconds"] as? Int ?? 7200
        self.status = RaceStatus(rawValue: data["status"] as? String ?? "pending") ?? .pending
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.startedAt = (data["startedAt"] as? Timestamp)?.dateValue()
        self.expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue()
        self.finishedAt = (data["finishedAt"] as? Timestamp)?.dateValue()
        self.winnerId = data["winnerId"] as? String
        self.winnerCardId = data["winnerCardId"] as? String
        self.voters = data["voters"] as? [String] ?? []
        self.isDuo = data["isDuo"] as? Bool ?? false
        self.pairedRaceId = data["pairedRaceId"] as? String
        self.duoTeamSide = data["duoTeamSide"] as? String
        self.entryFee = data["entryFee"] as? Int ?? 0
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "challengerId": challengerId,
            "challengerUsername": challengerUsername,
            "challengerCardId": challengerCardId,
            "challengerCardMake": challengerCardMake,
            "challengerCardModel": challengerCardModel,
            "challengerCardYear": challengerCardYear,
            "challengerCardImageURL": challengerCardImageURL,
            "challengerVotes": challengerVotes,
            
            "defenderId": defenderId,
            "defenderUsername": defenderUsername,
            "defenderCardId": defenderCardId,
            "defenderCardMake": defenderCardMake,
            "defenderCardModel": defenderCardModel,
            "defenderCardYear": defenderCardYear,
            "defenderCardImageURL": defenderCardImageURL,
            "defenderVotes": defenderVotes,
            
            "voteThreshold": voteThreshold,
            "durationSeconds": durationSeconds,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "voters": voters
        ]
        
        dict["isDuo"] = isDuo
        if let pairedRaceId = pairedRaceId { dict["pairedRaceId"] = pairedRaceId }
        if let duoTeamSide = duoTeamSide { dict["duoTeamSide"] = duoTeamSide }
        dict["entryFee"] = entryFee
        
        if let startedAt = startedAt { dict["startedAt"] = Timestamp(date: startedAt) }
        if let expiresAt = expiresAt { dict["expiresAt"] = Timestamp(date: expiresAt) }
        if let finishedAt = finishedAt { dict["finishedAt"] = Timestamp(date: finishedAt) }
        if let winnerId = winnerId { dict["winnerId"] = winnerId }
        if let winnerCardId = winnerCardId { dict["winnerCardId"] = winnerCardId }
        
        return dict
    }
    
    // MARK: - Computed Properties
    
    var totalVotes: Int { challengerVotes + defenderVotes }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
    
    /// Progress toward finish line (0.0 to 1.0) for each car
    var challengerProgress: CGFloat {
        guard voteThreshold > 0 else { return 0 }
        return min(CGFloat(challengerVotes) / CGFloat(voteThreshold), 1.0)
    }
    
    var defenderProgress: CGFloat {
        guard voteThreshold > 0 else { return 0 }
        return min(CGFloat(defenderVotes) / CGFloat(voteThreshold), 1.0)
    }
    
    /// Time remaining string
    var timeRemainingString: String {
        guard let expiresAt = expiresAt else { return "--:--" }
        let remaining = expiresAt.timeIntervalSince(Date())
        if remaining <= 0 { return "0:00" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Tracks a user's voting streak for correct picks
struct VoteStreak: Codable {
    var currentStreak: Int
    var bestStreak: Int
    var lastVotedRaceId: String?
    var lastVoteCorrect: Bool?
    
    init() {
        self.currentStreak = 0
        self.bestStreak = 0
    }
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.currentStreak = data["currentStreak"] as? Int ?? 0
        self.bestStreak = data["bestStreak"] as? Int ?? 0
        self.lastVotedRaceId = data["lastVotedRaceId"] as? String
        self.lastVoteCorrect = data["lastVoteCorrect"] as? Bool
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "currentStreak": currentStreak,
            "bestStreak": bestStreak
        ]
        if let id = lastVotedRaceId { dict["lastVotedRaceId"] = id }
        if let correct = lastVoteCorrect { dict["lastVoteCorrect"] = correct }
        return dict
    }
    
    /// Streak multiplier for coin rewards
    var coinMultiplier: Double {
        switch currentStreak {
        case 0...2: return 1.0
        case 3...4: return 2.0   // 2x at 3 streak
        case 5...9: return 3.0   // 3x at 5 streak
        default:    return 5.0   // 5x at 10+ streak
        }
    }
}

/// Individual vote record (for reward distribution after race ends)
struct RaceVote: Identifiable {
    var id: String
    var raceId: String
    var oddsLocked: Bool
    var voterId: String
    var votedForCardId: String  // Which card the user picked
    var votedAt: Date
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.raceId = data["raceId"] as? String ?? ""
        self.voterId = data["voterId"] as? String ?? ""
        self.votedForCardId = data["votedForCardId"] as? String ?? ""
        self.votedAt = (data["votedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.oddsLocked = data["oddsLocked"] as? Bool ?? false
    }
}

// MARK: - Win Record (stored on cards)

struct CardWinRecord: Codable {
    var wins: Int
    var totalRaces: Int
    
    init() {
        self.wins = 0
        self.totalRaces = 0
    }
}

// MARK: - HeadToHeadService

@MainActor
class HeadToHeadService: ObservableObject {
    static let shared = HeadToHeadService()
    
    // Published state
    @Published var activeRaces: [Race] = []           // All active races for voting feed
    @Published var openChallenges: [Race] = []        // Open challenges anyone can accept
    @Published var myPendingChallenges: [Race] = []   // Challenges sent to me awaiting accept
    @Published var mySentChallenges: [Race] = []      // Challenges I sent awaiting accept
    @Published var currentFeedRace: Race?             // The race currently shown in the feed
    @Published var myStreak: VoteStreak = VoteStreak()
    @Published var isLoading = false
    
    private let db = FirebaseManager.shared.db
    private var racesListener: ListenerRegistration?
    private var openListener: ListenerRegistration?
    private var pendingListener: ListenerRegistration?
    private var streakListener: ListenerRegistration?
    
    deinit {
        racesListener?.remove()
        openListener?.remove()
        pendingListener?.remove()
        streakListener?.remove()
        duoInviteListener?.remove()
    }
    
    private var racesCollection: CollectionReference {
        db.collection("races")
    }
    
    private var votesCollection: CollectionReference {
        db.collection("raceVotes")
    }
    
    private var streaksCollection: CollectionReference {
        db.collection("voteStreaks")
    }
    
    // Reward constants
    static let voterXP = 5                   // XP per vote cast
    static let voterCorrectPickXP = 20       // XP for picking the winning card (solo)
    static let voterDuoSingleXP = 15         // XP for picking 1 of 2 winning cards in a duo
    static let voterDuoPerfectXP = 40        // XP for picking both winning cards in a duo
    static let winnerXP = 25                 // XP for race winner
    static let loserXP = 10                  // Consolation XP for loser
    static let correctPickCoins = 10         // Base coins for picking winner
    static let cardCooldownHours = 24        // Hours before a card can race again
    
    // Entry fee tiers: [voteThreshold: entryFee]
    static let entryFees: [Int: Int] = [
        25: 25,     // Quick Race: 25 coins
        50: 50,     // Standard: 50 coins
        100: 100    // Marathon: 100 coins
    ]
    
    // MARK: - Listeners
    
    func startListening() {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        // Listen for active races (for voting feed)
        racesListener = racesCollection
            .whereField("status", isEqualTo: "active")
            .order(by: "startedAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Active races listener error: \(error)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                print("🏁 Active races loaded: \(docs.count) total")
                Task { @MainActor in
                    self?.activeRaces = docs.compactMap { Race(document: $0) }
                    print("🏁 Parsed races: \(self?.activeRaces.count ?? 0)")
                    
                    // Update current feed race with fresh data if it's still active
                    if let currentId = self?.currentFeedRace?.id,
                       let updated = self?.activeRaces.first(where: { $0.id == currentId }) {
                        self?.currentFeedRace = updated
                    } else if self?.currentFeedRace == nil {
                        self?.loadNextFeedRace()
                    }
                }
            }
        
        // Listen for open challenges (anyone can accept)
        openListener = racesCollection
            .whereField("status", isEqualTo: "open")
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.openChallenges = docs.compactMap { Race(document: $0) }
                }
            }
        
        // Listen for direct challenges sent to me
        pendingListener = racesCollection
            .whereField("defenderId", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.myPendingChallenges = docs.compactMap { Race(document: $0) }
                }
            }
        
        // Load my streak
        loadStreak(uid: uid)
    }
    
    func stopListening() {
        racesListener?.remove()
        openListener?.remove()
        pendingListener?.remove()
        streakListener?.remove()
    }
    
    private func loadStreak(uid: String) {
        streakListener = streaksCollection.document(uid).addSnapshotListener { [weak self] snapshot, _ in
            Task { @MainActor in
                if let snapshot = snapshot, snapshot.exists,
                   let streak = VoteStreak(document: snapshot) {
                    self?.myStreak = streak
                } else {
                    self?.myStreak = VoteStreak()
                }
            }
        }
    }
    
    // MARK: - Feed Navigation
    
    /// Load the next race to show. Prioritizes races the user is in,
    /// then shows other active races the user hasn't voted on.
    /// Track races we've already voted on this session so we cycle through
    var votedRaceIds: Set<String> = []
    var pendingPairedRaceId: String? = nil  // After voting on a duo race, show its pair next
    
    func markRaceVoted(_ raceId: String) {
        votedRaceIds.insert(raceId)
        
        // If this was a duo race, queue the paired race next
        if let race = activeRaces.first(where: { $0.id == raceId }),
           race.isDuo, let pairedId = race.pairedRaceId {
            pendingPairedRaceId = pairedId
        }
    }
    
    func loadNextFeedRace() {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        let now = Date()
        // Filter out races past their expiry even if still marked active
        let liveRaces = activeRaces.filter { race in
            guard let expiresAt = race.expiresAt else { return true }
            return expiresAt > now
        }
        
        print("🏁 loadNextFeedRace: \(activeRaces.count) active, \(liveRaces.count) live, \(votedRaceIds.count) locally voted")
        
        // Priority 0: Paired duo race (must vote on both)
        if let pairedId = pendingPairedRaceId,
           let pairedRace = liveRaces.first(where: { $0.id == pairedId }),
           !votedRaceIds.contains(pairedId) {
            pendingPairedRaceId = nil
            print("🏁 Showing paired duo race: \(pairedId)")
            currentFeedRace = pairedRace
            return
        }
        pendingPairedRaceId = nil
        
        // Priority 1: My active races (always show, even if voted)
        let myRaces = liveRaces.filter { $0.challengerId == uid || $0.defenderId == uid }
        let myUnvoted = myRaces.filter { !votedRaceIds.contains($0.id) && !$0.voters.contains(uid) }
        if let myRace = myUnvoted.first {
            print("🏁 Showing my unvoted race: \(myRace.id)")
            currentFeedRace = myRace
            return
        }
        
        // Priority 2: Other people's races I haven't voted on
        let othersUnvoted = liveRaces.filter { race in
            race.challengerId != uid &&
            race.defenderId != uid &&
            !votedRaceIds.contains(race.id) &&
            !race.voters.contains(uid)
        }
        if let next = othersUnvoted.randomElement() {
            print("🏁 Showing other's race: \(next.id)")
            currentFeedRace = next
            return
        }
        
        print("🏁 No races to show")
        currentFeedRace = nil
    }
    
    // MARK: - Issue Challenge
    
    /// Challenge another user's card with one of yours
    func issueChallenge(
        myCard: CloudCard,
        opponentUserId: String,
        opponentUsername: String,
        opponentCard: CloudCard,
        voteThreshold: Int
    ) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        // Check card cooldown
        let cooldownOk = try await checkCardCooldown(cardId: myCard.id)
        guard cooldownOk else {
            throw HeadToHeadError.cardOnCooldown
        }
        
        let raceId = UUID().uuidString
        let race = Race(document: try await {
            let data: [String: Any] = [
                "challengerId": uid,
                "challengerUsername": profile.username,
                "challengerCardId": myCard.id,
                "challengerCardMake": myCard.make,
                "challengerCardModel": myCard.model,
                "challengerCardYear": myCard.year,
                "challengerCardImageURL": myCard.flatImageURL ?? myCard.imageURL,
                "challengerVotes": 0,
                
                "defenderId": opponentUserId,
                "defenderUsername": opponentUsername,
                "defenderCardId": opponentCard.id,
                "defenderCardMake": opponentCard.make,
                "defenderCardModel": opponentCard.model,
                "defenderCardYear": opponentCard.year,
                "defenderCardImageURL": opponentCard.flatImageURL ?? opponentCard.imageURL,
                "defenderVotes": 0,
                
                "voteThreshold": voteThreshold,
                "durationSeconds": 7200, // 2 hours
                "status": "pending",
                "createdAt": Timestamp(date: Date()),
                "voters": [String]()
            ]
            
            try await racesCollection.document(raceId).setData(data)
            return try await racesCollection.document(raceId).getDocument()
        }())
        
        print("🏁 Challenge issued: \(myCard.make) \(myCard.model) vs \(opponentCard.make) \(opponentCard.model)")
    }
    
    // MARK: - Open Challenge (anyone can accept)
    
    /// Post an open challenge — your card waits for anyone to match against it
    func postOpenChallenge(
        myCard: CloudCard,
        voteThreshold: Int
    ) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        let fee = HeadToHeadService.entryFees[voteThreshold] ?? 50
        
        // Check coins
        guard (UserService.shared.currentProfile?.coins ?? 0) >= fee else {
            throw HeadToHeadError.insufficientCoins
        }
        
        // Check card cooldown
        let cooldownOk = try await checkCardCooldown(cardId: myCard.id)
        guard cooldownOk else {
            throw HeadToHeadError.cardOnCooldown
        }
        
        // Deduct entry fee
        _ = UserService.shared.spendCoins(fee)
        
        let raceId = UUID().uuidString
        let data: [String: Any] = [
            "challengerId": uid,
            "challengerUsername": profile.username,
            "challengerCardId": myCard.id,
            "challengerCardMake": myCard.make,
            "challengerCardModel": myCard.model,
            "challengerCardYear": myCard.year,
            "challengerCardImageURL": myCard.flatImageURL ?? myCard.imageURL,
            "challengerVotes": 0,
            
            // Defender fields empty until someone accepts
            "defenderId": "",
            "defenderUsername": "",
            "defenderCardId": "",
            "defenderCardMake": "",
            "defenderCardModel": "",
            "defenderCardYear": "",
            "defenderCardImageURL": "",
            "defenderVotes": 0,
            
            "voteThreshold": voteThreshold,
            "durationSeconds": 7200,
            "status": "open",
            "createdAt": Timestamp(date: Date()),
            "voters": [String](),
            "entryFee": fee
        ]
        
        try await racesCollection.document(raceId).setData(data)
        
        print("🏁 Open challenge posted: \(myCard.make) \(myCard.model) — waiting for opponent")
    }
    
    // MARK: - Challenge with Auto-Matchmaking
    
    /// Try to match with an existing open challenge at the same vote limit.
    /// If a match is found, accept it and start the race.
    /// If no match, post as an open challenge and wait in the queue.
    func challengeWithMatchmaking(
        myCard: CloudCard,
        voteThreshold: Int
    ) async throws -> ChallengeView.MatchResult {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        // Check cooldown
        let cooldownOk = try await checkCardCooldown(cardId: myCard.id)
        guard cooldownOk else {
            throw HeadToHeadError.cardOnCooldown
        }
        
        // Check coins for entry fee
        let fee = HeadToHeadService.entryFees[voteThreshold] ?? 50
        guard (UserService.shared.currentProfile?.coins ?? 0) >= fee else {
            throw HeadToHeadError.insufficientCoins
        }
        
        // Check if this card is already in an active or open race
        let activeCheck = try await racesCollection
            .whereField("challengerCardId", isEqualTo: myCard.id)
            .whereField("status", in: ["open", "active"])
            .limit(to: 1)
            .getDocuments()
        
        if !activeCheck.documents.isEmpty {
            throw HeadToHeadError.cardAlreadyInRace
        }
        
        let defenderCheck = try await racesCollection
            .whereField("defenderCardId", isEqualTo: myCard.id)
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .getDocuments()
        
        if !defenderCheck.documents.isEmpty {
            throw HeadToHeadError.cardAlreadyInRace
        }
        
        // Look for an open challenge at this vote limit (not my own, not my own cards)
        let openSnapshot = try await racesCollection
            .whereField("status", isEqualTo: "open")
            .whereField("voteThreshold", isEqualTo: voteThreshold)
            .limit(to: 10)
            .getDocuments()
        
        let candidates = openSnapshot.documents
            .compactMap { Race(document: $0) }
            .filter { $0.challengerId != uid && !$0.isDuo }
        
        if let match = candidates.randomElement() {
            // Found a match — accept it
            try await acceptOpenChallenge(raceId: match.id, myCard: myCard)
            
            // Fetch updated race
            let updatedDoc = try await racesCollection.document(match.id).getDocument()
            if let updatedRace = Race(document: updatedDoc) {
                return .matched(updatedRace)
            }
            return .matched(match)
        } else {
            // No match — post as open challenge
            try await postOpenChallenge(myCard: myCard, voteThreshold: voteThreshold)
            return .queued
        }
    }
    
    // MARK: - Duo Matchmaking
    
    /// Create a duo pair: two linked races where Team A (inviter+teammate) vs Team B (opponent duo)
    /// For now, matches against another open duo or queues as open duo
    func duoMatchmaking(
        invite: DuoInvite
    ) async throws -> ChallengeView.MatchResult {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        let threshold = invite.voteThreshold
        
        // Look for an open duo challenge to match against
        let openDuoSnap = try await racesCollection
            .whereField("status", isEqualTo: "open")
            .whereField("isDuo", isEqualTo: true)
            .whereField("voteThreshold", isEqualTo: threshold)
            .limit(to: 10)
            .getDocuments()
        
        // Find opponent duo races (not ours)
        let openDuos = openDuoSnap.documents
            .compactMap { Race(document: $0) }
            .filter { $0.challengerId != uid && $0.challengerId != invite.teammateId }
        
        print("🏁 Duo matchmaking: found \(openDuoSnap.documents.count) open duo races, \(openDuos.count) from other teams")
        
        // Try to find a complete opponent pair by following pairedRaceId
        var matchedPair: (Race, Race)? = nil
        for race in openDuos {
            guard let pairedId = race.pairedRaceId else { continue }
            // Fetch the paired race
            if let pairedDoc = try? await racesCollection.document(pairedId).getDocument(),
               let pairedRace = Race(document: pairedDoc),
               pairedRace.status == .open,
               pairedRace.challengerId != uid,
               pairedRace.challengerId != invite.teammateId {
                matchedPair = (race, pairedRace)
                break
            }
        }
        
        if let (opp1, opp2) = matchedPair {
            print("🏁 Duo match found! Opp races: \(opp1.id) + \(opp2.id)")
            
            // Inviter takes race 1, teammate takes race 2
            let inviterCard = createCardProxy(
                id: invite.inviterCardId,
                make: invite.inviterCardMake,
                model: invite.inviterCardModel,
                year: invite.inviterCardYear,
                imageURL: invite.inviterCardImageURL
            )
            let teammateCard = createCardProxy(
                id: invite.teammateCardId,
                make: invite.teammateCardMake,
                model: invite.teammateCardModel,
                year: invite.teammateCardYear,
                imageURL: invite.teammateCardImageURL
            )
            
            // Use ForUser variant for both to avoid cooldown checks on proxy cards
            try await acceptOpenChallengeForUser(
                raceId: opp1.id,
                userId: invite.inviterId,
                username: invite.inviterUsername,
                card: inviterCard
            )
            try await acceptOpenChallengeForUser(
                raceId: opp2.id,
                userId: invite.teammateId,
                username: invite.teammateUsername,
                card: teammateCard
            )
            
            let updatedDoc = try await racesCollection.document(opp1.id).getDocument()
            
            // Update invite so the teammate can see the result
            try await duoInvitesCollection.document(invite.id).updateData([
                "status": "matched",
                "inviterRaceId": opp1.id,
                "teammateRaceId": opp2.id
            ])
            
            if let race = Race(document: updatedDoc) {
                return .matched(race)
            }
            return .matched(opp1)
        } else {
            // No duo match — post our duo as open
            let now = Date()
            let raceId1 = UUID().uuidString
            let raceId2 = UUID().uuidString
            
            let fee = HeadToHeadService.entryFees[threshold] ?? 50
            
            let baseData: [String: Any] = [
                "voteThreshold": threshold,
                "durationSeconds": 7200,
                "status": "open",
                "createdAt": Timestamp(date: now),
                "voters": [String](),
                "isDuo": true,
                "entryFee": fee,
                "challengerVotes": 0,
                "defenderVotes": 0,
                "defenderId": "",
                "defenderUsername": "",
                "defenderCardId": "",
                "defenderCardMake": "",
                "defenderCardModel": "",
                "defenderCardYear": "",
                "defenderCardImageURL": "",
            ]
            
            var race1Data = baseData
            race1Data["challengerId"] = uid  // Create with current user
            race1Data["challengerUsername"] = invite.inviterUsername
            race1Data["challengerCardId"] = invite.inviterCardId
            race1Data["challengerCardMake"] = invite.inviterCardMake
            race1Data["challengerCardModel"] = invite.inviterCardModel
            race1Data["challengerCardYear"] = invite.inviterCardYear
            race1Data["challengerCardImageURL"] = invite.inviterCardImageURL
            race1Data["pairedRaceId"] = raceId2
            
            var race2Data = baseData
            race2Data["challengerId"] = uid  // Create with current user
            race2Data["challengerUsername"] = invite.teammateUsername
            race2Data["challengerCardId"] = invite.teammateCardId
            race2Data["challengerCardMake"] = invite.teammateCardMake
            race2Data["challengerCardModel"] = invite.teammateCardModel
            race2Data["challengerCardYear"] = invite.teammateCardYear
            race2Data["challengerCardImageURL"] = invite.teammateCardImageURL
            race2Data["pairedRaceId"] = raceId1
            
            try await racesCollection.document(raceId1).setData(race1Data)
            try await racesCollection.document(raceId2).setData(race2Data)
            
            // Update challengerIds to actual users
            try await racesCollection.document(raceId1).updateData([
                "challengerId": invite.inviterId
            ])
            try await racesCollection.document(raceId2).updateData([
                "challengerId": invite.teammateId
            ])
            
            // Update invite status
            try await duoInvitesCollection.document(invite.id).updateData([
                "status": "queued",
                "inviterRaceId": raceId1,
                "teammateRaceId": raceId2
            ])
            
            print("🏁 Duo posted to queue: \(raceId1) paired with \(raceId2)")
            return .queued
        }
    }
    
    /// Accept an open challenge on behalf of another user (for duo teammate)
    func acceptOpenChallengeForUser(
        raceId: String,
        userId: String,
        username: String,
        card: CloudCard
    ) async throws {
        let now = Date()
        try await racesCollection.document(raceId).updateData([
            "defenderId": userId,
            "defenderUsername": username,
            "defenderCardId": card.id,
            "defenderCardMake": card.make,
            "defenderCardModel": card.model,
            "defenderCardYear": card.year,
            "defenderCardImageURL": card.flatImageURL ?? card.imageURL,
            "defenderVotes": 0,
            "status": "active",
            "startedAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: now.addingTimeInterval(7200))
        ])
    }
    
    /// Helper to create a minimal CloudCard proxy from invite data
    private func createCardProxy(id: String, make: String, model: String, year: String, imageURL: String) -> CloudCard {
        var card = CloudCard(
            id: id,
            ownerId: "",
            make: make,
            model: model,
            color: "",
            year: year,
            imageURL: imageURL
        )
        card.flatImageURL = imageURL
        return card
    }
    
    // MARK: - Debug: Seed Fake Opponent Duo
    
    /// Creates a fake opponent duo pair in the queue for testing 2v2 without 4 devices
    func seedFakeOpponentDuo(voteThreshold: Int) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        let now = Date()
        let raceId1 = UUID().uuidString
        let raceId2 = UUID().uuidString
        
        let fakeNames = [
            ("TestBot_A", "Porsche", "911 GT3", "2024"),
            ("TestBot_B", "Ferrari", "F40", "1992")
        ]
        
        let fee = HeadToHeadService.entryFees[voteThreshold] ?? 50
        
        let baseData: [String: Any] = [
            "voteThreshold": voteThreshold,
            "durationSeconds": 7200,
            "status": "open",
            "createdAt": Timestamp(date: now),
            "voters": [String](),
            "isDuo": true,
            "entryFee": fee,
            "challengerVotes": 0,
            "defenderVotes": 0,
            "defenderId": "",
            "defenderUsername": "",
            "defenderCardId": "",
            "defenderCardMake": "",
            "defenderCardModel": "",
            "defenderCardYear": "",
            "defenderCardImageURL": "",
        ]
        
        // Create with current user to pass Firestore rules, then update to bot
        for (index, raceId) in [raceId1, raceId2].enumerated() {
            let pairedId = index == 0 ? raceId2 : raceId1
            let fakeBotId = "fakeBot_\(raceId)"
            
            var createData = baseData
            createData["challengerId"] = uid
            createData["challengerUsername"] = fakeNames[index].0
            createData["challengerCardId"] = "fakeCard_\(raceId)"
            createData["challengerCardMake"] = fakeNames[index].1
            createData["challengerCardModel"] = fakeNames[index].2
            createData["challengerCardYear"] = fakeNames[index].3
            createData["challengerCardImageURL"] = ""
            createData["pairedRaceId"] = pairedId
            
            try await racesCollection.document(raceId).setData(createData)
            try await racesCollection.document(raceId).updateData([
                "challengerId": fakeBotId
            ])
        }
        
        print("🤖 Seeded fake opponent duo: \(raceId1) + \(raceId2) at \(voteThreshold) votes")
    }
    
    /// Creates a fake solo opponent in the queue for testing 1v1
    func seedFakeSoloOpponent(voteThreshold: Int) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        let now = Date()
        let raceId = UUID().uuidString
        let fee = HeadToHeadService.entryFees[voteThreshold] ?? 50
        
        var data: [String: Any] = [
            "challengerId": uid,
            "challengerUsername": "SoloBot",
            "challengerCardId": "fakeCard_\(raceId)",
            "challengerCardMake": "Toyota",
            "challengerCardModel": "Supra",
            "challengerCardYear": "1998",
            "challengerCardImageURL": "",
            "challengerVotes": 0,
            "defenderId": "",
            "defenderUsername": "",
            "defenderCardId": "",
            "defenderCardMake": "",
            "defenderCardModel": "",
            "defenderCardYear": "",
            "defenderCardImageURL": "",
            "defenderVotes": 0,
            "voteThreshold": voteThreshold,
            "durationSeconds": 7200,
            "status": "open",
            "createdAt": Timestamp(date: now),
            "voters": [String](),
            "isDuo": false,
            "entryFee": fee
        ]
        
        try await racesCollection.document(raceId).setData(data)
        try await racesCollection.document(raceId).updateData([
            "challengerId": "fakeBot_\(raceId)"
        ])
        
        print("🤖 Seeded fake solo opponent: \(raceId) at \(voteThreshold) votes")
    }
    
    /// Accept an open challenge by picking your card to race against
    func acceptOpenChallenge(raceId: String, myCard: CloudCard) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        // Check card cooldown
        let cooldownOk = try await checkCardCooldown(cardId: myCard.id)
        guard cooldownOk else {
            throw HeadToHeadError.cardOnCooldown
        }
        
        // Get entry fee from the race and deduct
        let raceDoc = try await racesCollection.document(raceId).getDocument()
        let fee = raceDoc.data()?["entryFee"] as? Int ?? 0
        if fee > 0 {
            guard (UserService.shared.currentProfile?.coins ?? 0) >= fee else {
                throw HeadToHeadError.insufficientCoins
            }
            _ = UserService.shared.spendCoins(fee)
        }
        
        let now = Date()
        let expiresAt = now.addingTimeInterval(7200)
        
        try await racesCollection.document(raceId).updateData([
            "defenderId": uid,
            "defenderUsername": profile.username,
            "defenderCardId": myCard.id,
            "defenderCardMake": myCard.make,
            "defenderCardModel": myCard.model,
            "defenderCardYear": myCard.year,
            "defenderCardImageURL": myCard.flatImageURL ?? myCard.imageURL,
            "status": "active",
            "startedAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: expiresAt)
        ])
        
        print("✅ Open challenge accepted! \(myCard.make) \(myCard.model) enters the race")
    }
    
    // MARK: - Accept / Decline Challenge
    
    func acceptChallenge(raceId: String) async throws {
        let now = Date()
        let expiresAt = now.addingTimeInterval(7200) // 2 hours
        
        try await racesCollection.document(raceId).updateData([
            "status": "active",
            "startedAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: expiresAt)
        ])
        
        print("✅ Challenge accepted, race is live!")
    }
    
    func declineChallenge(raceId: String) async throws {
        try await racesCollection.document(raceId).updateData([
            "status": "declined"
        ])
        
        print("❌ Challenge declined")
    }
    
    // MARK: - Vote (Add Heat)
    
    /// Cast a vote for one side of a race. Returns the updated race.
    func castVote(raceId: String, votedForCardId: String) async throws -> Race {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Use a transaction to prevent race conditions
        let updatedDoc = try await db.runTransaction { transaction, errorPointer -> DocumentSnapshot? in
            let raceRef = self.racesCollection.document(raceId)
            
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(raceRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            
            guard let data = document.data(),
                  let status = data["status"] as? String,
                  status == "active" else {
                errorPointer?.pointee = NSError(domain: "HeadToHead", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Race is not active"])
                return nil
            }
            
            // Check if already voted
            let voters = data["voters"] as? [String] ?? []
            guard !voters.contains(uid) else {
                errorPointer?.pointee = NSError(domain: "HeadToHead", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Already voted on this race"])
                return nil
            }
            
            // Determine which side gets the vote
            let challengerCardId = data["challengerCardId"] as? String ?? ""
            let voteField = (votedForCardId == challengerCardId) ? "challengerVotes" : "defenderVotes"
            
            // Increment vote and add voter
            transaction.updateData([
                voteField: FieldValue.increment(Int64(1)),
                "voters": FieldValue.arrayUnion([uid])
            ], forDocument: raceRef)
            
            return document
        }
        
        // Record individual vote for reward distribution
        let voteId = "\(raceId)_\(uid)"
        try await votesCollection.document(voteId).setData([
            "raceId": raceId,
            "voterId": uid,
            "votedForCardId": votedForCardId,
            "votedAt": Timestamp(date: Date())
        ])
        
        // Award XP for voting
        UserService.shared.addXP(HeadToHeadService.voterXP)
        
        // Fetch updated race to check if it's finished
        let updatedRaceDoc = try await racesCollection.document(raceId).getDocument()
        guard let updatedRace = Race(document: updatedRaceDoc) else {
            throw HeadToHeadError.raceNotFound
        }
        
        // Check if vote threshold reached
        if updatedRace.challengerVotes >= updatedRace.voteThreshold ||
           updatedRace.defenderVotes >= updatedRace.voteThreshold {
            try await finishRace(raceId: raceId)
        }
        
        return updatedRace
    }
    
    // MARK: - Finish Race
    
    /// End a race and distribute rewards
    func finishRace(raceId: String) async throws {
        let raceDoc = try await racesCollection.document(raceId).getDocument()
        guard let race = Race(document: raceDoc), race.status == .active else { return }
        
        // Determine winner
        let winnerId: String
        let winnerCardId: String
        let loserId: String
        
        if race.challengerVotes > race.defenderVotes {
            winnerId = race.challengerId
            winnerCardId = race.challengerCardId
            loserId = race.defenderId
        } else if race.defenderVotes > race.challengerVotes {
            winnerId = race.defenderId
            winnerCardId = race.defenderCardId
            loserId = race.challengerId
        } else {
            // Tie — no winner, small consolation to both
            try await racesCollection.document(raceId).updateData([
                "status": "finished",
                "finishedAt": Timestamp(date: Date())
            ])
            // Award consolation XP to both
            await awardTieRewards(challengerId: race.challengerId, defenderId: race.defenderId)
            await distributeVoterRewards(raceId: raceId, winnerCardId: nil)
            return
        }
        
        // Update race document
        try await racesCollection.document(raceId).updateData([
            "status": "finished",
            "finishedAt": Timestamp(date: Date()),
            "winnerId": winnerId,
            "winnerCardId": winnerCardId
        ])
        
        // Award winner
        await awardWinnerRewards(winnerId: winnerId, winnerCardId: winnerCardId)
        
        // Award loser consolation
        await awardLoserRewards(loserId: loserId)
        
        // Increment win count on the winning card
        try await incrementCardWins(cardId: winnerCardId)
        
        // Award evolution points to both cards
        let isDuo = race.isDuo
        let winnerPoints = isDuo ? RarityUpgradeConfig.duo2v2Win : RarityUpgradeConfig.solo1v1Win
        let loserPoints = isDuo ? RarityUpgradeConfig.duo2v2Loss : RarityUpgradeConfig.solo1v1Loss
        let loserCardId = (winnerId == race.challengerId) ? race.defenderCardId : race.challengerCardId
        
        try? await RarityUpgradeService.shared.awardEvolutionPoints(cardId: winnerCardId, points: winnerPoints)
        try? await RarityUpgradeService.shared.awardEvolutionPoints(cardId: loserCardId, points: loserPoints)
        
        // Distribute voter rewards (coins for correct picks + streak updates)
        await distributeVoterRewards(raceId: raceId, winnerCardId: winnerCardId)
        
        // Set cooldowns on both cards
        try await setCardCooldown(cardId: race.challengerCardId)
        try await setCardCooldown(cardId: race.defenderCardId)
        
        print("🏆 Race finished! Winner: \(winnerId)")
    }
    
    // MARK: - Rewards
    
    private func awardWinnerRewards(winnerId: String, winnerCardId: String) async {
        // Get the race to calculate pot
        // For solo: pot = entryFee * 2 (both players' fees)
        // For duo: pot is calculated across paired races
        // Winner takes the full pot
        guard let race = activeRaces.first(where: { $0.winnerId == winnerId && $0.winnerCardId == winnerCardId })
              ?? activeRaces.first(where: { $0.challengerId == winnerId || $0.defenderId == winnerId }) else {
            return
        }
        
        var pot = race.entryFee * 2  // Both challenger + defender fees
        
        // For duo races, pot includes both paired races
        if race.isDuo, let pairedId = race.pairedRaceId,
           let pairedRace = activeRaces.first(where: { $0.id == pairedId }) {
            pot = (race.entryFee + pairedRace.entryFee) * 2  // All 4 players' fees
        }
        
        // Award pot to winner (minimum winnerXP even if free race)
        if winnerId == FirebaseManager.shared.currentUserId {
            if pot > 0 { UserService.shared.addCoins(pot) }
            UserService.shared.addXP(HeadToHeadService.winnerXP)
        } else {
            var updates: [String: Any] = [
                "totalXP": FieldValue.increment(Int64(HeadToHeadService.winnerXP))
            ]
            if pot > 0 {
                updates["coins"] = FieldValue.increment(Int64(pot))
            }
            try? await db.collection("users").document(winnerId).updateData(updates)
        }
    }
    
    private func awardLoserRewards(loserId: String) async {
        if loserId == FirebaseManager.shared.currentUserId {
            UserService.shared.addXP(HeadToHeadService.loserXP)
        } else {
            try? await db.collection("users").document(loserId).updateData([
                "totalXP": FieldValue.increment(Int64(HeadToHeadService.loserXP))
            ])
        }
    }
    
    private func awardTieRewards(challengerId: String, defenderId: String) async {
        let tieXP = 15
        for userId in [challengerId, defenderId] {
            if userId == FirebaseManager.shared.currentUserId {
                UserService.shared.addXP(tieXP)
            } else {
                try? await db.collection("users").document(userId).updateData([
                    "totalXP": FieldValue.increment(Int64(tieXP))
                ])
            }
        }
    }
    
    /// Distribute coins and XP to voters who picked the winner + update streaks
    /// For duo races, checks both paired races for perfect pick bonus
    private func distributeVoterRewards(raceId: String, winnerCardId: String?) async {
        do {
            let voteDocs = try await votesCollection
                .whereField("raceId", isEqualTo: raceId)
                .getDocuments()
            
            // Check if this is a duo race and get paired race info
            let thisRace = activeRaces.first(where: { $0.id == raceId })
            var pairedWinnerCardId: String? = nil
            var pairedRaceId: String? = nil
            if let race = thisRace, race.isDuo, let pId = race.pairedRaceId {
                pairedRaceId = pId
                let pairedDoc = try? await racesCollection.document(pId).getDocument()
                if let pairedRace = pairedDoc.flatMap({ Race(document: $0) }) {
                    pairedWinnerCardId = pairedRace.winnerCardId
                }
            }
            
            for doc in voteDocs.documents {
                guard let vote = RaceVote(document: doc) else { continue }
                let isCorrect = (winnerCardId != nil && vote.votedForCardId == winnerCardId)
                
                // Update voter's streak
                await updateVoterStreak(voterId: vote.voterId, raceId: raceId, correct: isCorrect)
                
                if isCorrect {
                    // Get streak multiplier for coins
                    let streakDoc = try? await streaksCollection.document(vote.voterId).getDocument()
                    let streak = streakDoc.flatMap { VoteStreak(document: $0) } ?? VoteStreak()
                    let coins = Int(Double(HeadToHeadService.correctPickCoins) * streak.coinMultiplier)
                    
                    // Check if voter also picked correctly on paired duo race
                    var xpReward = HeadToHeadService.voterCorrectPickXP  // Solo default: 20
                    
                    if let pairedRaceId = pairedRaceId, let pairedWinner = pairedWinnerCardId {
                        // This is a duo — base reward is 15 for 1/2
                        xpReward = HeadToHeadService.voterDuoSingleXP
                        
                        // Look up this voter's vote on the paired race
                        let pairedVoteDocs = try? await votesCollection
                            .whereField("raceId", isEqualTo: pairedRaceId)
                            .whereField("voterId", isEqualTo: vote.voterId)
                            .limit(to: 1)
                            .getDocuments()
                        
                        if let pairedVote = pairedVoteDocs?.documents.first.flatMap({ RaceVote(document: $0) }),
                           pairedVote.votedForCardId == pairedWinner {
                            // Perfect duo pick — both correct!
                            xpReward = HeadToHeadService.voterDuoPerfectXP
                        }
                    }
                    
                    if vote.voterId == FirebaseManager.shared.currentUserId {
                        UserService.shared.addCoins(coins)
                        UserService.shared.addXP(xpReward)
                    } else {
                        try? await db.collection("users").document(vote.voterId).updateData([
                            "coins": FieldValue.increment(Int64(coins)),
                            "totalXP": FieldValue.increment(Int64(xpReward))
                        ])
                    }
                }
                // No XP for incorrect picks
            }
        } catch {
            print("⚠️ Failed to distribute voter rewards: \(error)")
        }
    }
    
    private func updateVoterStreak(voterId: String, raceId: String, correct: Bool) async {
        let ref = streaksCollection.document(voterId)
        
        do {
            let doc = try await ref.getDocument()
            var streak = VoteStreak(document: doc) ?? VoteStreak()
            
            if correct {
                streak.currentStreak += 1
                streak.bestStreak = max(streak.bestStreak, streak.currentStreak)
            } else {
                streak.currentStreak = 0
            }
            streak.lastVotedRaceId = raceId
            streak.lastVoteCorrect = correct
            
            try await ref.setData(streak.dictionary, merge: true)
        } catch {
            print("⚠️ Failed to update streak for \(voterId): \(error)")
        }
    }
    
    // MARK: - Card Win Counter
    
    private func incrementCardWins(cardId: String) async throws {
        // Store win record in a subcollection or field on the card
        try await db.collection("cards").document(cardId).updateData([
            "h2hWins": FieldValue.increment(Int64(1)),
            "h2hRaces": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Card Cooldown
    
    /// Check if a card is allowed to race (not on cooldown)
    func checkCardCooldown(cardId: String) async throws -> Bool {
        let doc = try await db.collection("cardCooldowns").document(cardId).getDocument()
        guard let data = doc.data(),
              let cooldownUntil = (data["cooldownUntil"] as? Timestamp)?.dateValue() else {
            return true // No cooldown record = can race
        }
        return Date() >= cooldownUntil
    }
    
    private func setCardCooldown(cardId: String) async throws {
        let cooldownUntil = Date().addingTimeInterval(Double(HeadToHeadService.cardCooldownHours * 3600))
        try await db.collection("cardCooldowns").document(cardId).setData([
            "cooldownUntil": Timestamp(date: cooldownUntil),
            "cardId": cardId
        ])
    }
    
    /// Get cooldown expiry for a card (nil = no cooldown)
    func getCooldownExpiry(cardId: String) async throws -> Date? {
        let doc = try await db.collection("cardCooldowns").document(cardId).getDocument()
        guard let data = doc.data(),
              let cooldownUntil = (data["cooldownUntil"] as? Timestamp)?.dateValue(),
              Date() < cooldownUntil else {
            return nil
        }
        return cooldownUntil
    }
    
    // MARK: - Check Expired Races
    
    /// Called periodically to finalize races whose timer has expired
    func checkExpiredRaces() async {
        let now = Timestamp(date: Date())
        
        do {
            let expiredDocs = try await racesCollection
                .whereField("status", isEqualTo: "active")
                .whereField("expiresAt", isLessThan: now)
                .limit(to: 20)
                .getDocuments()
            
            for doc in expiredDocs.documents {
                try await finishRace(raceId: doc.documentID)
            }
        } catch {
            print("⚠️ Error checking expired races: \(error)")
        }
        
        // Also clean up old finished/cancelled races
        await cleanupOldRaces()
        
        // Clean up expired duo invites
        await cleanupExpiredDuoInvites()
    }
    
    /// Delete finished/cancelled races older than 24 hours + their votes
    private func cleanupOldRaces() async {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        let cutoff = Timestamp(date: oneDayAgo)
        
        do {
            // Finished races older than 1 day
            let finishedSnap = try await racesCollection
                .whereField("status", isEqualTo: "finished")
                .whereField("createdAt", isLessThan: cutoff)
                .limit(to: 30)
                .getDocuments()
            
            // Cancelled races older than 1 day
            let cancelledSnap = try await racesCollection
                .whereField("status", isEqualTo: "cancelled")
                .whereField("createdAt", isLessThan: cutoff)
                .limit(to: 30)
                .getDocuments()
            
            // Open races older than 1 day (stale queue entries)
            let openSnap = try await racesCollection
                .whereField("status", isEqualTo: "open")
                .whereField("createdAt", isLessThan: cutoff)
                .limit(to: 30)
                .getDocuments()
            
            let allOld = finishedSnap.documents + cancelledSnap.documents + openSnap.documents
            
            guard !allOld.isEmpty else { return }
            
            for doc in allOld {
                let raceId = doc.documentID
                
                // Delete associated vote records
                let voteDocs = try await votesCollection
                    .whereField("raceId", isEqualTo: raceId)
                    .getDocuments()
                
                for voteDoc in voteDocs.documents {
                    try await voteDoc.reference.delete()
                }
                
                // Delete the race itself
                try await doc.reference.delete()
            }
            
            print("🧹 Cleaned up \(allOld.count) old race(s)")
        } catch {
            print("⚠️ Error cleaning up old races: \(error)")
        }
    }
    
    /// Clean up expired duo invites
    func cleanupExpiredDuoInvites() async {
        do {
            let expiredSnap = try await duoInvitesCollection
                .whereField("status", isEqualTo: "pending")
                .whereField("expiresAt", isLessThan: Timestamp(date: Date()))
                .getDocuments()
            
            for doc in expiredSnap.documents {
                try await doc.reference.updateData(["status": "expired"])
            }
            
            if !expiredSnap.documents.isEmpty {
                print("🧹 Expired \(expiredSnap.documents.count) duo invites")
            }
        } catch {
            print("⚠️ Error cleaning expired duo invites: \(error)")
        }
    }
    
    // MARK: - Fetch Helpers
    
    /// Get win count for a card (shown on card UI)
    func getWinCount(cardId: String) async -> Int {
        do {
            let doc = try await db.collection("cards").document(cardId).getDocument()
            return doc.data()?["h2hWins"] as? Int ?? 0
        } catch {
            return 0
        }
    }
    
    /// Get my active race count (for UI indicators)
    func getMyActiveRaceCount() -> Int {
        guard let uid = FirebaseManager.shared.currentUserId else { return 0 }
        return activeRaces.filter { $0.challengerId == uid || $0.defenderId == uid }.count
    }
    
    // MARK: - Vote History
    
    /// Fetch all races the user has voted on (to track if their picks are winning)
    func fetchVotedRaces() async throws -> [(race: Race, votedForCardId: String)] {
        guard let uid = FirebaseManager.shared.currentUserId else { return [] }
        
        // Get all votes by this user
        let voteSnap = try await votesCollection
            .whereField("voterId", isEqualTo: uid)
            .order(by: "votedAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        print("📋 Found \(voteSnap.documents.count) vote records")
        
        var results: [(race: Race, votedForCardId: String)] = []
        
        for doc in voteSnap.documents {
            guard let vote = RaceVote(document: doc) else { continue }
            
            // Fetch the race
            let raceDoc = try await racesCollection.document(vote.raceId).getDocument()
            guard let race = Race(document: raceDoc) else { continue }
            
            results.append((race: race, votedForCardId: vote.votedForCardId))
        }
        
        print("📋 Loaded \(results.count) voted races")
        return results
    }
    
    // MARK: - Duo Invites
    
    @Published var pendingDuoInvite: DuoInvite? = nil
    private var duoInviteListener: ListenerRegistration?
    
    private var duoInvitesCollection: CollectionReference {
        db.collection("duoInvites")
    }
    
    /// Send a duo invite to a teammate
    func sendDuoInvite(
        myCard: CloudCard,
        teammateId: String,
        teammateUsername: String,
        voteThreshold: Int
    ) async throws -> String {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        let inviteId = UUID().uuidString
        let data: [String: Any] = [
            "inviterId": uid,
            "inviterUsername": profile.username,
            "inviterCardId": myCard.id,
            "inviterCardMake": myCard.make,
            "inviterCardModel": myCard.model,
            "inviterCardYear": myCard.year,
            "inviterCardImageURL": myCard.flatImageURL ?? myCard.imageURL,
            "teammateId": teammateId,
            "teammateUsername": teammateUsername,
            "teammateCardId": "",
            "teammateCardImageURL": "",
            "voteThreshold": voteThreshold,
            "status": "pending",
            "createdAt": Timestamp(date: Date()),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(300))
        ]
        
        try await duoInvitesCollection.document(inviteId).setData(data)
        print("📨 Duo invite sent to \(teammateUsername)")
        return inviteId
    }
    
    /// Accept a duo invite by picking your card
    func acceptDuoInvite(inviteId: String, myCard: CloudCard) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        try await duoInvitesCollection.document(inviteId).updateData([
            "teammateCardId": myCard.id,
            "teammateCardMake": myCard.make,
            "teammateCardModel": myCard.model,
            "teammateCardYear": myCard.year,
            "teammateCardImageURL": myCard.flatImageURL ?? myCard.imageURL,
            "status": "accepted"
        ])
        
        print("✅ Duo invite accepted by \(profile.username)")
    }
    
    /// Decline a duo invite
    func declineDuoInvite(inviteId: String) async throws {
        try await duoInvitesCollection.document(inviteId).updateData([
            "status": "declined"
        ])
    }
    
    /// Listen for incoming duo invites (teammate side)
    func startDuoInviteListener() {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        duoInviteListener = duoInvitesCollection
            .whereField("teammateId", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Duo invite listener error: \(error)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                
                Task { @MainActor in
                    let invites = docs.compactMap { DuoInvite(document: $0) }
                        .filter { $0.expiresAt > Date() }
                        .sorted { $0.createdAt > $1.createdAt }
                    
                    self?.pendingDuoInvite = invites.first
                }
            }
    }
    
    func stopDuoInviteListener() {
        duoInviteListener?.remove()
        duoInviteListener = nil
    }
}

// MARK: - XP Helper on UserService

extension UserService {
    func addXP(_ amount: Int) {
        guard let uid = currentProfile?.id else { return }
        
        currentProfile?.totalXP += amount
        currentProfile?.currentXP += amount
        
        Task {
            try? await FirebaseManager.shared.db.collection("users").document(uid).updateData([
                "totalXP": FieldValue.increment(Int64(amount)),
                "currentXP": FieldValue.increment(Int64(amount))
            ])
        }
    }
}

// MARK: - Duo Invite Model

struct DuoInvite: Identifiable {
    var id: String
    var inviterId: String
    var inviterUsername: String
    var inviterCardId: String
    var inviterCardMake: String
    var inviterCardModel: String
    var inviterCardYear: String
    var inviterCardImageURL: String
    var teammateId: String
    var teammateUsername: String
    var teammateCardId: String
    var teammateCardMake: String
    var teammateCardModel: String
    var teammateCardYear: String
    var teammateCardImageURL: String
    var voteThreshold: Int
    var status: String
    var createdAt: Date
    var expiresAt: Date
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.inviterId = data["inviterId"] as? String ?? ""
        self.inviterUsername = data["inviterUsername"] as? String ?? ""
        self.inviterCardId = data["inviterCardId"] as? String ?? ""
        self.inviterCardMake = data["inviterCardMake"] as? String ?? ""
        self.inviterCardModel = data["inviterCardModel"] as? String ?? ""
        self.inviterCardYear = data["inviterCardYear"] as? String ?? ""
        self.inviterCardImageURL = data["inviterCardImageURL"] as? String ?? ""
        self.teammateId = data["teammateId"] as? String ?? ""
        self.teammateUsername = data["teammateUsername"] as? String ?? ""
        self.teammateCardId = data["teammateCardId"] as? String ?? ""
        self.teammateCardMake = data["teammateCardMake"] as? String ?? ""
        self.teammateCardModel = data["teammateCardModel"] as? String ?? ""
        self.teammateCardYear = data["teammateCardYear"] as? String ?? ""
        self.teammateCardImageURL = data["teammateCardImageURL"] as? String ?? ""
        self.voteThreshold = data["voteThreshold"] as? Int ?? 50
        self.status = data["status"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date()
    }
}

enum HeadToHeadError: LocalizedError {
    case cardOnCooldown
    case cardAlreadyInRace
    case raceNotFound
    case alreadyVoted
    case raceNotActive
    case cannotVoteOwnRace
    case insufficientCoins
    
    var errorDescription: String? {
        switch self {
        case .cardOnCooldown: return "This card is on cooldown. Try again later."
        case .cardAlreadyInRace: return "This card is already in an active race."
        case .raceNotFound: return "Race not found."
        case .alreadyVoted: return "You already voted on this race."
        case .raceNotActive: return "This race is no longer active."
        case .cannotVoteOwnRace: return "You can't vote on your own race."
        case .insufficientCoins: return "Not enough coins to enter this race."
        }
    }
}
