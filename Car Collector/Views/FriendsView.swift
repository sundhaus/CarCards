//
//  FriendsView.swift
//  CarCardCollector
//
//  Friends feed showing recent card additions from people you follow
//  Now with Heat system for identifying top weekly cards
//

import SwiftUI

struct FriendsView: View {
    var isLandscape: Bool = false
    @StateObject private var friendsService = FriendsService.shared
    @State private var showFriendsList = false
    @State private var showSearch = false
    @State private var flippedCardId: String? = nil  // Track which card is flipped
    @Environment(\.dismiss) private var dismiss
    
    // Generate gradient colors based on level (same as LevelHeader)
    private func levelGradient(for level: Int) -> [Color] {
        let colors: [Color] = [
            .red,
            Color(red: 1.0, green: 0.5, blue: 0.0), // Orange
            .yellow,
            .green,
            .cyan,
            .blue,
            Color(red: 0.5, green: 0.0, blue: 1.0), // Purple
            Color(red: 1.0, green: 0.0, blue: 1.0), // Magenta
            .red // Complete the cycle
        ]
        
        let cycleLength = 80
        let position = (level - 1) % cycleLength
        let segmentLength = 10
        let colorIndex = position / segmentLength
        
        let startColor = colors[colorIndex]
        let endColor = colors[colorIndex + 1]
        
        return [startColor, endColor]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark blue background
                Color.appBackgroundSolid
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header banner
                    ZStack(alignment: .bottom) {
                        // Background extends to top
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea(edges: .top)
                        
                        // Content at bottom
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                            }
                            
                            Spacer()
                            
                            Text("Friends")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    showFriendsList = true
                                }
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                    
                                    // Notification badge
                                    if friendsService.newFollowersCount > 0 {
                                        ZStack {
                                            Circle()
                                                .fill(.red)
                                                .frame(width: 18, height: 18)
                                            
                                            Text("\(friendsService.newFollowersCount)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                        .offset(x: 8, y: -8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .padding(.bottom, 8)
                    }
                    .frame(height: 60)
                    
                    // Friends activity feed
                    ScrollView {
                        VStack(spacing: 0) {
                            if friendsService.isLoading {
                                ProgressView()
                                    .padding(.top, 60)
                            } else if friendsService.friendActivities.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.gray)
                                    Text("No recent activity")
                                        .foregroundStyle(.secondary)
                                    Text("Follow people to see their cards")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Button(action: {
                                        showSearch = true
                                    }) {
                                        HStack {
                                            Image(systemName: "person.badge.plus")
                                            Text("Find People")
                                        }
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(.blue)
                                        .cornerRadius(20)
                                    }
                                    .padding(.top, 8)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .padding(.top, 60)
                            } else {
                                ForEach(friendsService.friendActivities) { activity in
                                    FriendActivityCard(
                                        activity: activity,
                                        levelGradient: levelGradient(for: activity.level),
                                        flippedCardId: $flippedCardId
                                    )
                                    
                                    if activity.id != friendsService.friendActivities.last?.id {
                                        Divider()
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.bottom, isLandscape ? 20 : 100)
                        .background(
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Tap anywhere in feed area to dismiss flipped card
                                    if flippedCardId != nil {
                                        withAnimation(.spring(response: 0.4)) {
                                            flippedCardId = nil
                                        }
                                    }
                                }
                        )
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                .padding(.trailing, isLandscape ? 100 : 0)
                
                // Bottom blur gradient behind hub (portrait mode)
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .clear, Color(.systemGray6).opacity(0.7), Color(.systemGray6), Color(.systemGray6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                startListeners()
            }
        }
    }
    
    private func startListeners() {
        guard let uid = FirebaseManager.shared.currentUserId else { return }
        
        friendsService.listenToFollows(uid: uid)
        friendsService.listenToFriendActivities(uid: uid)
    }
}

// Individual friend activity card in feed
struct FriendActivityCard: View {
    let activity: FriendActivity
    let levelGradient: [Color]
    @Binding var flippedCardId: String?  // Shared state from parent
    
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    @State private var isHeated: Bool = false
    @State private var heatCount: Int = 0
    @State private var isAnimatingHeat = false
    @State private var showFloatingFlame = false
    
    // Specs fetching state
    @State private var fetchedSpecs: VehicleSpecs?
    @State private var isFetchingSpecs = false
    
    // Track the last synced state from Firestore to detect conflicts
    @State private var lastSyncedHeatedBy: [String] = []
    @State private var lastSyncedHeatCount: Int = 0
    
