//
//  BattleModels.swift
//  CarCardCollector
//
//  Data models for the stat-based battle system.
//  Covers: match types, battle state, ranked ladder, match history, rewards.
//
//  Battle flow (Top Trumps):
//    1. Player creates/joins a battle (casual or ranked)
//    2. Both players pick a card from their hand
//    3. Attacker chooses a stat category
//    4. Higher stat wins the round
//    5. Best of N rounds wins the match
//
//  Battle flow (Draft Battle):
//    1. Each player selects 5 cards from their garage
//    2. Players alternate: attacker picks category, both reveal cards
//    3. Winner of each round scores a point
//    4. Best of 5 wins
//

import Foundation
import FirebaseFirestore

// MARK: - Battle Mode

enum BattleMode: String, Codable, CaseIterable {
    case topTrumps    = "Top Trumps"       // Quick 1v1 single card, pick a stat
    case draftBattle  = "Draft Battle"     // Best of 5 with hand selection
    case classBattle  = "Class Battle"     // Both must use same vehicle category
    case budgetBattle = "Budget Battle"    // Coin-limited hand building
    
    var icon: String {
        switch self {
        case .topTrumps:    return "bolt.circle.fill"
        case .draftBattle:  return "rectangle.stack.fill"
        case .classBattle:  return "car.2.fill"
        case .budgetBattle: return "dollarsign.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .topTrumps:    return "Pick a card, pick a stat. Highest wins."
        case .draftBattle:  return "Build a 5-card hand. Best of 5 rounds."
        case .classBattle:  return "Same car class. Who has the best?"
        case .budgetBattle: return "Limited budget. Choose wisely."
        }
    }
    
    var roundCount: Int {
        switch self {
        case .topTrumps:    return 1
        case .draftBattle:  return 5
        case .classBattle:  return 3
        case .budgetBattle: return 5
        }
    }
    
    var handSize: Int {
        switch self {
        case .topTrumps:    return 1
        case .draftBattle:  return 5
        case .classBattle:  return 3
        case .budgetBattle: return 5
        }
    }
    
    /// Minimum level to unlock this battle mode
    var requiredLevel: Int {
        switch self {
        case .topTrumps:    return 1
        case .draftBattle:  return 5
        case .classBattle:  return 8
        case .budgetBattle: return 10
        }
    }
}

// MARK: - Queue Type

enum BattleQueueType: String, Codable {
    case casual = "casual"
    case ranked = "ranked"
}

// MARK: - Battle Status

enum BattleStatus: String, Codable {
    case searching       // In matchmaking queue
    case handSelection   // Both players selecting cards
    case inProgress      // Rounds being played
    case waitingForMove  // Waiting for opponent's move (async)
    case finished        // Battle complete
    case abandoned       // Player disconnected / timed out
    case cancelled       // Cancelled before start
}

// MARK: - Round Result

struct BattleRound: Codable, Identifiable {
    var id: Int  // Round number (1-based)
    var attackerId: String          // Who picked the category
    var categoryChosen: String      // BattleCategory rawValue
    var player1CardId: String
    var player1StatValue: Int
    var player2CardId: String
    var player2StatValue: Int
    var winnerId: String?           // nil = tie
    var completedAt: Date?
    
    var category: BattleCategory? {
        BattleCategory(rawValue: categoryChosen)
    }
}

// MARK: - Player Battle State

/// One player's state within a battle
struct BattlePlayer: Codable {
    var userId: String
    var username: String
    var level: Int
    var rankPoints: Int
    var handCardIds: [String]       // Card IDs selected for this battle
    var currentCardId: String?      // Card played this round
    var score: Int                  // Rounds won
    var isReady: Bool               // Has selected their hand
    
    init(userId: String, username: String, level: Int, rankPoints: Int = 0) {
        self.userId = userId
        self.username = username
        self.level = level
        self.rankPoints = rankPoints
        self.handCardIds = []
        self.currentCardId = nil
        self.score = 0
        self.isReady = false
    }
    
