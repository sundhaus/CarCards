//
//  ActivityService.swift
//  Car Collector
//
//  Fetches recent activity (comments + heats) on the current user's cards
//

import Foundation
import FirebaseFirestore

struct ActivityItem: Identifiable {
    let id: String
    let type: ActivityType
    let userId: String
    let username: String
    let profilePictureURL: String?
    let text: String?       // comment text (nil for heats)
    let cardMake: String
    let cardModel: String
    let activityId: String  // friend_activity doc id
    let createdAt: Date
    
    enum ActivityType {
        case comment
        case heat
    }
    
    var timeDisplay: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: createdAt)
    }
}

@MainActor
class ActivityService: ObservableObject {
    static let shared = ActivityService()
    
    private let db = Firestore.firestore()
    
    @Published var activities: [ActivityItem] = []
    @Published var isLoading = false
    @Published var hasUnread = false
    
    private let lastViewedKey = "activityLastViewedTimestamp"
    
    var lastViewedDate: Date {
        let ts = UserDefaults.standard.double(forKey: lastViewedKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : Date.distantPast
    }
    
    private init() {}
    
    /// Mark all activity as read (call when user opens activity page)
    func markAsRead() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastViewedKey)
        hasUnread = false
    }
    
    /// Lightweight check for unread activity without fetching full list
    func checkForUnread() async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        let lastViewed = lastViewedDate
        
        do {
            // Check for any activity newer than last viewed
            let snapshot = try await db.collection("friend_activities")
                .whereField("userId", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            for doc in snapshot.documents {
                let data = doc.data()
                
                // Check heats
                if let heatTimestamps = data["heatTimestamps"] as? [String: Timestamp] {
                    for (heaterUid, ts) in heatTimestamps {
                        if heaterUid != uid && ts.dateValue() > lastViewed {
                            hasUnread = true
                            return
                        }
                    }
                }
                
                // Check comments
                let comments = try await db.collection("friend_activities")
                    .document(doc.documentID)
                    .collection("comments")
                    .order(by: "createdAt", descending: true)
                    .limit(to: 1)
                    .getDocuments()
                
                if let latest = comments.documents.first,
                   let commentUserId = latest.data()["userId"] as? String,
                   commentUserId != uid,
                   let commentTs = latest.data()["createdAt"] as? Timestamp,
                   commentTs.dateValue() > lastViewed {
                    hasUnread = true
                    return
                }
            }
            
            hasUnread = false
        } catch {
            print("⚠️ Failed to check unread activity: \(error)")
        }
    }
    
    func fetchActivity() async {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        isLoading = true
        
        do {
            // Get all friend_activities owned by current user
            let activitiesSnapshot = try await db.collection("friend_activities")
                .whereField("userId", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            var items: [ActivityItem] = []
            
            for doc in activitiesSnapshot.documents {
                let data = doc.data()
                let make = data["cardMake"] as? String ?? "Unknown"
                let model = data["cardModel"] as? String ?? ""
                let activityId = doc.documentID
                
                // Fetch heats
                if let heatedBy = data["heatedBy"] as? [String], !heatedBy.isEmpty {
                    let heatTimestamps = data["heatTimestamps"] as? [String: Timestamp] ?? [:]
                    let fallbackTimestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    for heaterUid in heatedBy {
                        if heaterUid == uid { continue } // skip self
                        
                        // Use per-user timestamp if available, else fallback to card creation
                        let heatTime = heatTimestamps[heaterUid]?.dateValue() ?? fallbackTimestamp
                        
                        let user = await lookupUser(uid: heaterUid)
                        
                        items.append(ActivityItem(
                            id: "\(activityId)-heat-\(heaterUid)",
                            type: .heat,
                            userId: heaterUid,
                            username: user.username,
                            profilePictureURL: user.pfp,
                            text: nil,
                            cardMake: make,
                            cardModel: model,
                            activityId: activityId,
                            createdAt: heatTime
                        ))
                    }
                }
                
                // Fetch comments
                let commentsSnapshot = try await db.collection("friend_activities")
                    .document(activityId)
                    .collection("comments")
                    .order(by: "createdAt", descending: true)
                    .limit(to: 20)
                    .getDocuments()
                
                for commentDoc in commentsSnapshot.documents {
                    let commentData = commentDoc.data()
                    let commentUserId = commentData["userId"] as? String ?? ""
                    if commentUserId == uid { continue } // skip own comments
                    
                    let user = await lookupUser(uid: commentUserId)
                    let text = commentData["text"] as? String ?? ""
                    let createdAt = (commentData["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    items.append(ActivityItem(
                        id: commentDoc.documentID,
                        type: .comment,
                        userId: commentUserId,
                        username: user.username,
                        profilePictureURL: user.pfp,
                        text: text,
                        cardMake: make,
                        cardModel: model,
                        activityId: activityId,
                        createdAt: createdAt
                    ))
                }
            }
            
            // Sort all by date, newest first
            activities = items.sorted { $0.createdAt > $1.createdAt }
            
            // Check for unread
            let lastViewed = lastViewedDate
            hasUnread = activities.contains { $0.createdAt > lastViewed }
            
            isLoading = false
            
        } catch {
            print("❌ Failed to fetch activity: \(error)")
            isLoading = false
        }
    }
    
    private var userCache: [String: (username: String, pfp: String?)] = [:]
    
    private func lookupUser(uid: String) async -> (username: String, pfp: String?) {
        if let cached = userCache[uid] { return cached }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let username = doc.data()?["username"] as? String ?? "Unknown"
            let pfp = doc.data()?["profilePictureURL"] as? String
            userCache[uid] = (username, pfp)
            return (username, pfp)
        } catch {
            return ("Unknown", nil)
        }
    }
}