    // Computed property: is THIS card flipped?
    private var isFlipped: Bool {
        flippedCardId == activity.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Friend info header
            HStack(spacing: 8) {
                // Level bubble
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: levelGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Text("\(activity.level)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                // Tappable username
                NavigationLink {
                    UserProfileView(userId: activity.userId, username: activity.username)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.username)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("added a card")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(activity.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Card preview with tap to flip, double-tap to heat
            ZStack {
                if !isFlipped {
                    // FRONT OF CARD
                    ZStack {
                        // Custom frame/border
                        if let frameName = activity.customFrame, frameName != "None" {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    frameName == "White" ? Color.white : Color.black,
                                    lineWidth: 6
                                )
                                .frame(width: 360, height: 202.5)
                        }
                        
                        if let image = cardImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 360, height: 202.5)
                                .clipped()
                                .cornerRadius(12)
                                .overlay(
                                ZStack {
                                    // Floating flame animation
                                    if showFloatingFlame {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 80))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.orange, .red],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .shadow(color: .black.opacity(0.3), radius: 10)
                                            .scaleEffect(showFloatingFlame ? 1.0 : 0.5)
                                            .opacity(showFloatingFlame ? 1.0 : 0.0)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                    
                                    // Tap hint
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Text("Tap for specs")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.black.opacity(0.6))
                                                .cornerRadius(6)
                                                .padding(8)
                                        }
                                    }
                                }
                            )
                        } else {
                            // Placeholder while loading
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.2, green: 0.25, blue: 0.35), Color(red: 0.15, green: 0.2, blue: 0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                if isLoadingImage {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "car.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.white.opacity(0.6))
                                    
                                    VStack(spacing: 4) {
                                        Text("\(activity.cardMake) \(activity.cardModel)")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text(activity.cardYear)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                            }
                            .frame(width: 360, height: 202.5)
                        }
                    }
                    .onTapGesture {
                        // Single tap to flip/unflip
                        if isFlipped {
                            // This card is flipped, flip it back
                            withAnimation(.spring(response: 0.4)) {
                                flippedCardId = nil
                            }
                        } else {
                            // Flip this card (auto-flips any other card back)
                            Task {
                                await fetchSpecsIfNeeded()
                            }
                            withAnimation(.spring(response: 0.4)) {
                                flippedCardId = activity.id
                            }
                        }
                    }
                    .onTapGesture(count: 2) {
                        // Double tap to heat
                        if !isHeated {
                            toggleHeat()
                        }
                    }
                } else {
                    // BACK OF CARD
                    if isFetchingSpecs {
                        // Loading specs
                        ZStack {
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.5)
                                Text("Loading specs...")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .frame(width: 360, height: 202.5)
                        .cornerRadius(12)
                    } else {
                        // Card back with specs
                        ZStack {
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            VStack(spacing: 12) {
                                Text("\(activity.cardMake) \(activity.cardModel)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Text(activity.cardYear)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                
                                // Stats grid
                                VStack(spacing: 8) {
                                    HStack(spacing: 12) {
                                        statItem(label: "HP", value: parseIntValue(fetchedSpecs?.horsepower))
                                        statItem(label: "TRQ", value: parseIntValue(fetchedSpecs?.torque))
                                    }
                                    
                                    HStack(spacing: 12) {
                                        statItem(label: "0-60", value: parseDoubleValue(fetchedSpecs?.zeroToSixty))
                                        statItem(label: "TOP", value: parseIntValue(fetchedSpecs?.topSpeed))
                                    }
                                    
                                    HStack(spacing: 12) {
                                        statItem(label: "ENGINE", value: fetchedSpecs?.engine ?? "???", compact: true)
                                        statItem(label: "DRIVE", value: fetchedSpecs?.drivetrain ?? "???", compact: true)
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                Text("Tap to flip back")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.vertical, 12)
                        }
                        .frame(width: 360, height: 202.5)
                        .cornerRadius(12)
                    }
                }
            }
            }
            .padding(.horizontal)
            .task {
                await loadCardImage()
            }
            .onChange(of: activity.heatedBy) { _, newHeatedBy in
                // Only sync from Firestore if the data actually changed from what we last knew
                syncFromFirestoreIfNeeded(newHeatedBy: newHeatedBy, newHeatCount: activity.heatCount)
            }
            .onAppear {
                // Initial load only
                if lastSyncedHeatedBy.isEmpty {
                    loadHeatState()
                }
            }
            
            // Engagement buttons - Heat system
            HStack(spacing: 20) {
                // Heat button (flame icon)
                Button(action: {
                    toggleHeat()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isHeated ? "flame.fill" : "flame")
                            .font(.subheadline)
                            .foregroundStyle(isHeated ?
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ) :
                                LinearGradient(
                                    colors: [.secondary, .secondary],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(isAnimatingHeat ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimatingHeat)
                        
                        if heatCount > 0 {
                            Text("\(heatCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(isHeated ? .orange : .secondary)
                        }
                    }
                }
                
                // Comment button (placeholder for future)
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.subheadline)
                        Text("Comment")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    private func loadCardImage() async {
        isLoadingImage = true
        
        do {
            let image = try await CardService.shared.loadImage(from: activity.imageURL)
            await MainActor.run {
                cardImage = image
                isLoadingImage = false
            }
        } catch {
            print("❌ Failed to load card image: \(error)")
            await MainActor.run {
                isLoadingImage = false
            }
        }
    }
    
    private func loadHeatState() {
        guard let currentUserId = FirebaseManager.shared.currentUserId else { return }
        
        // Load initial state from activity
        isHeated = activity.heatedBy.contains(currentUserId)
        heatCount = activity.heatCount
        
        // Store what we loaded
        lastSyncedHeatedBy = activity.heatedBy
        lastSyncedHeatCount = activity.heatCount
        
        print("📊 Loaded heat state - isHeated: \(isHeated), count: \(heatCount)")
    }
    
    private func syncFromFirestoreIfNeeded(newHeatedBy: [String], newHeatCount: Int) {
        guard let currentUserId = FirebaseManager.shared.currentUserId else { return }
        
        // Check if Firestore data actually changed from what we last synced
        guard newHeatedBy != lastSyncedHeatedBy || newHeatCount != lastSyncedHeatCount else {
            print("📊 No change in Firestore data, skipping sync")
            return
        }
        
        print("📊 Firestore updated - syncing: heatedBy: \(newHeatedBy.count), count: \(newHeatCount)")
        
        // Update our local state to match Firestore
        isHeated = newHeatedBy.contains(currentUserId)
        heatCount = newHeatCount
        
        // Update last synced state
        lastSyncedHeatedBy = newHeatedBy
        lastSyncedHeatCount = newHeatCount
    }
    
    private func toggleHeat() {
        guard let currentUserId = FirebaseManager.shared.currentUserId else { return }
        
        // Prevent double-tapping
        guard !isAnimatingHeat else { return }
        
        // Determine action
        let willBeHeated = !isHeated
        
        print("🔥 Toggle heat - current: \(isHeated), will be: \(willBeHeated)")
        
        // Optimistic UI update
        isHeated = willBeHeated
        
        if willBeHeated {
            heatCount += 1
            
            // Animate button flame
            isAnimatingHeat = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimatingHeat = false
            }
            
            // Show floating flame over card
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showFloatingFlame = true
            }
            
            // Hide floating flame after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showFloatingFlame = false
                }
            }
            
            // Update Firestore
            Task {
                do {
                    try await FriendsService.shared.addHeat(activityId: activity.id, userId: currentUserId)
                    print("✅ Heat added to Firestore")
                } catch {
                    // Revert on error
                    await MainActor.run {
                        isHeated = false
                        heatCount = max(0, heatCount - 1)
                    }
                    print("❌ Failed to add heat: \(error)")
                }
            }
        } else {
            heatCount = max(0, heatCount - 1)
            
            // Update Firestore
            Task {
                do {
                    try await FriendsService.shared.removeHeat(activityId: activity.id, userId: currentUserId)
                    print("✅ Heat removed from Firestore")
                } catch {
                    // Revert on error
                    await MainActor.run {
                        isHeated = true
                        heatCount += 1
                    }
                    print("❌ Failed to remove heat: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods for Specs
    
    private func statItem(label: String, value: String, compact: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: compact ? 14 : 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 4 : 8)
        .background(Color.white.opacity(0.15))
        .cornerRadius(6)
    }
    
    private func parseIntValue(_ string: String?) -> String {
        guard let string = string, string != "N/A" else { return "???" }
        let cleaned = string.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleaned.isEmpty ? "???" : cleaned
    }
    
    private func parseDoubleValue(_ string: String?) -> String {
        guard let string = string, string != "N/A" else { return "???" }
        let cleaned = string.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return cleaned.isEmpty ? "???" : cleaned + "s"
    }
    
    private func fetchSpecsIfNeeded() async {
        guard fetchedSpecs == nil else { return }
        
        await MainActor.run {
            isFetchingSpecs = true
        }
        
        do {
            // Use VehicleIDService - checks Firestore cache first!
            // If your friend already flipped this card, specs load instantly
            let vehicleService = VehicleIdentificationService()
            let specs = try await vehicleService.fetchSpecs(
                make: activity.cardMake,
                model: activity.cardModel,
                year: activity.cardYear
            )
            
            await MainActor.run {
                fetchedSpecs = specs
                isFetchingSpecs = false
            }
            
            print("✅ Loaded specs for \(activity.cardMake) \(activity.cardModel) from shared cache")
        } catch {
            print("❌ Failed to fetch specs: \(error)")
            await MainActor.run {
                isFetchingSpecs = false
            }
        }
    }
}

#Preview {
    FriendsView()
}
