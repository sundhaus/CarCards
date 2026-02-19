//
//  VehicleSelectionView.swift
//  Car-Collector
//
//  Selection screen showing 3 AI identification options
//  User taps the correct match to confirm
//

import SwiftUI

struct VehicleSelectionView: View {
    let cardImage: UIImage
    let options: [VehicleIdentification]
    let onSelect: (VehicleIdentification) -> Void
    let onRetry: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Which car is this?")
                        .font(.pTitle2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Tap the correct match")
                        .font(.pSubheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 50)
                .padding(.bottom, 30)
                
                // 3 Option Cards
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                            OptionCard(
                                image: cardImage,
                                option: option,
                                rank: index + 1,
                                onTap: {
                                    onSelect(option)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                Spacer()
            }
            
            // Bottom buttons with gradient
            ZStack(alignment: .bottom) {
                // Gradient background - full width, bottom aligned
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                }
                .ignoresSafeArea()  // Extend to all edges
                
                // Button on top of gradient
                HStack(spacing: 15) {
                    // None of these button
                    Button(action: onRetry) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("None of these")
                        }
                        .font(.pHeadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(.gray.opacity(0.3))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

struct OptionCard: View {
    let image: UIImage
    let option: VehicleIdentification
    let rank: Int
    let onTap: () -> Void
    
    var confidenceColor: Color {
        switch option.confidence?.lowercased() ?? "unknown" {
        case "high": return .green
        case "medium": return .orange
        case "low": return .red
        default: return .gray
        }
    }
    
    var confidenceBadge: String {
        switch option.confidence?.lowercased() ?? "unknown" {
        case "high": return "High Match"
        case "medium": return "Medium Match"
        case "low": return "Low Match"
        default: return "Unknown"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Mini card preview
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(12)
                    
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.7))
                            .frame(width: 32, height: 32)
                        
                        Text("\(rank)")
                            .font(.pHeadline)
                            .foregroundStyle(.white)
                    }
                    .padding(10)
                }
                
                // Info section
                VStack(alignment: .leading, spacing: 8) {
                    // Make & Model
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.make)
                                .font(.pHeadline)
                                .foregroundStyle(.white)
                            
                            Text(option.model)
                                .font(.pTitle3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        
                        Spacer()
                        
                        // Confidence badge
                        Text(confidenceBadge)
                            .font(.pCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(confidenceColor.opacity(0.8))
                            .cornerRadius(8)
                    }
                    
                    // Generation
                    if !option.generation.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.pCaption)
                            Text(option.generation)
                                .font(.pSubheadline)
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.gray.opacity(0.2))
            }
            .background(.gray.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// Button style that scales on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    VehicleSelectionView(
        cardImage: UIImage(systemName: "car.fill")!,
        options: [
            VehicleIdentification(make: "Mitsubishi", model: "Lancer Evolution", generation: "Evo IX", confidence: "high"),
            VehicleIdentification(make: "Mitsubishi", model: "Lancer Evolution", generation: "Evo VIII", confidence: "medium"),
            VehicleIdentification(make: "Mitsubishi", model: "Lancer", generation: "2004-2007", confidence: "low")
        ],
        onSelect: { _ in },
        onRetry: {}
    )
}
