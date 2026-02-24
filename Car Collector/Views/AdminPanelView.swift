//
//  AdminPanelView.swift
//  CarCardCollector
//
//  Admin panel for managing users and removing cards
//

import SwiftUI

struct AdminPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var adminService = AdminService.shared
    
    @State private var searchText = ""
    @State private var searchResults: [(id: String, username: String, totalCards: Int)] = []
    @State private var selectedUser: (id: String, username: String)? = nil
    @State private var userCards: [CloudCard] = []
    @State private var isSearching = false
    @State private var isLoadingCards = false
    @State private var confirmDelete: CloudCard? = nil
    @State private var statusMessage: String? = nil
    @State private var showSystemResetConfirm1 = false
    @State private var showSystemResetConfirm2 = false
    @State private var isResetting = false
    @State private var showH2HResetConfirm = false
    @State private var isResettingH2H = false
    @State private var showFeedResetConfirm = false
    @State private var isResettingFeed = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchBar
                    statusBanner
                    scrollContent
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .modifier(AdminAlertsModifier(
                confirmDelete: $confirmDelete,
                showSystemResetConfirm1: $showSystemResetConfirm1,
                showSystemResetConfirm2: $showSystemResetConfirm2,
                showH2HResetConfirm: $showH2HResetConfirm,
                showFeedResetConfirm: $showFeedResetConfirm,
                onRemoveCard: { card in removeCard(card) },
                onSystemReset: performSystemReset,
                onH2HReset: performH2HReset,
                onFeedReset: performFeedReset
            ))
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)
            TextField("Search username...", text: $searchText)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { searchUsers() }
        }
        .padding(12)
        .background(.white.opacity(0.08))
        .cornerRadius(12)
        .padding()
    }
    
    // MARK: - Status Banner
    
    @ViewBuilder
    private var statusBanner: some View {
        if let status = statusMessage {
            Text(status)
                .font(.caption.bold())
                .foregroundStyle(.green)
                .padding(.horizontal)
                .transition(.opacity)
        }
    }
    
    // MARK: - Scroll Content
    
    private var scrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                adminToolsSection
                
                Divider().background(.white.opacity(0.2)).padding(.horizontal)
                
                if let user = selectedUser {
                    userCardSection(userId: user.id, username: user.username)
                } else {
                    searchResultsList
                }
            }
        }
    }
    
    // MARK: - Admin Tools Section
    
    private var adminToolsSection: some View {
        VStack(spacing: 4) {
            systemResetButton
                .padding(.vertical, 8)
            
            Divider().background(.white.opacity(0.2)).padding(.horizontal)
            
            h2hResetButton
            feedResetButton
        }
    }
    
    // MARK: - System Reset Button
    
    @ViewBuilder
    private var systemResetButton: some View {
        if isResetting {
            VStack(spacing: 16) {
                ProgressView().tint(.red).scaleEffect(1.5)
                Text("Wiping all data...").font(.headline).foregroundStyle(.red)
                Text("Do not close the app").font(.caption).foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } else {
            Button { showSystemResetConfirm1 = true } label: {
                AdminToolRow(
                    icon: "exclamationmark.triangle.fill", iconColor: .yellow,
                    title: "SYSTEM-WIDE RESET", titleColor: .red,
                    titleFont: .headline.bold(),
                    trailingIcon: "trash.fill", trailingColor: .red,
                    bgColor: .red
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - H2H Reset Button
    
    @ViewBuilder
    private var h2hResetButton: some View {
        if isResettingH2H {
            AdminProgressRow(text: "Clearing H2H data...", color: .orange)
        } else {
            Button { showH2HResetConfirm = true } label: {
                AdminToolRow(
                    icon: "flag.checkered", iconColor: .orange,
                    title: "Reset All Head-to-Head", titleColor: .orange,
                    subtitle: "Races · Cooldowns · Votes", bgColor: .orange
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Feed Reset Button
    
    @ViewBuilder
    private var feedResetButton: some View {
        if isResettingFeed {
            AdminProgressRow(text: "Clearing feed & featured...", color: .purple)
        } else {
            Button { showFeedResetConfirm = true } label: {
                AdminToolRow(
                    icon: "newspaper", iconColor: .purple,
                    title: "Reset Feed & Featured", titleColor: .purple,
                    subtitle: "Activities · Featured · Follows", bgColor: .purple
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Search Results
    
    @ViewBuilder
    private var searchResultsList: some View {
        if isSearching {
            ProgressView().tint(.white).padding(40)
        } else if searchResults.isEmpty && !searchText.isEmpty {
            Text("No users found")
                .foregroundStyle(.white.opacity(0.5))
                .padding(40)
        } else {
            ForEach(searchResults, id: \.id) { user in
                AdminSearchResultRow(user: user) {
                    selectedUser = (id: user.id, username: user.username)
                    loadUserCards(userId: user.id)
                }
                Divider().background(.white.opacity(0.1))
            }
        }
    }
    
    // MARK: - User Card Section
    
    private func userCardSection(userId: String, username: String) -> some View {
        VStack(spacing: 0) {
            Button {
                selectedUser = nil; userCards = []
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back to search")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .padding()
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(username)'s Cards (\(userCards.count))")
                .font(.headline).foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal).padding(.bottom, 8)
            
            if isLoadingCards {
                ProgressView().tint(.white).padding(40)
            } else if userCards.isEmpty {
                Text("No cards found").foregroundStyle(.white.opacity(0.5)).padding(40)
            } else {
                ForEach(userCards) { card in
                    AdminCardRow(card: card) { confirmDelete = card }
                    Divider().background(.white.opacity(0.1))
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func searchUsers() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        Task {
            do { searchResults = try await adminService.searchUsers(query: searchText) }
            catch { print("❌ Search failed: \(error)") }
            isSearching = false
        }
    }
    
    private func loadUserCards(userId: String) {
        isLoadingCards = true
        Task {
            do { userCards = try await adminService.fetchUserCards(userId: userId) }
            catch { print("❌ Failed to load cards: \(error)") }
            isLoadingCards = false
        }
    }
    
    private func removeCard(_ card: CloudCard) {
        Task {
            do {
                try await adminService.removeCard(cardId: card.id, ownerId: card.ownerId)
                userCards.removeAll { $0.id == card.id }
                withAnimation { statusMessage = "✅ Removed \(card.make) \(card.model)" }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { statusMessage = nil }
            } catch {
                withAnimation { statusMessage = "❌ Error: \(error.localizedDescription)" }
            }
        }
    }
    
    private func performSystemReset() {
        isResetting = true
        statusMessage = "🔄 System reset in progress..."
        Task {
            do {
                try await adminService.systemWideReset()
                await MainActor.run {
                    isResetting = false; searchResults = []; userCards = []; selectedUser = nil
                    withAnimation { statusMessage = "✅ SYSTEM RESET COMPLETE — Restart the app" }
                }
            } catch {
                await MainActor.run {
                    isResetting = false
                    withAnimation { statusMessage = "❌ Reset failed: \(error.localizedDescription)" }
                }
            }
        }
    }
    
    private func performH2HReset() {
        isResettingH2H = true
        statusMessage = "🔄 Resetting Head-to-Head..."
        Task {
            do {
                try await adminService.resetAllHeadToHead()
                await MainActor.run { isResettingH2H = false; withAnimation { statusMessage = "✅ H2H Reset — all cards freed" } }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { withAnimation { statusMessage = nil } }
            } catch {
                await MainActor.run { isResettingH2H = false; withAnimation { statusMessage = "❌ H2H reset failed: \(error.localizedDescription)" } }
            }
        }
    }
    
    private func performFeedReset() {
        isResettingFeed = true
        statusMessage = "🔄 Resetting feed & featured..."
        Task {
            do {
                try await adminService.resetFeedAndFeatured()
                await MainActor.run { isResettingFeed = false; withAnimation { statusMessage = "✅ Feed & featured cleared" } }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { withAnimation { statusMessage = nil } }
            } catch {
                await MainActor.run { isResettingFeed = false; withAnimation { statusMessage = "❌ Feed reset failed: \(error.localizedDescription)" } }
            }
        }
    }
}

// MARK: - Extracted Subviews

struct AdminToolRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let titleColor: Color
    var titleFont: Font = .subheadline.bold()
    var subtitle: String? = nil
    var trailingIcon: String? = nil
    var trailingColor: Color = .gray
    let bgColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(iconColor)
            Text(title).font(titleFont).foregroundStyle(titleColor)
            Spacer()
            if let subtitle = subtitle {
                Text(subtitle).font(.caption2).foregroundStyle(.gray)
            }
            if let trailingIcon = trailingIcon {
                Image(systemName: trailingIcon).foregroundStyle(trailingColor)
            }
        }
        .padding()
        .background(bgColor.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(bgColor.opacity(0.2), lineWidth: 1)
        )
    }
}

struct AdminProgressRow: View {
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().tint(color)
            Text(text).font(.subheadline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct AdminSearchResultRow: View {
    let user: (id: String, username: String, totalCards: Int)
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(user.username.prefix(1)).uppercased())
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.username).font(.headline).foregroundStyle(.white)
                    Text("\(user.totalCards) cards").font(.caption).foregroundStyle(.gray)
                }
                
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.gray)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

struct AdminCardRow: View {
    let card: CloudCard
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: card.imageURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
                    .overlay(Image(systemName: "car.fill").foregroundStyle(.gray))
            }
            .frame(width: 80, height: 45)
            .clipped()
            .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(card.make) \(card.model)")
                    .font(.subheadline.bold()).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 8) {
                    Text(card.year).font(.caption).foregroundStyle(.gray)
                    Text(card.cardType).font(.caption).foregroundStyle(.orange)
                    Text(card.id.prefix(8) + "...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16)).foregroundStyle(.red)
                    .padding(8).background(.red.opacity(0.1)).clipShape(Circle())
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
    }
}

// MARK: - Alerts Modifier (keeps body clean)

struct AdminAlertsModifier: ViewModifier {
    @Binding var confirmDelete: CloudCard?
    @Binding var showSystemResetConfirm1: Bool
    @Binding var showSystemResetConfirm2: Bool
    @Binding var showH2HResetConfirm: Bool
    @Binding var showFeedResetConfirm: Bool
    let onRemoveCard: (CloudCard) -> Void
    let onSystemReset: () -> Void
    let onH2HReset: () -> Void
    let onFeedReset: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Remove Card?", isPresented: Binding(
                get: { confirmDelete != nil },
                set: { if !$0 { confirmDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { confirmDelete = nil }
                Button("Remove", role: .destructive) {
                    if let card = confirmDelete { onRemoveCard(card) }
                }
            } message: {
                Text(confirmDelete.map { "Permanently delete \($0.make) \($0.model)?" } ?? "")
            }
            .alert("⚠️ System-Wide Reset", isPresented: $showSystemResetConfirm1) {
                Button("Cancel", role: .cancel) {}
                Button("I understand, continue", role: .destructive) { showSystemResetConfirm2 = true }
            } message: {
                Text("DELETE ALL cards, activities, listings, races, follows, and reset ALL users' progress. Cannot be undone.")
            }
            .alert("🔴 FINAL CONFIRMATION", isPresented: $showSystemResetConfirm2) {
                Button("Cancel", role: .cancel) {}
                Button("WIPE EVERYTHING", role: .destructive) { onSystemReset() }
            } message: {
                Text("Last chance. Everything gone. Are you absolutely sure?")
            }
            .alert("Reset All Head-to-Head?", isPresented: $showH2HResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset H2H", role: .destructive) { onH2HReset() }
            } message: {
                Text("Deletes all races, cooldowns, votes, duo invites, and vote streaks.")
            }
            .alert("Reset Feed & Featured?", isPresented: $showFeedResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset Feed", role: .destructive) { onFeedReset() }
            } message: {
                Text("Deletes all activity posts, featured cards, and follows.")
            }
    }
}
