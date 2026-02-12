//
//  OnboardingView.swift
//  CarCardCollector
//
//  First-launch username picker with silent anonymous auth
//  No login screen — just pick a name and play
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var firebaseManager = FirebaseManager.shared
    let onComplete: () -> Void
    
    @State private var username = ""
    @State private var isChecking = false
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var animateIn = false
    
    private var isValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.count <= 20
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
                        .font(.system(size: 70))
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
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(animateIn ? 1.0 : 0.0)
                }
                .padding(.bottom, 50)
                
                // Username input
                VStack(spacing: 16) {
                    Text("Choose your name")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    VStack(spacing: 8) {
                        TextField("", text: $username, prompt: Text("Enter username").foregroundStyle(.white.opacity(0.4)))
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: username) { _, _ in
                                errorMessage = nil
                            }
                        
                        // Character count
                        Text("\(username.count)/20")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                        
                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
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
                                .font(.system(size: 20, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                isValid
                                    ? LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
                .disabled(!isValid || isCreating)
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
    
    private func createAccount() {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        
        guard isValid else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Sign in anonymously (silent — no UI)
                try await firebaseManager.signInAnonymously()
                
                guard let uid = firebaseManager.currentUserId else {
                    throw FirebaseError.notAuthenticated
                }
                
                // 2. Check if username is taken
                let taken = try await UserService.shared.isUsernameTaken(trimmed)
                if taken {
                    await MainActor.run {
                        errorMessage = "Username already taken"
                        isCreating = false
                    }
                    return
                }
                
                // 3. Create user profile in Firestore
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
