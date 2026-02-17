//
//  LevelHeader.swift
//  CarCardCollector
//
//  Header showing user level, profile picture, and username
//

import SwiftUI

struct LevelHeader: View {
    @ObservedObject var levelSystem: LevelSystem
    var isLandscape: Bool
    var totalCards: Int
    @Binding var showProfile: Bool
    
    @State private var profileImage: UIImage?
    @ObservedObject private var userService = UserService.shared
    
    private var username: String {
        userService.currentProfile?.username ?? "Player"
    }
    
    private var profilePictureURL: String? {
        userService.currentProfile?.profilePictureURL
    }
    
    // Generate gradient colors based on level (cycles through spectrum every 80 levels)
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
        if isLandscape {
            // Landscape: Split into corners
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    // Profile section in top left
                    profileSection
                        .padding(.leading, 16)
                        .padding(.top, 8)
                    
                    Spacer()
                    
                    // Coins in top right (stop before hub)
                    coinsSection
                        .padding(.trailing, 110) // Space for hub
                        .padding(.top, 8)
                }
                Spacer()
            }
        } else {
            // Portrait: Single bar across top
            VStack(spacing: 0) {
                Spacer()
                
                HStack(spacing: 12) {
                    // Profile section with picture and username
                    profileSectionCompact
                    
                    Spacer()
                    
                    // Coins section
                    coinsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .frame(height: 60)
            .background(
                Rectangle()
                    .fill(Color.headerBackground)
                    .ignoresSafeArea(edges: .top)
            )
            .frame(maxWidth: .infinity)
        }
    }
    
    // Compact profile section for portrait mode
    private var profileSectionCompact: some View {
        Button(action: {
            withAnimation {
                showProfile = true
            }
        }) {
            HStack(spacing: 10) {
                // Profile picture with progress ring (no level badge overlay)
                ZStack {
                    // Background circle for ring
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)
                        .frame(width: 52, height: 52)
                    
                    // Progress ring (fills clockwise)
                    Circle()
                        .trim(from: 0, to: levelSystem.progress)
                        .stroke(
                            LinearGradient(
                                colors: levelGradient(for: levelSystem.level),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90)) // Start at top
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: levelSystem.progress)
                    
                    // Profile picture or placeholder
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: levelGradient(for: levelSystem.level),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                
                // Username
                Text(username)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                // Level badge to the right of username
                levelBadge(size: 28)
            }
        }
        .buttonStyle(.plain)
        .task {
            await loadProfilePicture()
        }
        .onChange(of: profilePictureURL) { oldValue, newValue in
            // Reload image whenever URL changes
            if oldValue != newValue {
                Task {
                    await loadProfilePicture()
                }
            }
        }
    }
    
    // Profile section for landscape mode
    private var profileSection: some View {
        Button(action: {
            withAnimation {
                showProfile = true
            }
        }) {
            HStack(spacing: 10) {
                // Profile picture with progress ring (no level badge overlay)
                ZStack {
                    // Background circle for ring
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 4)
                        .frame(width: 52, height: 52)
                    
                    // Progress ring (fills clockwise)
                    Circle()
                        .trim(from: 0, to: levelSystem.progress)
                        .stroke(
                            LinearGradient(
                                colors: levelGradient(for: levelSystem.level),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90)) // Start at top
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: levelSystem.progress)
                    
                    // Profile picture or placeholder
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: levelGradient(for: levelSystem.level),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                
                // Username
                Text(username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                // Level badge to the right of username
                levelBadge(size: 28)
            }
            .padding(8)
            .background(Color.headerBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .task {
            await loadProfilePicture()
        }
        .onChange(of: profilePictureURL) { oldValue, newValue in
            // Reload image whenever URL changes
            if oldValue != newValue {
                Task {
                    await loadProfilePicture()
                }
            }
        }
    }
    
    // Level badge with shape based on level
    private func levelBadge(size: CGFloat) -> some View {
        let gradient = LinearGradient(
            colors: levelGradient(for: levelSystem.level),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        return ZStack {
            // Shape background - apply fill before wrapping in AnyView
            Group {
                let adjustedLevel = ((levelSystem.level - 1) % 100) + 1
                
                switch adjustedLevel {
                case 1...10:
                    Circle()
                        .fill(gradient)
                case 11...20:
                    TriangleShape()
                        .fill(gradient)
                case 21...30:
                    Rectangle()
                        .fill(gradient)
                case 31...40:
                    PentagonShape()
                        .fill(gradient)
                case 41...50:
                    HexagonShape()
                        .fill(gradient)
                case 51...60:
                    Circle()
                        .fill(gradient)
                case 61...70:
                    TriangleShape()
                        .rotation(Angle(degrees: 180))
                        .fill(gradient)
                case 71...80:
                    DiamondShape()
                        .fill(gradient)
                case 81...90:
                    PentagonShape()
                        .rotation(Angle(degrees: 180))
                        .fill(gradient)
                case 91...100:
                    HexagonShape()
                        .rotation(Angle(degrees: 30))
                        .fill(gradient)
                default:
                    Circle()
                        .fill(gradient)
                }
            }
            .frame(width: size, height: size)
            
            // Level number
            Text("\(levelSystem.level)")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    // Coins section (reusable)
    private var coinsSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.yellow)
            
            Text("\(levelSystem.coins)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
    
    // Load profile picture
    private func loadProfilePicture() async {
        guard let urlString = profilePictureURL, !urlString.isEmpty else {
            await MainActor.run {
                profileImage = nil
            }
            return
        }
        
        do {
            let image = try await CardService.shared.loadImage(from: urlString)
            await MainActor.run {
                profileImage = image
            }
            print("✅ Loaded profile picture in header")
        } catch {
            print("❌ Failed to load profile picture in header: \(error)")
            await MainActor.run {
                profileImage = nil
            }
        }
    }
}

// MARK: - Custom Shapes

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct PentagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        for i in 0..<5 {
            let angle = (Double(i) * 2.0 * .pi / 5.0) - (.pi / 2.0)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        for i in 0..<6 {
            let angle = (Double(i) * 2.0 * .pi / 6.0) - (.pi / 2.0)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack {
        LevelHeader(levelSystem: LevelSystem(), isLandscape: false, totalCards: 0, showProfile: .constant(false))
        Spacer()
    }
}
