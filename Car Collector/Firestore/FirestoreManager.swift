//
//  FirebaseManager.swift
//  CarCardCollector
//
//  Core Firebase initialization + Anonymous Authentication
//  Handles silent sign-in on first launch (Clash of Clans style)
//

import Foundation
import Combine
import FirebaseCore
@preconcurrency import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    // Firebase references
    let db: Firestore
    let storage: Storage
    let auth: Auth
    
    // Auth state
    @Published var currentUserId: String?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var isAnonymous = true
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private init() {
        // Ensure Firebase is configured before accessing any services
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        self.db = Firestore.firestore()
        self.storage = Storage.storage()
        self.auth = Auth.auth()
        
        // Listen for auth state changes
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUserId = user?.uid
                self?.isAuthenticated = user != nil
                self?.isAnonymous = user?.isAnonymous ?? true
                self?.isLoading = false
            }
        }
    }
    
    deinit {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Configure (called from App init)
    
    static func configure() {
        // Only configure if not already done
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Enable Firestore offline persistence
        let dbSettings = FirestoreSettings()
        dbSettings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = dbSettings
        
        print("✅ Firebase configured")
    }
    
    // MARK: - Anonymous Sign In (silent, no UI)
    
    func signInAnonymously() async throws {
        if auth.currentUser != nil {
            print("✅ Already signed in: \(auth.currentUser?.uid ?? "unknown")")
            return
        }
        
        let result = try await auth.signInAnonymously()
        self.currentUserId = result.user.uid
        self.isAuthenticated = true
        self.isAnonymous = true
        
        print("✅ Anonymous sign-in: \(result.user.uid)")
    }
    
    // MARK: - Link to Apple ID (upgrade anonymous → permanent)
    
    func linkWithApple(idToken: String, nonce: String) async throws {
        guard let user = auth.currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        
        do {
            let result = try await user.link(with: credential)
            self.isAnonymous = false
            print("✅ Linked Apple account: \(result.user.uid)")
        } catch let error as NSError {
            // If credential already linked to another account
            if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                throw FirebaseError.accountAlreadyLinked
            }
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        try auth.signOut()
        self.currentUserId = nil
        self.isAuthenticated = false
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        // Delete user data from Firestore first
        if let uid = currentUserId {
            try await UserService.shared.deleteUserData(uid: uid)
        }
        
        // Delete Firebase auth account
        try await user.delete()
        
        self.currentUserId = nil
        self.isAuthenticated = false
    }
}

// MARK: - Error Types

enum FirebaseError: LocalizedError {
    case notAuthenticated
    case accountAlreadyLinked
    case userNotFound
    case uploadFailed
    case documentNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in"
        case .accountAlreadyLinked:
            return "This account is already linked to another user"
        case .userNotFound:
            return "User not found"
        case .uploadFailed:
            return "Failed to upload image"
        case .documentNotFound:
            return "Document not found"
        }
    }
}
