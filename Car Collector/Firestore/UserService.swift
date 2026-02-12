//
//  UserService.swift
//  CarCardCollector
//
//  Manages user profiles in Firestore
//  Handles username, level, XP, coins synced to cloud
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

// Firestore user profile model
struct UserProfile: Codable, Identifiable {
    var id: String  // Firebase uid
    var username: String
    var level: Int
    var currentXP: Int
    var totalXP: Int
    var coins: Int
    var totalCardsCollected: Int
    var createdAt: Date
    var linkedAccount: Bool
    var profilePictureURL: String?
    
    // Firestore document â†’ UserProfile
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.username = data["username"] as? String ?? "Unknown"
        self.level = data["level"] as? Int ?? 1
        self.currentXP = data["currentXP"] as? Int ?? 0
        self.totalXP = data["totalXP"] as? Int ?? 0
        self.coins = data["coins"] as? Int ?? 0
        self.totalCardsCollected = data["totalCardsCollected"] as? Int ?? 0
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.linkedAccount = data["linkedAccount"] as? Bool ?? false
        self.profilePictureURL = data["profilePictureURL"] as? String
    }
    
    // New user default
    init(uid: String, username: String) {
        self.id = uid
        self.username = username
        self.level = 1
        self.currentXP = 0
        self.totalXP = 0
        self.coins = 0
        self.totalCardsCollected = 0
        self.createdAt = Date()
        self.linkedAccount = false
        self.profilePictureURL = nil
    }
    
    // Convert to Firestore dictionary
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "username": username,
            "level": level,
            "currentXP": currentXP,
            "totalXP": totalXP,
            "coins": coins,
            "totalCardsCollected": totalCardsCollected,
            "createdAt": Timestamp(date: createdAt),
            "linkedAccount": linkedAccount
        ]
        
        if let url = profilePictureURL {
            dict["profilePictureURL"] = url
        }
        
        return dict
    }
}

@MainActor
class UserService: ObservableObject {
    static let shared = UserService()
    
    @Published var currentProfile: UserProfile?
    @Published var isProfileLoaded = false
    
    private let db = FirebaseManager.shared.db
    private var profileListener: ListenerRegistration?
    
    private var usersCollection: CollectionReference {
        db.collection("users")
    }
    
    private init() {}
    
    deinit {
        profileListener?.remove()
    }
    
    // MARK: - Create Profile (first launch)
    
    func createProfile(uid: String, username: String) async throws {
        let profile = UserProfile(uid: uid, username: username)
        
        try await usersCollection.document(uid).setData(profile.dictionary)
        
        self.currentProfile = profile
        self.isProfileLoaded = true
        
        print("âœ… Created profile for: \(username)")
    }
    
    // MARK: - Check if Profile Exists
    
    func profileExists(uid: String) async throws -> Bool {
        let doc = try await usersCollection.document(uid).getDocument()
        return doc.exists
    }
    
    // MARK: - Check if Username is Taken
    
    func isUsernameTaken(_ username: String) async throws -> Bool {
        let snapshot = try await usersCollection
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    // MARK: - Load Profile (with real-time listener)
    
    func loadProfile(uid: String) {
        // Remove existing listener
        profileListener?.remove()
        
        // Set up real-time listener so profile stays in sync
        profileListener = usersCollection.document(uid).addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("âŒ Profile listener error: \(error)")
                return
            }
            
            guard let snapshot = snapshot else { return }
            
            Task { @MainActor in
                if let profile = UserProfile(document: snapshot) {
                    self?.currentProfile = profile
                    self?.isProfileLoaded = true
                } else {
                    self?.isProfileLoaded = true
                }
            }
        }
    }
    
    // MARK: - Update Profile Fields
    
    func updateProfile(uid: String, fields: [String: Any]) async throws {
        try await usersCollection.document(uid).updateData(fields)
    }
    
    // MARK: - Update Username
    
    func updateUsername(uid: String, newUsername: String) async throws {
        // Check if taken first
        let taken = try await isUsernameTaken(newUsername)
        if taken {
            throw UserServiceError.usernameTaken
        }
        
        try await updateProfile(uid: uid, fields: ["username": newUsername])
    }
    
    // MARK: - Sync Level/XP/Coins to Firestore
    
    func syncProgress(uid: String, level: Int, currentXP: Int, totalXP: Int, coins: Int) async throws {
        try await updateProfile(uid: uid, fields: [
            "level": level,
            "currentXP": currentXP,
            "totalXP": totalXP,
            "coins": coins
        ])
    }
    
    // MARK: - Increment Card Count
    
    func incrementCardCount(uid: String) async throws {
        try await usersCollection.document(uid).updateData([
            "totalCardsCollected": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Fetch Another User's Profile (for marketplace)
    
    func fetchProfile(uid: String) async throws -> UserProfile? {
        let doc = try await usersCollection.document(uid).getDocument()
        return UserProfile(document: doc)
    }
    
    // MARK: - Search Users by Username
    
    func searchUsers(query: String) async throws -> [UserProfile] {
        guard !query.isEmpty else {
            return []
        }
        
        // Firestore doesn't support case-insensitive search or "contains"
        // So we'll get all users and filter client-side for better UX
        // For production, consider using Algolia or similar for better search
        
        let snapshot = try await usersCollection
            .limit(to: 50)  // Limit results to prevent excessive data transfer
            .getDocuments()
        
        let allProfiles = snapshot.documents.compactMap { UserProfile(document: $0) }
        
        // Filter by username (case-insensitive contains)
        let lowercaseQuery = query.lowercased()
        let results = allProfiles.filter { profile in
            profile.username.lowercased().contains(lowercaseQuery)
        }
        
        print("🔍 Found \(results.count) users matching '\(query)'")
        
        return results
    }
    
    // MARK: - Delete User Data
    
    func deleteUserData(uid: String) async throws {
        // Delete profile
        try await usersCollection.document(uid).delete()
        
        profileListener?.remove()
        self.currentProfile = nil
        self.isProfileLoaded = false
        
        print("âœ… Deleted user data for: \(uid)")
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        profileListener?.remove()
    }
    
    // MARK: - Upload Profile Picture
    
    func uploadProfilePicture(uid: String, image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw FirebaseError.uploadFailed
        }
        
        let path = "profile_pictures/\(uid).jpg"
        let ref = FirebaseManager.shared.storage.reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        
        // Update profile with URL
        try await updateProfile(uid: uid, fields: ["profilePictureURL": downloadURL.absoluteString])
        
        print("âœ… Uploaded profile picture: \(path)")
        return downloadURL.absoluteString
    }
}

// MARK: - Errors

enum UserServiceError: LocalizedError {
    case usernameTaken
    case profileNotFound
    
    var errorDescription: String? {
        switch self {
        case .usernameTaken:
            return "That username is already taken"
        case .profileNotFound:
            return "Profile not found"
        }
    }
}
