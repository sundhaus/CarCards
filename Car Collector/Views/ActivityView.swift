//
//  ActivityView.swift
//  Car Collector
//
//  Shows recent activity (comments + heats) on the current user's cards
//

import SwiftUI

struct ActivityView: View {
    @Binding var isShowing: Bool
    @StateObject private var activityService = ActivityService.shared
    
    var body: some View {
        ZStack {
            Color.appBackgroundSolid
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { isShowing = false }) {
                        Image(systemName: "chevron.left")
                            .font(.pTitle3)
                            .foregroundStyle(.primary)
                    }
                    
                    Text("ACTIVITY")
                        .font(.pTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 18)
                .padding(.bottom, 10)
                
                // Content
                if activityService.isLoading && activityService.activities.isEmpty {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if activityService.activities.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        
                        Text("No activity yet")
                            .font(.pBody)
                            .foregroundStyle(.secondary)
                        
                        Text("When people heat or comment on your cards, it'll show up here.")
                            .font(.pCaption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(activityService.activities) { item in
                                ActivityRow(item: item)
                                
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await activityService.fetchActivity()
        }
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let item: ActivityItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(item.type == .heat ?
                          LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: item.type == .heat ? "flame.fill" : "bubble.right.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Main text
                Group {
                    if item.type == .heat {
                        Text("**\(item.username)** gave heat to your **\(cardName)** card")
                    } else {
                        Text("**\(item.username)** commented on your **\(cardName)** card")
                    }
                }
                .font(.pSubheadline)
                .foregroundStyle(.primary)
                
                // Comment text preview
                if let commentText = item.text {
                    Text(commentText)
                        .font(.pCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                // Time
                Text(item.timeDisplay)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var cardName: String {
        if item.cardModel.isEmpty {
            return item.cardMake
        }
        return "\(item.cardMake) \(item.cardModel)"
    }
}

#Preview {
    ActivityView(isShowing: .constant(true))
}
