//
//  CommentSectionView.swift
//  Car Collector
//
//  Comment section displayed under cards in the friends feed.
//  Shows comment count, recent comments, and input bar.
//

import SwiftUI

// MARK: - Comment Button (shown under card)

struct CommentButton: View {
    let activityId: String
    let onTap: () -> Void
    @ObservedObject private var commentService = CommentService.shared
    
    private var count: Int {
        commentService.commentCounts[activityId] ?? 0
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                Text(count > 0 ? "\(count) comment\(count == 1 ? "" : "s")" : "Add a comment")
                    .font(.pCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .task {
            await commentService.fetchCommentCount(activityId: activityId)
        }
    }
}

// MARK: - Comments List (expanded view)

struct CommentsListView: View {
    let activityId: String
    @ObservedObject private var commentService = CommentService.shared
    
    private var comments: [CardComment] {
        commentService.commentsCache[activityId] ?? []
    }
    
    var body: some View {
        if !comments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(comments) { comment in
                    CommentRow(comment: comment)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Single Comment Row

struct CommentRow: View {
    let comment: CardComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(comment.username)
                .font(.pCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text(comment.text)
                .font(.pCaption)
                .foregroundStyle(.primary)
                .lineLimit(3)
            
            Spacer()
            
            Text(comment.timeAgo)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Comment Input Bar (Instagram-style above keyboard)

struct CommentInputBar: View {
    let activityId: String
    let onDismiss: () -> Void
    
    @State private var text = ""
    @State private var isSending = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Username avatar
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(UserService.shared.currentProfile?.username.prefix(1) ?? "?").uppercased())
                            .font(.poppins(13))
                            .foregroundStyle(.blue)
                    }
                
                // Text field
                TextField("Add a comment...", text: $text)
                    .font(.pSubheadline)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendComment()
                    }
                
                // Send button
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: sendComment) {
                        if isSending {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Post")
                                .font(.pSubheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                    }
                    .disabled(isSending)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .onAppear {
            isFocused = true
        }
    }
    
    private func sendComment() {
        let commentText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commentText.isEmpty, !isSending else { return }
        
        isSending = true
        
        Task {
            do {
                try await CommentService.shared.postComment(activityId: activityId, text: commentText)
                await MainActor.run {
                    text = ""
                    isSending = false
                    onDismiss()
                }
            } catch {
                print("❌ Failed to post comment: \(error)")
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }
}