    var toDictionary: [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "username": username,
            "level": level,
            "rankPoints": rankPoints,
            "handCardIds": handCardIds,
            "score": score,
            "isReady": isReady
        ]
        if let cardId = currentCardId {
            dict["currentCardId"] = cardId
        }
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> BattlePlayer? {
        guard let userId = dict["userId"] as? String,
              let username = dict["username"] as? String else { return nil }
        
        var player = BattlePlayer(
            userId: userId,
            username: username,
            level: dict["level"] as? Int ?? 1,
            rankPoints: dict["rankPoints"] as? Int ?? 0
        )
        player.handCardIds = dict["handCardIds"] as? [String] ?? []
        player.currentCardId = dict["currentCardId"] as? String
        player.score = dict["score"] as? Int ?? 0
        player.isReady = dict["isReady"] as? Bool ?? false
        return player
    }
}

// MARK: - Battle Match (Firestore document)

struct BattleMatch: Identifiable {
    var id: String                  // Firestore document ID
    var mode: BattleMode
    var queueType: BattleQueueType
    var status: BattleStatus
    var player1: BattlePlayer
    var player2: BattlePlayer?
    var rounds: [BattleRound]
    var currentRound: Int           // 1-based
    var currentAttackerId: String   // Who picks category this round
    var winnerId: String?
    var createdAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var turnDeadline: Date?         // Async: when the current turn expires
    var classBattleCategory: String? // For Class Battle mode
    var budgetLimit: Int?           // For Budget Battle mode
    
    // Synergy info (stored after hand selection)
    var player1Synergies: [String]? // SynergyType rawValues
    var player2Synergies: [String]?
    
    // Pending round data (attacker's move before defender responds)
    var pendingRound: [String: Any]?
    
    // MARK: - Firestore Init
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.mode = BattleMode(rawValue: data["mode"] as? String ?? "") ?? .topTrumps
        self.queueType = BattleQueueType(rawValue: data["queueType"] as? String ?? "casual") ?? .casual
        self.status = BattleStatus(rawValue: data["status"] as? String ?? "") ?? .searching
        
        guard let p1Data = data["player1"] as? [String: Any],
              let p1 = BattlePlayer.fromDictionary(p1Data) else { return nil }
        self.player1 = p1
        
        if let p2Data = data["player2"] as? [String: Any] {
            self.player2 = BattlePlayer.fromDictionary(p2Data)
        }
        
        // Parse rounds
        if let roundsData = data["rounds"] as? [[String: Any]] {
            self.rounds = roundsData.enumerated().compactMap { index, rd in
                BattleRound(
                    id: rd["id"] as? Int ?? (index + 1),
                    attackerId: rd["attackerId"] as? String ?? "",
                    categoryChosen: rd["categoryChosen"] as? String ?? "",
                    player1CardId: rd["player1CardId"] as? String ?? "",
                    player1StatValue: rd["player1StatValue"] as? Int ?? 0,
                    player2CardId: rd["player2CardId"] as? String ?? "",
                    player2StatValue: rd["player2StatValue"] as? Int ?? 0,
                    winnerId: rd["winnerId"] as? String,
                    completedAt: (rd["completedAt"] as? Timestamp)?.dateValue()
                )
            }
        } else {
            self.rounds = []
        }
        
        self.currentRound = data["currentRound"] as? Int ?? 1
        self.currentAttackerId = data["currentAttackerId"] as? String ?? p1.userId
        self.winnerId = data["winnerId"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.startedAt = (data["startedAt"] as? Timestamp)?.dateValue()
        self.finishedAt = (data["finishedAt"] as? Timestamp)?.dateValue()
        self.turnDeadline = (data["turnDeadline"] as? Timestamp)?.dateValue()
        self.classBattleCategory = data["classBattleCategory"] as? String
        self.budgetLimit = data["budgetLimit"] as? Int
        self.player1Synergies = data["player1Synergies"] as? [String]
        self.player2Synergies = data["player2Synergies"] as? [String]
        self.pendingRound = data["pendingRound"] as? [String: Any]
    }
    
    // MARK: - Programmatic Init (for creating new battles)
    
    init(
        id: String,
        mode: BattleMode,
        queueType: BattleQueueType,
        player1: BattlePlayer,
        classBattleCategory: String? = nil,
        budgetLimit: Int? = nil
    ) {
        self.id = id
        self.mode = mode
        self.queueType = queueType
        self.status = .searching
        self.player1 = player1
        self.player2 = nil
        self.rounds = []
        self.currentRound = 1
        self.currentAttackerId = player1.userId
        self.winnerId = nil
        self.createdAt = Date()
        self.startedAt = nil
        self.finishedAt = nil
        self.turnDeadline = nil
        self.classBattleCategory = classBattleCategory
        self.budgetLimit = budgetLimit
        self.player1Synergies = nil
        self.player2Synergies = nil
        self.pendingRound = nil
    }
    
