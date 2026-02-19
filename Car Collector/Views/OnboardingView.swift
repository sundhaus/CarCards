//
//  OnboardingView.swift
//  CarCardCollector
//
//  First-launch username picker with silent anonymous auth
//  No login screen — just pick a name and play
//  Real-time username availability checking
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var firebaseManager = FirebaseManager.shared
    let onComplete: () -> Void
    
    @State private var username = ""
    @State private var isChecking = false
    @State private var isAvailable: Bool? = nil  // nil = not checked yet
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var animateIn = false
    @State private var checkTask: Task<Void, Never>?
    
    private var isValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.count <= 20
    }
    
    /// Can only proceed if username is valid AND confirmed available
    private var canProceed: Bool {
        isValid && isAvailable == true && !isChecking
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.15),
                    Color(red: 0.1, green: 0.15, blue: 0.25),
                    Color(red: 0.05, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // App icon / logo area
                VStack(spacing: 16) {
                    Image(systemName: "car.fill")
                        .font(.poppins(70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animateIn ? 1.0 : 0.5)
                        .opacity(animateIn ? 1.0 : 0.0)
                    
                    Text("Car Card Collector")
                        .font(.poppins(32))
                        .foregroundStyle(.white)
                        .opacity(animateIn ? 1.0 : 0.0)
                }
                .padding(.bottom, 50)
                
                // Username input
                VStack(spacing: 16) {
                    Text("Choose your name")
                        .font(.pTitle3)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    VStack(spacing: 8) {
                        HStack {
                            TextField("", text: $username, prompt: Text("Enter username").foregroundStyle(.white.opacity(0.4)))
                                .font(.poppins(22))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: username) { _, _ in
                                    errorMessage = nil
                                    isAvailable = nil
                                    checkUsernameDebounced()
                                }
                            
                            // Availability indicator
                            if isValid {
                                if isChecking {
                                    ProgressView()
                                        .tint(.white.opacity(0.6))
                                        .scaleEffect(0.8)
                                } else if let available = isAvailable {
                                    Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(available ? .green : .red)
                                        .font(.pTitle3)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(availabilityBorderColor, lineWidth: 1)
                                )
                        )
                        
                        // Status text
                        HStack {
                            // Availability message
                            if isValid {
                                if isChecking {
                                    Text("Checking availability...")
                                        .font(.pCaption)
                                        .foregroundStyle(.white.opacity(0.5))
                                } else if let available = isAvailable {
                                    Text(available ? "Username available!" : "Username already taken")
                                        .font(.pCaption)
                                        .foregroundStyle(available ? .green : .red)
                                        .transition(.opacity)
                                }
                            }
                            
                            Spacer()
                            
                            // Character count
                            Text("\(username.count)/20")
                                .font(.pCaption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.pCaption)
                                .foregroundStyle(.red)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .opacity(animateIn ? 1.0 : 0.0)
                .offset(y: animateIn ? 0 : 20)
                
                Spacer()
                
                // Start button
                Button(action: createAccount) {
                    Group {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Let's Go")
                                .font(.poppins(20))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                canProceed
                                    ? LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
                .disabled(!canProceed || isCreating)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .opacity(animateIn ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateIn = true
            }
        }
    }
    
    // MARK: - Border Color Based on Availability
    
    private var availabilityBorderColor: Color {
        guard isValid else {
            return .white.opacity(0.2)
        }
        if isChecking {
            return .white.opacity(0.3)
        }
        if let available = isAvailable {
            return available ? .green.opacity(0.5) : .red.opacity(0.5)
        }
        return .white.opacity(0.2)
    }
    
    // MARK: - Debounced Username Check
    
    private func checkUsernameDebounced() {
        // Cancel any in-flight check
        checkTask?.cancel()
        isAvailable = nil
        
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        guard trimmed.count >= 3 else {
            isChecking = false
            return
        }
        
        isChecking = true
        
        checkTask = Task {
            // Debounce: wait 400ms before checking
            try? await Task.sleep(nanoseconds: 400_000_000)
            
            guard !Task.isCancelled else { return }
            
            do {
                let taken = try await UserService.shared.isUsernameTaken(trimmed)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAvailable = !taken
                        isChecking = false
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isChecking = false
                }
            }
        }
    }
    
    // MARK: - Create Account
    
    private func createAccount() {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        guard canProceed else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Sign in anonymously (silent — no UI)
                try await firebaseManager.signInAnonymously()
                
                guard let uid = firebaseManager.currentUserId else {
                    throw FirebaseError.notAuthenticated
                }
                
                // 2. Double-check username is still available (race condition guard)
                let taken = try await UserService.shared.isUsernameTaken(trimmed)
                if taken {
                    await MainActor.run {
                        errorMessage = "Username was just taken — try another"
                        isAvailable = false
                        isCreating = false
                    }
                    return
                }
                
                // 3. Create user profile + reserve username atomically
                try await UserService.shared.createProfile(uid: uid, username: trimmed)
                
                // 4. Mark onboarding complete locally
                UserDefaults.standard.set(true, forKey: "onboardingComplete")
                
                await MainActor.run {
                    isCreating = false
                    onComplete()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
