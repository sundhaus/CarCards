//
//  CommentService.swift
//  Car Collector
//
//  Manages comments on friend activity cards via Firestore subcollection
//

import Foundation
import FirebaseFirestore

struct CardComment: Identifiable {
    let id: String
    let userId: String
    let username: String
    let text: String
    let createdAt: Date
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.username = data["username"] as? String ?? ""
        self.text = data["text"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 604800))w"
    }
}

@MainActor
class CommentService: ObservableObject {
    static let shared = CommentService()
    
    private let db = Firestore.firestore()
    
    // Cache: activityId -> comments
    @Published var commentsCache: [String: [CardComment]] = [:]
    // Cache: activityId -> comment count
    @Published var commentCounts: [String: Int] = [:]
    
    private var listeners: [String: ListenerRegistration] = [:]
    
    private init() {}
    
    deinit {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    deinit {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Post Comment
    
    func postComment(activityId: String, text: String) async throws {
        guard let uid = FirebaseManager.shared.currentUserId,
              let username = UserService.shared.currentProfile?.username else { return }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let data: [String: Any] = [
            "userId": uid,
            "username": username,
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("friend_activities")
            .document(activityId)
            .collection("comments")
            .addDocument(data: data)
        
        // Update comment count on the activity document
        try await db.collection("friend_activities")
            .document(activityId)
            .updateData(["commentCount": FieldValue.increment(Int64(1))])
        
        print("💬 Comment posted on activity \(activityId)")
    }
    
    // MARK: - Listen to Comments
    
    func listenToComments(activityId: String) {
        // Don't duplicate listeners
        guard listeners[activityId] == nil else { return }
        
        let listener = db.collection("friend_activities")
            .document(activityId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                
                let comments = snapshot.documents.compactMap { CardComment(document: $0) }
                Task { @MainActor in
                    self.commentsCache[activityId] = comments
                    self.commentCounts[activityId] = comments.count
                }
            }
        
        listeners[activityId] = listener
    }
    
    // MARK: - Fetch Comment Count (lightweight)
    
    func fetchCommentCount(activityId: String) async {
        // Use cached count from activity document's commentCount field
        // This avoids reading the full subcollection
        if commentCounts[activityId] != nil { return }
        
        do {
            let doc = try await db.collection("friend_activities").document(activityId).getDocument()
            let count = doc.data()?["commentCount"] as? Int ?? 0
            commentCounts[activityId] = count
        } catch {
            print("⚠️ Failed to fetch comment count: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    func removeListener(activityId: String) {
        listeners[activityId]?.remove()
        listeners.removeValue(forKey: activityId)
    }
    
    func removeAllListeners() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }
}