    // MARK: - Computed Properties
    
    /// Check if it's a specific player's turn to act
    func isPlayerTurn(_ userId: String) -> Bool {
        guard status == .inProgress || status == .waitingForMove else { return false }
        return currentAttackerId == userId
    }
    
    /// Get the opponent of a specific player
    func opponent(of userId: String) -> BattlePlayer? {
        if player1.userId == userId { return player2 }
        if player2?.userId == userId { return player1 }
        return nil
    }
    
    /// Get the player object for a specific user
    func player(for userId: String) -> BattlePlayer? {
        if player1.userId == userId { return player1 }
        if player2?.userId == userId { return player2 }
        return nil
    }
    
    // MARK: - Dictionary
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "mode": mode.rawValue,
            "queueType": queueType.rawValue,
            "status": status.rawValue,
            "player1": player1.toDictionary,
            "currentRound": currentRound,
            "currentAttackerId": currentAttackerId,
            "createdAt": Timestamp(date: createdAt),
            // Denormalized fields for matchmaking queries
            "player1Id": player1.userId,
            "player1RankPoints": player1.rankPoints,
            "player1Level": player1.level
        ]
        
        if let p2 = player2 {
            dict["player2"] = p2.toDictionary
            dict["player2Id"] = p2.userId
        }
        
        if !rounds.isEmpty {
            dict["rounds"] = rounds.map { round in
                var rd: [String: Any] = [
                    "id": round.id,
                    "attackerId": round.attackerId,
                    "categoryChosen": round.categoryChosen,
                    "player1CardId": round.player1CardId,
                    "player1StatValue": round.player1StatValue,
                    "player2CardId": round.player2CardId,
                    "player2StatValue": round.player2StatValue
                ]
                if let winner = round.winnerId { rd["winnerId"] = winner }
                if let completed = round.completedAt { rd["completedAt"] = Timestamp(date: completed) }
                return rd
            }
        }
        
        if let winner = winnerId { dict["winnerId"] = winner }
        if let started = startedAt { dict["startedAt"] = Timestamp(date: started) }
        if let finished = finishedAt { dict["finishedAt"] = Timestamp(date: finished) }
        if let deadline = turnDeadline { dict["turnDeadline"] = Timestamp(date: deadline) }
        if let cat = classBattleCategory { dict["classBattleCategory"] = cat }
        if let budget = budgetLimit { dict["budgetLimit"] = budget }
        if let s1 = player1Synergies { dict["player1Synergies"] = s1 }
        if let s2 = player2Synergies { dict["player2Synergies"] = s2 }
        
        return dict
    }
}

// MARK: - Ranked Ladder

/// Rank tiers for the competitive ladder
enum BattleRank: String, Codable, CaseIterable {
    case bronze1   = "Bronze I"
    case bronze2   = "Bronze II"
    case bronze3   = "Bronze III"
    case silver1   = "Silver I"
    case silver2   = "Silver II"
    case silver3   = "Silver III"
    case gold1     = "Gold I"
    case gold2     = "Gold II"
    case gold3     = "Gold III"
    case platinum1 = "Platinum I"
    case platinum2 = "Platinum II"
    case platinum3 = "Platinum III"
    case diamond   = "Diamond"
    case champion  = "Champion"
    
    var tier: String {
        if rawValue.contains("Bronze") { return "Bronze" }
        if rawValue.contains("Silver") { return "Silver" }
        if rawValue.contains("Gold") { return "Gold" }
        if rawValue.contains("Platinum") { return "Platinum" }
        if rawValue.contains("Diamond") { return "Diamond" }
        return "Champion"
    }
    
    var icon: String {
        switch tier {
        case "Bronze":   return "shield.fill"
        case "Silver":   return "shield.lefthalf.filled"
        case "Gold":     return "star.circle.fill"
        case "Platinum": return "crown.fill"
        case "Diamond":  return "diamond.fill"
        default:         return "trophy.fill"
        }
    }
    
    /// Minimum rank points for this rank
    var minPoints: Int {
        switch self {
        case .bronze1:   return 0
        case .bronze2:   return 100
        case .bronze3:   return 200
        case .silver1:   return 350
        case .silver2:   return 500
        case .silver3:   return 700
        case .gold1:     return 950
        case .gold2:     return 1200
        case .gold3:     return 1500
        case .platinum1: return 1850
        case .platinum2: return 2200
        case .platinum3: return 2600
        case .diamond:   return 3100
        case .champion:  return 4000
        }
    }
    
