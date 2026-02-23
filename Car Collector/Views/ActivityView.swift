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
    @State private var profileImage: UIImage?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile picture
            ZStack {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.2)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(String(item.username.prefix(1)).uppercased())
                                .font(.poppins(14))
                                .foregroundStyle(.white)
                        }
                }
                
                // Small type badge in corner
                Image(systemName: item.type == .heat ? "flame.fill" : "bubble.right.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(item.type == .heat ? Color.orange : Color.blue)
                    .clipShape(Circle())
                    .offset(x: 13, y: 13)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Line 1: username + action
                let action = item.type == .heat ? "gave heat to your" : "commented on your"
                
                (Text(item.username)
                    .font(.pSubheadline)
                    .foregroundColor(.white)
                 + Text("  \(action)")
                    .font(.pCaption)
                    .foregroundColor(.gray)
                )
                
                // Line 2: card make + model (always on new line, bold white)
                Text(cardName.uppercased())
                    .font(.pSubheadline)
                    .foregroundColor(.white)
                
                // Comment text preview (white, non-bold)
                if let commentText = item.text {
                    let displayText = UserService.shared.currentProfile?.isMinor == true ? ProfanityFilter.censor(commentText) : commentText
                    Text(displayText)
                        .font(.custom("Futura-Medium", fixedSize: DeviceScale.f(13)))
                        .foregroundColor(.white.opacity(0.85))
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
        .task { await loadProfileImage() }
    }
    
    private var cardName: String {
        if item.cardModel.isEmpty {
            return item.cardMake
        }
        return "\(item.cardMake) \(item.cardModel)"
    }
    
    private func loadProfileImage() async {
        guard let urlString = item.profilePictureURL,
              let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run { profileImage = image }
            }
        } catch {
            print("⚠️ Failed to load activity pfp: \(error)")
        }
    }
}

#Preview {
    ActivityView(isShowing: .constant(true))
}
