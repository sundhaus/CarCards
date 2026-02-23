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
    
    enum RaceStatus: String, Codable {
        case pending    // Awaiting defender acceptance
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
    var raceid: String
    var oddsLocked: Bool
    var voterId: String
    var votedForCardId: String  // Which card the user picked
    var votedAt: Date
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.raceid = data["raceId"] as? String ?? ""
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
    @Published var myPendingChallenges: [Race] = []   // Challenges sent to me awaiting accept
    @Published var mySentChallenges: [Race] = []      // Challenges I sent awaiting accept
    @Published var currentFeedRace: Race?             // The race currently shown in the feed
    @Published var myStreak: VoteStreak = VoteStreak()
    @Published var isLoading = false
    
    private let db = FirebaseManager.shared.db
    private var racesListener: ListenerRegistration?
    private var pendingListener: ListenerRegistration?
    private var streakListener: ListenerRegistration?
    
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
    static let voterXP = 5                   // XP per vote
    static let winnerCoins = 50              // Coins for race winner
    static let winnerXP = 25                 // XP for race winner
    static let loserXP = 10                  // Consolation XP for loser
    static let correctPickCoins = 10         // Base coins for picking winner
    static let cardCooldownHours = 24        // Hours before a card can race again
    
    // MARK: - Listeners
    
    func startListening() {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        // Listen for active races (for voting feed)
        racesListener = racesCollection
            .whereField("status", isEqualTo: "active")
            .order(by: "startedAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.activeRaces = docs.compactMap { Race(document: $0) }
                    // Auto-load next race if feed is empty
                    if self?.currentFeedRace == nil {
                        self?.loadNextFeedRace()
                    }
                }
            }
        
        // Listen for challenges sent to me
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
    
    /// Load the next race the user hasn't voted on
    func loadNextFeedRace() {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        // Filter: active races I haven't voted on and I'm not a participant in
        let available = activeRaces.filter { race in
            !race.voters.contains(uid) &&
            race.challengerId != uid &&
            race.defenderId != uid
        }
        
        // Pick a random one for variety
        currentFeedRace = available.randomElement()
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
        
        // Distribute voter rewards (coins for correct picks + streak updates)
        await distributeVoterRewards(raceId: raceId, winnerCardId: winnerCardId)
        
        // Set cooldowns on both cards
        try await setCardCooldown(cardId: race.challengerCardId)
        try await setCardCooldown(cardId: race.defenderCardId)
        
        print("🏆 Race finished! Winner: \(winnerId)")
    }
    
    // MARK: - Rewards
    
    private func awardWinnerRewards(winnerId: String, winnerCardId: String) async {
        // Coins + XP to winner
        if winnerId == FirebaseManager.shared.currentUserId {
            UserService.shared.addCoins(HeadToHeadService.winnerCoins)
            UserService.shared.addXP(HeadToHeadService.winnerXP)
        } else {
            // Remote user — update their doc directly
            try? await db.collection("users").document(winnerId).updateData([
                "coins": FieldValue.increment(Int64(HeadToHeadService.winnerCoins)),
                "totalXP": FieldValue.increment(Int64(HeadToHeadService.winnerXP))
            ])
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
    
    /// Distribute coins to voters who picked the winner + update streaks
    private func distributeVoterRewards(raceId: String, winnerCardId: String?) async {
        do {
            let voteDocs = try await votesCollection
                .whereField("raceId", isEqualTo: raceId)
                .getDocuments()
            
            for doc in voteDocs.documents {
                guard let vote = RaceVote(document: doc) else { continue }
                let isCorrect = (winnerCardId != nil && vote.votedForCardId == winnerCardId)
                
                // Update voter's streak
                await updateVoterStreak(voterId: vote.voterId, raceId: raceId, correct: isCorrect)
                
                // Award coins if correct
                if isCorrect {
                    // Get streak multiplier
                    let streakDoc = try? await streaksCollection.document(vote.voterId).getDocument()
                    let streak = streakDoc.flatMap { VoteStreak(document: $0) } ?? VoteStreak()
                    let coins = Int(Double(HeadToHeadService.correctPickCoins) * streak.coinMultiplier)
                    
                    if vote.voterId == FirebaseManager.shared.currentUserId {
                        UserService.shared.addCoins(coins)
                    } else {
                        try? await db.collection("users").document(vote.voterId).updateData([
                            "coins": FieldValue.increment(Int64(coins))
                        ])
                    }
                }
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

// MARK: - Errors

enum HeadToHeadError: LocalizedError {
    case cardOnCooldown
    case raceNotFound
    case alreadyVoted
    case raceNotActive
    case cannotVoteOwnRace
    
    var errorDescription: String? {
        switch self {
        case .cardOnCooldown: return "This card is on cooldown. Try again later."
        case .raceNotFound: return "Race not found."
        case .alreadyVoted: return "You already voted on this race."
        case .raceNotActive: return "This race is no longer active."
        case .cannotVoteOwnRace: return "You can't vote on your own race."
        }
    }
}
