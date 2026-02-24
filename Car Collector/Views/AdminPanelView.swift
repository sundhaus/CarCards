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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
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
                    
                    if let status = statusMessage {
                        Text(status)
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // System Reset Button (danger zone)
                            VStack(spacing: 12) {
                                if isResetting {
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .tint(.red)
                                            .scaleEffect(1.5)
                                        Text("Wiping all data...")
                                            .font(.headline)
                                            .foregroundStyle(.red)
                                        Text("Do not close the app")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                                } else {
                                    Button(action: {
                                        showSystemResetConfirm1 = true
                                    }) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(.yellow)
                                            Text("SYSTEM-WIDE RESET")
                                                .font(.headline.bold())
                                                .foregroundStyle(.red)
                                            Spacer()
                                            Image(systemName: "trash.fill")
                                                .foregroundStyle(.red)
                                        }
                                        .padding()
                                        .background(.red.opacity(0.1))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.red.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
                            
                            Divider().background(.white.opacity(0.2)).padding(.horizontal)
                            
                            // H2H Reset Button
                            VStack(spacing: 12) {
                                if isResettingH2H {
                                    HStack(spacing: 12) {
                                        ProgressView().tint(.orange)
                                        Text("Clearing H2H data...")
                                            .font(.subheadline)
                                            .foregroundStyle(.orange)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                } else {
                                    Button(action: {
                                        showH2HResetConfirm = true
                                    }) {
                                        HStack {
                                            Image(systemName: "flag.checkered")
                                                .foregroundStyle(.orange)
                                            Text("Reset All Head-to-Head")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.orange)
                                            Spacer()
                                            Text("Races · Cooldowns · Votes")
                                                .font(.caption2)
                                                .foregroundStyle(.gray)
                                        }
                                        .padding()
                                        .background(.orange.opacity(0.08))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.orange.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            Divider().background(.white.opacity(0.2)).padding(.horizontal)

                            if let user = selectedUser {
                                // User card list
                                userCardSection(userId: user.id, username: user.username)
                            } else {
                                // Search results
                                searchResultsList
                            }
                        }
                    }
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Remove Card?", isPresented: .init(
                get: { confirmDelete != nil },
                set: { if !$0 { confirmDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { confirmDelete = nil }
                Button("Remove", role: .destructive) {
                    if let card = confirmDelete {
                        removeCard(card)
                    }
                }
            } message: {
                if let card = confirmDelete {
                    Text("This will permanently delete \(card.make) \(card.model) and remove it from all feeds, listings, and races. This cannot be undone.")
                }
            }
            // System-wide reset — confirmation 1
            .alert("⚠️ System-Wide Reset", isPresented: $showSystemResetConfirm1) {
                Button("Cancel", role: .cancel) {}
                Button("I understand, continue", role: .destructive) {
                    showSystemResetConfirm2 = true
                }
            } message: {
                Text("This will DELETE ALL cards, activities, listings, races, follows, and reset ALL users' coins, levels, and XP to zero. Only accounts will be preserved.\n\nThis affects EVERY user. This cannot be undone.")
            }
            // System-wide reset — confirmation 2 (final)
            .alert("🔴 FINAL CONFIRMATION", isPresented: $showSystemResetConfirm2) {
                Button("Cancel", role: .cancel) {}
                Button("WIPE EVERYTHING", role: .destructive) {
                    performSystemReset()
                }
            } message: {
                Text("Last chance. Every card, every listing, every race, every follow — gone. All progress reset to zero. Are you absolutely sure?")
            }
            // H2H reset confirmation
            .alert("Reset All Head-to-Head?", isPresented: $showH2HResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset H2H", role: .destructive) {
                    performH2HReset()
                }
            } message: {
                Text("This will delete all races, cooldowns, votes, duo invites, and vote streaks. All cards (including A-Z sim cards) will be freed to race again.")
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsList: some View {
        Group {
            if isSearching {
                ProgressView().tint(.white).padding(40)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Text("No users found")
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(40)
            } else {
                ForEach(searchResults, id: \.id) { user in
                    Button {
                        selectedUser = (id: user.id, username: user.username)
                        loadUserCards(userId: user.id)
                    } label: {
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
                                Text(user.username)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(user.totalCards) cards")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.gray)
                        }
                        .padding()
                    }
                    .buttonStyle(.plain)
                    
                    Divider().background(.white.opacity(0.1))
                }
            }
        }
    }
    
    // MARK: - User Card Section
    
    private func userCardSection(userId: String, username: String) -> some View {
        VStack(spacing: 0) {
            // Back to search
            Button {
                selectedUser = nil
                userCards = []
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
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            if isLoadingCards {
                ProgressView().tint(.white).padding(40)
            } else if userCards.isEmpty {
                Text("No cards found")
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(40)
            } else {
                ForEach(userCards) { card in
                    adminCardRow(card: card)
                    Divider().background(.white.opacity(0.1))
                }
            }
        }
    }
    
    // MARK: - Card Row
    
    private func adminCardRow(card: CloudCard) -> some View {
        HStack(spacing: 12) {
            // Card thumbnail
            AsyncImage(url: URL(string: card.imageURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.gray.opacity(0.3))
                    .overlay(Image(systemName: "car.fill").foregroundStyle(.gray))
            }
            .frame(width: 80, height: 45)
            .clipped()
            .cornerRadius(6)
            
            // Card info
            VStack(alignment: .leading, spacing: 2) {
                Text("\(card.make) \(card.model)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(card.year)
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(card.cardType)
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(card.id.prefix(8) + "...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Remove button
            Button {
                confirmDelete = card
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Actions
    
    private func searchUsers() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        
        Task {
            do {
                searchResults = try await adminService.searchUsers(query: searchText)
            } catch {
                print("❌ Search failed: \(error)")
            }
            isSearching = false
        }
    }
    
    private func loadUserCards(userId: String) {
        isLoadingCards = true
        
        Task {
            do {
                userCards = try await adminService.fetchUserCards(userId: userId)
            } catch {
                print("❌ Failed to load cards: \(error)")
            }
            isLoadingCards = false
        }
    }
    
    private func removeCard(_ card: CloudCard) {
        Task {
            do {
                try await adminService.removeCard(cardId: card.id, ownerId: card.ownerId)
                
                // Remove from local list
                userCards.removeAll { $0.id == card.id }
                
                withAnimation {
                    statusMessage = "✅ Removed \(card.make) \(card.model)"
                }
                
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { statusMessage = nil }
            } catch {
                withAnimation {
                    statusMessage = "❌ Error: \(error.localizedDescription)"
                }
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
                    isResetting = false
                    searchResults = []
                    userCards = []
                    selectedUser = nil
                    
                    withAnimation {
                        statusMessage = "✅ SYSTEM RESET COMPLETE — Restart the app"
                    }
                }
            } catch {
                await MainActor.run {
                    isResetting = false
                    withAnimation {
                        statusMessage = "❌ Reset failed: \(error.localizedDescription)"
                    }
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
                
                await MainActor.run {
                    isResettingH2H = false
                    withAnimation {
                        statusMessage = "✅ H2H Reset — all cards freed"
                    }
                }
                
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    withAnimation { statusMessage = nil }
                }
            } catch {
                await MainActor.run {
                    isResettingH2H = false
                    withAnimation {
                        statusMessage = "❌ H2H reset failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
