///
//  FriendsService.swift
//  CarCardCollector
//
//  Manages follows and friend activity feed via Firestore
//  Follow-based system: follow anyone, friends = mutual follows
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// Follow relationship model
struct Follow: Identifiable {
    var id: String
    var followerId: String   // User who is following
    var followingId: String  // User being followed
    var createdAt: Date
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.followerId = data["followerId"] as? String ?? ""
        self.followingId = data["followingId"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    var dictionary: [String: Any] {
        return [
            "followerId": followerId,
            "followingId": followingId,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

// Friend activity (card additions)
struct FriendActivity: Identifiable {
    var id: String
    var userId: String
    var username: String
    var level: Int
    var cardId: String
    var cardMake: String
    var cardModel: String
    var cardYear: String
    var imageURL: String
    var createdAt: Date
    var heatedBy: [String]
    var heatCount: Int
    var customFrame: String?
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.username = data["username"] as? String ?? ""
        self.level = data["level"] as? Int ?? 1
        self.cardId = data["cardId"] as? String ?? ""
        self.cardMake = data["cardMake"] as? String ?? ""
        self.cardModel = data["cardModel"] as? String ?? ""
        self.cardYear = data["cardYear"] as? String ?? ""
        self.imageURL = data["imageURL"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.heatedBy = data["heatedBy"] as? [String] ?? []
        self.heatCount = data["heatCount"] as? Int ?? 0
        self.customFrame = data["customFrame"] as? String
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "username": username,
            "level": level,
            "cardId": cardId,
            "cardMake": cardMake,
            "cardModel": cardModel,
            "cardYear": cardYear,
            "imageURL": imageURL,
            "createdAt": Timestamp(date: createdAt),
            "heatedBy": heatedBy,
            "heatCount": heatCount
        ]
        
        if let customFrame = customFrame {
            dict["customFrame"] = customFrame
        }
        
        return dict
    }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 {
            return days == 1 ? "1d ago" : "\(days)d ago"
        } else if hours > 0 {
            return hours == 1 ? "1h ago" : "\(hours)h ago"
        } else if minutes > 0 {
            return minutes == 1 ? "1m ago" : "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// Friend profile (extended from UserProfile)
struct FriendProfile: Identifiable {
    var id: String
    var username: String
    var level: Int
    var totalCards: Int
    var profilePictureURL: String?
    var isFriend: Bool = false        // Mutual follow
    var isFollowing: Bool = false     // I follow them
    var followsMe: Bool = false       // They follow me
    var followedAt: Date?             // When they started following me (for new follower notifications)
    
    init(uid: String, username: String, level: Int, totalCards: Int, profilePictureURL: String? = nil) {
        self.id = uid
        self.username = username
        self.level = level
        self.totalCards = totalCards
        self.profilePictureURL = profilePictureURL
    }
    
    init(profile: UserProfile) {
        self.id = profile.id
        self.username = profile.username
        self.level = profile.level
        self.totalCards = profile.totalCardsCollected
        self.profilePictureURL = profile.profilePictureURL
    }
    
    var isNewFollower: Bool {
        guard let followedAt = followedAt,
              let lastViewed = UserDefaults.standard.object(forKey: "lastViewedFollowersAt") as? Date else {
            return false
        }
        return followedAt > lastViewed
    }
}

@MainActor
class FriendsService: ObservableObject {
    static let shared = FriendsService()
    
    @Published var friends: [FriendProfile] = []          // Mutual follows
    @Published var following: [FriendProfile] = []        // People I follow
    @Published var followers: [FriendProfile] = []        // People who follow me
    @Published var friendActivities: [FriendActivity] = []
    @Published var newFollowersCount: Int = 0
    @Published var isLoading = false
    
    private let db = FirebaseManager.shared.db
    private var followsListener: ListenerRegistration?
    private var activitiesListener: ListenerRegistration?
    
    private var followsCollection: CollectionReference {
        db.collection("follows")
    }
    
    private var activitiesCollection: CollectionReference {
        db.collection("friend_activities")
    }
    
    private init() {}
    
    deinit {
        followsListener?.remove()
        activitiesListener?.remove()
    }
    
    // MARK: - Follow User
    
    func followUser(userId: String) async throws {
        guard let myUid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        // Can't follow yourself
        guard userId != myUid else {
            throw FriendsServiceError.cannotFollowSelf
        }
        
        // Check if already following
        let existing = try await followsCollection
            .whereField("followerId", isEqualTo: myUid)
            .whereField("followingId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        
        if !existing.documents.isEmpty {
            throw FriendsServiceError.alreadyFollowing
        }
        
        // Create follow relationship
        let followId = UUID().uuidString
        let data: [String: Any] = [
            "followerId": myUid,
            "followingId": userId,
            "createdAt": Timestamp(date: Date())
        ]
        
        try await followsCollection.document(followId).setData(data)
        
        print("Ã¢Å“â€¦ Now following user: \(userId)")
        
        // Backfill their recent cards (last 30 days) to activity feed
        await backfillRecentCards(for: userId)
    }
    
    // MARK: - Backfill Recent Cards (when following someone new)
    
    private func backfillRecentCards(for userId: String) async {
        do {
            // Get user's profile for username/level
            guard let profile = try await UserService.shared.fetchProfile(uid: userId) else {
                print("Ã¢Å¡Â Ã¯Â¸Â Cannot backfill - profile not found for \(userId)")
                return
            }
            
            // Get cards added in last 30 days
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            let cardsSnapshot = try await db.collection("cards")
                .whereField("ownerId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThan: Timestamp(date: thirtyDaysAgo))
                .order(by: "createdAt", descending: true)
                .limit(to: 20) // Limit to 20 most recent
                .getDocuments()
            
            let cards = cardsSnapshot.documents.compactMap { CloudCard(document: $0) }
            
            print("Ã°Å¸â€œÅ  Backfilling \(cards.count) recent cards from \(profile.username)")
            
            // Create activity entries for each recent card
            for card in cards {
                // Check if activity already exists
                let existingActivity = try await activitiesCollection
                    .whereField("userId", isEqualTo: userId)
                    .whereField("cardId", isEqualTo: card.id)
                    .limit(to: 1)
                    .getDocuments()
                
                if existingActivity.documents.isEmpty {
                    // Create new activity
                    let activityId = UUID().uuidString
                    let activityData: [String: Any] = [
                        "userId": userId,
                        "username": profile.username,
                        "level": profile.level,
                        "cardId": card.id,
                        "cardMake": card.make,
                        "cardModel": card.model,
                        "cardYear": card.year,
                        "imageURL": card.imageURL,
                        "createdAt": Timestamp(date: card.createdAt)
                    ]
                    
                    try await activitiesCollection.document(activityId).setData(activityData)
                }
            }
            
            print("Ã¢Å“â€¦ Backfilled \(cards.count) activities for \(profile.username)")
            
        } catch {
            print("Ã¢Å¡Â Ã¯Â¸Â Backfill failed (non-critical): \(error)")
        }
    }
    
    // MARK: - Unfollow User
    
    func unfollowUser(userId: String) async throws {
        guard let myUid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        let snapshot = try await followsCollection
            .whereField("followerId", isEqualTo: myUid)
            .whereField("followingId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else {
            return
        }
        
        try await followsCollection.document(doc.documentID).delete()
        
        print("Ã¢Å“â€¦ Unfollowed user: \(userId)")
    }
    
    // MARK: - Search Users (Case-Insensitive)
    
    func searchUsers(query: String) async throws -> [FriendProfile] {
        guard !query.isEmpty else { return [] }
        
        // Get all users and filter client-side for case-insensitive search
        let snapshot = try await db.collection("users")
            .limit(to: 100)
            .getDocuments()
        
        let lowercaseQuery = query.lowercased()
        
        var results: [FriendProfile] = []
        for doc in snapshot.documents {
            if let profile = UserProfile(document: doc) {
                if profile.username.lowercased().contains(lowercaseQuery) {
                    var friendProfile = FriendProfile(profile: profile)
                    
                    // Check follow status
                    if FirebaseManager.shared.currentUserId != nil {
                        friendProfile.isFollowing = try await checkIfFollowing(userId: profile.id)
                        friendProfile.followsMe = try await checkIfFollowsMe(userId: profile.id)
                        friendProfile.isFriend = friendProfile.isFollowing && friendProfile.followsMe
                    }
                    
                    results.append(friendProfile)
                }
            }
        }
        
        return results.sorted { $0.username.lowercased() < $1.username.lowercased() }
    }
    
    // MARK: - Check Follow Status
    
    func checkIfFollowing(userId: String) async throws -> Bool {
        guard let myUid = FirebaseManager.shared.currentUserId else {
            return false
        }
        
        let snapshot = try await followsCollection
            .whereField("followerId", isEqualTo: myUid)
            .whereField("followingId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    func checkIfFollowsMe(userId: String) async throws -> Bool {
        guard let myUid = FirebaseManager.shared.currentUserId else {
            return false
        }
        
        let snapshot = try await followsCollection
            .whereField("followerId", isEqualTo: userId)
            .whereField("followingId", isEqualTo: myUid)
            .limit(to: 1)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    // MARK: - Listen to Follows
    
    func listenToFollows(uid: String) {
        followsListener?.remove()
        isLoading = true
        
        // Listen to all follows (both following and followers)
        followsListener = followsCollection
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Ã¢ÂÅ’ Follows listener error: \(error)")
                    Task { @MainActor in self?.isLoading = false }
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor [weak self] in
                    let follows = documents.compactMap { Follow(document: $0) }
                    
                    // People I follow
                    let followingIds = follows
                        .filter { $0.followerId == uid }
                        .map { $0.followingId }
                    
                    // People who follow me (with timestamps)
                    let followerData = follows
                        .filter { $0.followingId == uid }
                        .map { (userId: $0.followerId, followedAt: $0.createdAt) }
                    
                    let followerIds = followerData.map { $0.userId }
                    
                    // Friends = mutual follows
                    let friendIds = followingIds.filter { followerIds.contains($0) }
                    
                    await self?.fetchProfiles(
                        friendIds: friendIds,
                        followingIds: followingIds,
                        followerData: followerData
                    )
                }
            }
    }
    
    private func fetchProfiles(friendIds: [String], followingIds: [String], followerData: [(userId: String, followedAt: Date)]) async {
        let followerIds = followerData.map { $0.userId }
        
        // Combine all unique IDs
        let allIds = Set(friendIds + followingIds + followerIds)
        
        guard !allIds.isEmpty else {
            self.friends = []
            self.following = []
            self.followers = []
            self.isLoading = false
            self.newFollowersCount = 0
            return
        }
        
        var profiles: [String: FriendProfile] = [:]
        let followerTimestamps = Dictionary(uniqueKeysWithValues: followerData.map { ($0.userId, $0.followedAt) })
        
        for uid in allIds {
            do {
                if let profile = try await UserService.shared.fetchProfile(uid: uid) {
                    var friendProfile = FriendProfile(profile: profile)
                    friendProfile.isFollowing = followingIds.contains(uid)
                    friendProfile.followsMe = followerIds.contains(uid)
                    friendProfile.isFriend = friendIds.contains(uid)
                    friendProfile.followedAt = followerTimestamps[uid]
                    
                    profiles[uid] = friendProfile
                }
            } catch {
                print("Ã¢Å¡Â Ã¯Â¸Â Failed to fetch profile for \(uid): \(error)")
            }
        }
        
        // Update published properties
        self.friends = friendIds.compactMap { profiles[$0] }.sorted { $0.username < $1.username }
        self.following = followingIds.compactMap { profiles[$0] }.sorted { $0.username < $1.username }
        
        // Sort followers: new ones first, then alphabetically
        let allFollowers = followerIds.compactMap { profiles[$0] }
        self.followers = allFollowers.sorted { follower1, follower2 in
            let isNew1 = follower1.isNewFollower
            let isNew2 = follower2.isNewFollower
            
            if isNew1 && !isNew2 {
                return true  // New followers first
            } else if !isNew1 && isNew2 {
                return false
            } else {
                // Both new or both old: sort by followedAt (most recent first) or username
                if let date1 = follower1.followedAt, let date2 = follower2.followedAt {
                    return date1 > date2
                }
                return follower1.username < follower2.username
            }
        }
        
        // Calculate new followers count
        self.newFollowersCount = allFollowers.filter { $0.isNewFollower }.count
        
        self.isLoading = false
        
        print("Ã¢Å“â€¦ Friends: \(friends.count), Following: \(following.count), Followers: \(followers.count), New: \(newFollowersCount)")
    }
    
    // MARK: - Listen to Friend Activities
    
    func listenToFriendActivities(uid: String) {
        activitiesListener?.remove()
        
        Task {
            // Clean up old activities (30+ days old)
            await cleanupOldActivities()
            
            // Get people I'm following
            let snapshot = try await followsCollection
                .whereField("followerId", isEqualTo: uid)
                .getDocuments()
            
            let followingIds = snapshot.documents
                .compactMap { Follow(document: $0) }
                .map { $0.followingId }
            
            print("Ã°Å¸â€œÅ  Listening to activities from \(followingIds.count) users I follow")
            
            guard !followingIds.isEmpty else {
                await MainActor.run {
                    self.friendActivities = []
                }
                return
            }
            
            // Calculate 30 days ago
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            // Listen to activities from people I follow (max 10 at a time due to Firestore limit)
            // Only show activities from last 30 days
            await MainActor.run {
                self.activitiesListener = self.activitiesCollection
                    .whereField("userId", in: Array(followingIds.prefix(10)))
                    .whereField("createdAt", isGreaterThan: Timestamp(date: thirtyDaysAgo))
                    .order(by: "createdAt", descending: true)
                    .limit(to: 50)
                    .addSnapshotListener { [weak self] snapshot, error in
                        if let error = error {
                            print("Ã¢ÂÅ’ Activities listener error: \(error)")
                            return
                        }
                        
                        guard let documents = snapshot?.documents else { return }
                        
                        print("Ã°Å¸â€œÅ  Received \(documents.count) activities from last 30 days")
                        
                        Task { @MainActor in
                            self?.friendActivities = documents.compactMap { FriendActivity(document: $0) }
                        }
                    }
            }
        }
    }
    
    // MARK: - Cleanup Old Activities (30+ days)
    
    private func cleanupOldActivities() async {
        do {
            // Calculate 30 days ago
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            // Query for old activities
            let oldActivities = try await activitiesCollection
                .whereField("createdAt", isLessThan: Timestamp(date: thirtyDaysAgo))
                .limit(to: 100) // Delete in batches
                .getDocuments()
            
            guard !oldActivities.documents.isEmpty else {
                return
            }
            
            print("Ã°Å¸â€”â€˜Ã¯Â¸Â Cleaning up \(oldActivities.documents.count) old activities...")
            
            // Delete old activities
            let batch = db.batch()
            for doc in oldActivities.documents {
                batch.deleteDocument(doc.reference)
            }
            
            try await batch.commit()
            
            print("Ã¢Å“â€¦ Deleted \(oldActivities.documents.count) activities older than 30 days")
            
        } catch {
            print("Ã¢Å¡Â Ã¯Â¸Â Cleanup failed (non-critical): \(error)")
        }
    }
    
    // MARK: - Post Activity (when user adds a card)
    
    func postCardActivity(cardId: String, make: String, model: String, year: String, imageURL: String, customFrame: String? = nil) async throws {
        guard let uid = FirebaseManager.shared.currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        
        guard let profile = UserService.shared.currentProfile else {
            throw UserServiceError.profileNotFound
        }
        
        // Check if activity already exists for this card
        let existingActivity = try await activitiesCollection
            .whereField("userId", isEqualTo: uid)
            .whereField("cardId", isEqualTo: cardId)
            .limit(to: 1)
            .getDocuments()
        
        if !existingActivity.documents.isEmpty {
            print("Ã¢â€žÂ¹Ã¯Â¸Â Activity already exists for card \(cardId)")
            return
        }
        
        let activityId = UUID().uuidString
        var data: [String: Any] = [
            "userId": uid,
            "username": profile.username,
            "level": profile.level,
            "cardId": cardId,
            "cardMake": make,
            "cardModel": model,
            "cardYear": year,
            "imageURL": imageURL,
            "createdAt": Timestamp(date: Date())
        ]
        
        if let customFrame = customFrame {
            data["customFrame"] = customFrame
        }
        
        try await activitiesCollection.document(activityId).setData(data)
        
        print("Ã¢Å“â€¦ Posted card activity: \(make) \(model) by \(profile.username)")
    }
    
    // MARK: - Update Activity Custom Frame
    
    /// Update customFrame for all activities with a specific cardId
    func updateActivityCustomFrame(cardId: String, customFrame: String?) async throws {
        // Find all activities for this card
        let snapshot = try await activitiesCollection
            .whereField("cardId", isEqualTo: cardId)
            .getDocuments()
        
        // Update each activity
        for document in snapshot.documents {
            if let frame = customFrame {
                try await activitiesCollection.document(document.documentID).updateData([
                    "customFrame": frame
                ])
            } else {
                try await activitiesCollection.document(document.documentID).updateData([
                    "customFrame": FieldValue.delete()
                ])
            }
        }
        
        print("✅ Updated customFrame for \(snapshot.documents.count) activities with cardId: \(cardId)")
    }
    
    // MARK: - Get Follow Stats for User Profile
    
    /// Get follow statistics for a specific user
    func getFollowStats(userId: String) async throws -> (friends: Int, following: Int, followers: Int) {
        // Get who this user follows
        let followingSnapshot = try await followsCollection
            .whereField("followerId", isEqualTo: userId)
            .getDocuments()
        
        let following = followingSnapshot.documents.map { $0.data()["followingId"] as? String ?? "" }
        
        // Get who follows this user
        let followersSnapshot = try await followsCollection
            .whereField("followingId", isEqualTo: userId)
            .getDocuments()
        
        let followers = followersSnapshot.documents.map { $0.data()["followerId"] as? String ?? "" }
        
        // Calculate mutual follows (friends)
        let followingSet = Set(following)
        let followersSet = Set(followers)
        let friendsCount = followingSet.intersection(followersSet).count
        
        return (
            friends: friendsCount,
            following: following.count,
            followers: followers.count
        )
    }
    
    // MARK: - Mark Followers as Viewed
    
    /// Call this when the Followers tab is opened to reset new follower notifications
    func markFollowersAsViewed() {
        UserDefaults.standard.set(Date(), forKey: "lastViewedFollowersAt")
        newFollowersCount = 0
        print("Ã¢Å“â€¦ Followers marked as viewed")
    }
    
    // MARK: - Stop Listeners
    
    
    // MARK: - Heat Management
    
    /// Add heat to an activity
    func addHeat(activityId: String, userId: String) async throws {
        let activityRef = db.collection("friend_activities").document(activityId)
        
        // Get the document
        let doc = try await activityRef.getDocument()
        
        // Check if document exists
        guard doc.exists else {
            throw FriendsServiceError.activityNotFound
        }
        
        // Get heatedBy array, default to empty if field doesn't exist (for old activities)
        let heatedBy = doc.data()?["heatedBy"] as? [String] ?? []
        
        // Skip if already heated
        if heatedBy.contains(userId) {
            print("âš ï¸ User already heated this activity, skipping")
            return
        }
        
        // Atomic update - add user to heatedBy array and increment count
        // If fields don't exist, they'll be created automatically
        try await activityRef.updateData([
            "heatedBy": FieldValue.arrayUnion([userId]),
            "heatCount": FieldValue.increment(Int64(1))
        ])
        
        print("âœ… Heat added to activity \(activityId)")
    }
    
    /// Remove heat from an activity
    func removeHeat(activityId: String, userId: String) async throws {
        let activityRef = db.collection("friend_activities").document(activityId)
        
        // Get the document
        let doc = try await activityRef.getDocument()
        
        // Check if document exists
        guard doc.exists else {
            throw FriendsServiceError.activityNotFound
        }
        
        // Get heatedBy array, default to empty if field doesn't exist (for old activities)
        let heatedBy = doc.data()?["heatedBy"] as? [String] ?? []
        
        // Skip if not heated
        if !heatedBy.contains(userId) {
            print("âš ï¸ User hasn't heated this activity, skipping")
            return
        }
        
        // Atomic update - remove user from heatedBy array and decrement count
        try await activityRef.updateData([
            "heatedBy": FieldValue.arrayRemove([userId]),
            "heatCount": FieldValue.increment(Int64(-1))
        ])
        
        print("âœ… Heat removed from activity \(activityId)")
    }
    
    func stopAllListeners() {
        followsListener?.remove()
        activitiesListener?.remove()
    }
}

// MARK: - Errors

enum FriendsServiceError: LocalizedError {
    case userNotFound
    case alreadyFollowing
    case cannotFollowSelf
    case activityNotFound
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .alreadyFollowing:
            return "Already following this user"
        case .cannotFollowSelf:
            return "You cannot follow yourself"
        case .activityNotFound:
            return "Activity not found"
        }
    }
    
    // MARK: - Migration: Backfill Custom Frames
    
    /// One-time migration to backfill customFrame from cards to activities
    func backfillActivityFrames() async throws {
        print("🔄 Starting frame backfill migration...")
        
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirebaseError.notAuthenticated
        }
        
        // Get all my cards with frames
        let cardsSnapshot = try await Firestore.firestore().collection("cards")
            .whereField("ownerId", isEqualTo: uid)
            .getDocuments()
        
        var updateCount = 0
        
        for cardDoc in cardsSnapshot.documents {
            guard let customFrame = cardDoc.data()["customFrame"] as? String else {
                continue  // Skip cards without frames
            }
            
            let cardId = cardDoc.documentID
            
            // Find activities for this card
            let activitiesSnapshot = try await db.collection("friend_activities")
                .whereField("cardId", isEqualTo: cardId)
                .getDocuments()
            
            // Update each activity
            for activityDoc in activitiesSnapshot.documents {
                try await db.collection("friend_activities").document(activityDoc.documentID).updateData([
                    "customFrame": customFrame
                ])
                updateCount += 1
            }
        }
        
        print("✅ Frame backfill complete: Updated \(updateCount) activities")
    }
}
