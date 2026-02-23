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
    let username: String
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
    @Published var unreadCount = 0
    
    private init() {}
    
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
                    let heatTimestamp = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    for heaterUid in heatedBy {
                        if heaterUid == uid { continue } // skip self
                        
                        // Look up username
                        let username = await lookupUsername(uid: heaterUid)
                        
                        items.append(ActivityItem(
                            id: "\(activityId)-heat-\(heaterUid)",
                            type: .heat,
                            username: username,
                            text: nil,
                            cardMake: make,
                            cardModel: model,
                            activityId: activityId,
                            createdAt: heatTimestamp
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
                    
                    let username = commentData["username"] as? String ?? "Unknown"
                    let text = commentData["text"] as? String ?? ""
                    let createdAt = (commentData["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    items.append(ActivityItem(
                        id: commentDoc.documentID,
                        type: .comment,
                        username: username,
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
            unreadCount = 0
            isLoading = false
            
        } catch {
            print("❌ Failed to fetch activity: \(error)")
            isLoading = false
        }
    }
    
    private var usernameCache: [String: String] = [:]
    
    private func lookupUsername(uid: String) async -> String {
        if let cached = usernameCache[uid] { return cached }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let username = doc.data()?["username"] as? String ?? "Unknown"
            usernameCache[uid] = username
            return username
        } catch {
            return "Unknown"
        }
    }
}
