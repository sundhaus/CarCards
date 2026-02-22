//
//  ProfileView.swift
//  CarCardCollector
//
//  User profile popup – now powered by Firebase
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseFirestore

struct ProfileView: View {
    @Binding var isShowing: Bool
    @ObservedObject var levelSystem: LevelSystem
    var totalCards: Int
    
    @State private var showImagePicker = false
    @State private var showImageSourceSheet = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var profileImage: UIImage?
    @State private var isUploadingImage = false
    @State private var showOwnProfile = false
    @State private var currentNonce: String?
    @State private var showAppleSignInError = false
    @State private var appleSignInErrorMessage = ""
    
    // Pull from Firebase
    private var username: String {
        UserService.shared.currentProfile?.username ?? "Unknown"
    }
    
    private var accountCreationDate: Date {
        UserService.shared.currentProfile?.createdAt ?? Date()
    }
    
    private var isAnonymous: Bool {
        FirebaseManager.shared.isAnonymous
    }
    
    private var profilePictureURL: String? {
        UserService.shared.currentProfile?.profilePictureURL
    }
    
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
        
        let cycleLength = 80 // 10 levels per color * 8 color transitions
        let position = (level - 1) % cycleLength
        let segmentLength = 10
        let colorIndex = position / segmentLength
        
        let startColor = colors[colorIndex]
        let endColor = colors[colorIndex + 1]
        
        return [startColor, endColor]
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }
            
            // Profile card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("PROFILE")
                        .font(.pTitle2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.pTitle2)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect)
                
                // Profile content
                VStack(spacing: 24) {
                    // Profile picture placeholder
                    Button(action: {
                        showImageSourceSheet = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: levelGradient(for: levelSystem.level),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.poppins(40))
                                    .foregroundStyle(.white)
                            }
                            
                            if isUploadingImage {
                                Circle()
                                    .fill(.black.opacity(0.5))
                                    .frame(width: 80, height: 80)
                                
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    
                    // Username — tap to view public profile
                    VStack(spacing: 4) {
                        Button(action: {
                            showOwnProfile = true
                        }) {
                            HStack(spacing: 6) {
                                Text(username)
                                    .font(.pTitle2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Text("Level \(levelSystem.level)")
                            .font(.pSubheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // XP Progress bar
                    VStack(spacing: 8) {
                        // XP fraction
                        Text("\(levelSystem.currentXP) / \(levelSystem.xpForNextLevel) XP")
                            .font(.pCaption)
                            .foregroundStyle(.secondary)
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 12)
                                
                                // Progress fill
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: levelGradient(for: levelSystem.level),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * levelSystem.progress, height: 12)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: levelSystem.progress)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding(.horizontal, 24)
                    
                    // Stats - simple list format
                    VStack(spacing: 12) {
                        HStack {
                            Text("TOTAL XP EARNED:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(levelSystem.totalXP)")
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("CARDS COLLECTED:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(totalCards)")
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("COINS:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(.yellow)
                                Text("\(levelSystem.coins)")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Account creation date
                    VStack(spacing: 4) {
                        Text("MEMBER SINCE")
                            .font(.pCaption)
                            .foregroundStyle(.secondary)
                        Text(accountCreationDate, style: .date)
                            .font(.pSubheadline)
                            .fontWeight(.medium)
                    }
                    
                    // Account linking prompt (for anonymous users)
                    if isAnonymous {
                        VStack(spacing: 8) {
                            Divider()
                                .padding(.horizontal)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.shield")
                                    .font(.pTitle3)
                                    .foregroundStyle(.orange)
                                
                                Text("Account not backed up")
                                    .font(.pCaption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.orange)
                                
                                Text("Sign in with Apple to save your progress across devices")
                                    .font(.pCaption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal)
                            
                            // Apple Sign-In button
                            SignInWithAppleButton(.signIn) { request in
                                let nonce = randomNonceString()
                                currentNonce = nonce
                                request.requestedScopes = [.email]
                                request.nonce = sha256(nonce)
                            } onCompletion: { result in
                                switch result {
                                case .success(let auth):
                                    handleAppleSignIn(auth)
                                case .failure(let error):
                                    print("❌ Apple Sign-In failed: \(error)")
                                    appleSignInErrorMessage = error.localizedDescription
                                    showAppleSignInError = true
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 44)
                            .cornerRadius(10)
                            .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(width: 320)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 20)
        }
        .confirmationDialog("Change Profile Picture", isPresented: $showImageSourceSheet) {
            Button("Take Photo") {
                imageSourceType = .camera
                showImagePicker = true
            }
            Button("Choose from Library") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: imageSourceType)
        }
        .fullScreenCover(isPresented: $showOwnProfile) {
            if let uid = UserService.shared.currentProfile?.id {
                NavigationStack {
                    UserProfileView(userId: uid, username: username)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: { showOwnProfile = false }) {
                                    Image(systemName: "xmark")
                                        .font(.pBody)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                }
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            guard let image = newImage,
                  let uid = FirebaseManager.shared.currentUserId else { return }
            
            profileImage = image
            isUploadingImage = true
            
            Task {
                do {
                    _ = try await UserService.shared.uploadProfilePicture(uid: uid, image: image)
                    await MainActor.run {
                        isUploadingImage = false
                    }
                } catch {
                    print("❌ Profile picture upload failed: \(error)")
                    await MainActor.run {
                        isUploadingImage = false
                    }
                }
            }
        }
        .alert("Sign In Error", isPresented: $showAppleSignInError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appleSignInErrorMessage)
        }
        .task {
            // Load existing profile picture
            guard let urlString = profilePictureURL else { return }
            
            do {
                let image = try await CardService.shared.loadImage(from: urlString)
                await MainActor.run {
                    profileImage = image
                }
            } catch {
                print("❌ Failed to load profile picture: \(error)")
            }
        }
    }
    
    // MARK: - Apple Sign-In
    
    private func handleAppleSignIn(_ authorization: ASAuthorization) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let idTokenData = appleCredential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8),
              let nonce = currentNonce else {
            appleSignInErrorMessage = "Failed to get Apple credentials"
            showAppleSignInError = true
            return
        }
        
        Task {
            do {
                try await FirebaseManager.shared.linkWithApple(idToken: idToken, nonce: nonce)
                
                // Update profile to mark as linked
                UserService.shared.currentProfile?.linkedAccount = true
                if let uid = FirebaseManager.shared.currentUserId {
                    try? await Firestore.firestore().collection("users").document(uid).updateData([
                        "linkedAccount": true
                    ])
                }
                
                print("✅ Apple account linked successfully")
                
                // Refresh profile so UI updates immediately
                await UserService.shared.fetchProfile()
            } catch {
                appleSignInErrorMessage = error.localizedDescription
                showAppleSignInError = true
            }
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    ProfileView(
        isShowing: .constant(true),
        levelSystem: LevelSystem(),
        totalCards: 42
    )
}