    /// Determine rank from points
    static func from(points: Int) -> BattleRank {
        let sorted = allCases.reversed()
        return sorted.first(where: { points >= $0.minPoints }) ?? .bronze1
    }
    
    /// Points earned for a win at this rank level
    var winPoints: Int {
        switch tier {
        case "Bronze":   return 30
        case "Silver":   return 25
        case "Gold":     return 22
        case "Platinum": return 18
        case "Diamond":  return 15
        default:         return 12
        }
    }
    
    /// Points lost for a loss at this rank level
    var lossPoints: Int {
        switch tier {
        case "Bronze":   return 10
        case "Silver":   return 15
        case "Gold":     return 18
        case "Platinum": return 20
        case "Diamond":  return 22
        default:         return 25
        }
    }
}

// MARK: - Battle Result (for history)

struct BattleResult: Identifiable, Codable {
    var id: String
    var matchId: String
    var mode: String
    var queueType: String
    var opponentId: String
    var opponentUsername: String
    var won: Bool
    var myScore: Int
    var opponentScore: Int
    var rankPointsChange: Int   // Can be negative
    var coinsEarned: Int
    var xpEarned: Int
    var completedAt: Date
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.matchId = data["matchId"] as? String ?? ""
        self.mode = data["mode"] as? String ?? ""
        self.queueType = data["queueType"] as? String ?? ""
        self.opponentId = data["opponentId"] as? String ?? ""
        self.opponentUsername = data["opponentUsername"] as? String ?? ""
        self.won = data["won"] as? Bool ?? false
        self.myScore = data["myScore"] as? Int ?? 0
        self.opponentScore = data["opponentScore"] as? Int ?? 0
        self.rankPointsChange = data["rankPointsChange"] as? Int ?? 0
        self.coinsEarned = data["coinsEarned"] as? Int ?? 0
        self.xpEarned = data["xpEarned"] as? Int ?? 0
        self.completedAt = (data["completedAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    var dictionary: [String: Any] {
        [
            "matchId": matchId,
            "mode": mode,
            "queueType": queueType,
            "opponentId": opponentId,
            "opponentUsername": opponentUsername,
            "won": won,
            "myScore": myScore,
            "opponentScore": opponentScore,
            "rankPointsChange": rankPointsChange,
            "coinsEarned": coinsEarned,
            "xpEarned": xpEarned,
            "completedAt": Timestamp(date: completedAt)
        ]
    }
}

// MARK: - Battle Rewards Config

struct BattleRewards {
    
    /// Calculate rewards for a battle result
    static func calculate(won: Bool, mode: BattleMode, queueType: BattleQueueType, currentRank: BattleRank) -> (coins: Int, xp: Int, rankChange: Int) {
        
        let baseCoins: Int
        let baseXP: Int
        
        switch mode {
        case .topTrumps:    baseCoins = 25;  baseXP = 50
        case .draftBattle:  baseCoins = 75;  baseXP = 150
        case .classBattle:  baseCoins = 50;  baseXP = 100
        case .budgetBattle: baseCoins = 60;  baseXP = 120
        }
        
        let rankChange: Int
        if queueType == .ranked {
            rankChange = won ? currentRank.winPoints : -currentRank.lossPoints
        } else {
            rankChange = 0
        }
        
        if won {
            let multiplier = queueType == .ranked ? 1.5 : 1.0
            return (
                coins: Int(Double(baseCoins) * multiplier),
                xp: Int(Double(baseXP) * multiplier),
                rankChange: rankChange
            )
        } else {
            // Losers still get some coins/XP for participating
            return (
                coins: baseCoins / 4,
                xp: baseXP / 3,
                rankChange: rankChange
            )
        }
    }
}

// MARK: - Async Turn Timer

/// Configuration for async turn timing
struct AsyncTurnConfig {
    /// How long a player has to make their move before auto-forfeit
    static let turnTimeoutSeconds: TimeInterval = 24 * 60 * 60  // 24 hours
    
    /// Grace period after timeout before auto-forfeit (for push notification delay)
    static let graceSeconds: TimeInterval = 30 * 60  // 30 minutes
    
    /// How long to wait in matchmaking before giving up
    static let matchmakingTimeoutSeconds: TimeInterval = 5 * 60  // 5 minutes (for active search)
}
