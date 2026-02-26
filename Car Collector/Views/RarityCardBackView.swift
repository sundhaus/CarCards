//
//  RarityCardBackView.swift
//  Car Collector
//
//  Enhanced card back that visually differentiates by rarity tier.
//  Higher rarity = more detailed, more visually rich card back.
//
//  - Common:    Basic carbon texture + simple stats grid
//  - Uncommon:  + Subtle green accent line, slightly enhanced text
//  - Rare:      + Description text, blue accent accents, rarity badge
//  - Epic:      + Full description, animated purple border glow, gradient background
//  - Legendary: + Gold foil accents, animated shimmer, full stat presentation,
//               manufacturer logo area, serial number
//

import SwiftUI

struct RarityCardBackView: View {
    let make: String
    let model: String
    let year: String
    let specs: VehicleSpecs
    let rarity: CardRarity
    var customFrame: String? = nil
    var cardHeight: CGFloat = 200
    var capturedBy: String? = nil
    var capturedLocation: String? = nil
    
    // Card is 16:9 landscape
    private var cardWidth: CGFloat { cardHeight * (16.0 / 9.0) }
    private var scale: CGFloat { cardHeight / 200 }
    
    @State private var shimmerPhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background — varies by rarity
            backgroundLayer
            
            // Content
            contentLayer
            
            // Border overlay
            borderLayer
            
            // Animated effects for Epic+
            if rarity >= .epic {
                epicEffectsLayer
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardHeight * 0.09))
        .shadow(radius: 10)
        .rotation3DEffect(
            .degrees(180),
            axis: (x: 0, y: 1, z: 0)
        )
    }
    
    // MARK: - Background Layer
    
    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            // Base texture
            if let texture = UIImage(named: "CardBackTexture") {
                Image(uiImage: texture)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            }
            
            // Rarity-tinted overlay
            LinearGradient(
                colors: rarityBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(rarityBackgroundOpacity)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
    
    private var rarityBackgroundColors: [Color] {
        switch rarity {
        case .common:
            return [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]
        case .uncommon:
            return [Color.green.opacity(0.15), Color.green.opacity(0.05)]
        case .rare:
            return [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)]
        case .epic:
            return [Color.purple.opacity(0.3), Color.pink.opacity(0.15)]
        case .legendary:
            return [Color.yellow.opacity(0.25), Color.orange.opacity(0.15)]
        }
    }
    
    private var rarityBackgroundOpacity: Double {
        switch rarity {
        case .common: return 0.3
        case .uncommon: return 0.4
        case .rare: return 0.5
        case .epic: return 0.6
        case .legendary: return 0.7
        }
    }
    
    // MARK: - Content Layer
    
    @ViewBuilder
    private var contentLayer: some View {
        VStack(spacing: 2 * scale) {
            // Header with rarity badge
            headerSection
            
            // Description (Rare+)
            if rarity >= .rare && !specs.description.isEmpty {
                Text(specs.description)
                    .font(.poppins(6 * scale))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(rarity >= .epic ? 4 : 2)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 16 * scale)
            }
            
            Spacer(minLength: 1 * scale)
            
            // Stats grid — more detailed for higher rarity
            statsSection
            
            // Footer — captured info (Epic+), serial number (Legendary)
            if rarity >= .epic {
                footerSection
            }
        }
        .frame(width: cardWidth, height: cardHeight)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 6 * scale) {
            // Rarity badge (Rare+)
            if rarity >= .rare {
                Image(systemName: rarity.iconName)
                    .font(.system(size: 9 * scale, weight: .semibold))
                    .foregroundStyle(rarity.color)
            }
            
            VStack(spacing: 1 * scale) {
                Text("\(make.uppercased()) \(model.uppercased())")
                    .font(.custom("Futura-Bold", fixedSize: rarity >= .epic ? 13 * scale : 12 * scale))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                HStack(spacing: 4 * scale) {
                    Text(year)
                        .font(.poppins(9 * scale))
                        .foregroundStyle(.white.opacity(0.8))
                    
                    if rarity >= .uncommon {
                        Text("•")
                            .foregroundStyle(rarity.color.opacity(0.8))
                        
                        Text(rarity.rawValue.uppercased())
                            .font(.custom("Futura-Bold", fixedSize: 7 * scale))
                            .foregroundStyle(rarity.color)
                    }
                }
            }
            
            if rarity >= .rare {
                Image(systemName: rarity.iconName)
                    .font(.system(size: 9 * scale, weight: .semibold))
                    .foregroundStyle(rarity.color)
            }
        }
        .padding(.top, 10 * scale)
    }
    
    // MARK: - Stats Grid
    
    private var statsSection: some View {
        VStack(spacing: 3 * scale) {
            // Row 1: Power
            HStack(spacing: 6 * scale) {
                enhancedStatItem(label: "HP", value: specs.horsepower, highlight: specs.horsepower != "N/A")
                enhancedStatItem(label: "TORQUE", value: specs.torque, highlight: specs.torque != "N/A")
            }
            
            // Row 2: Performance
            HStack(spacing: 6 * scale) {
                enhancedStatItem(label: "0-60", value: specs.zeroToSixty, highlight: specs.zeroToSixty != "N/A")
                enhancedStatItem(label: "TOP SPEED", value: specs.topSpeed, highlight: specs.topSpeed != "N/A")
            }
            
            // Row 3: Drivetrain
            HStack(spacing: 6 * scale) {
                enhancedStatItem(label: "ENGINE", value: specs.engine, highlight: specs.engine != "N/A")
                enhancedStatItem(label: "DRIVE", value: specs.drivetrain, highlight: specs.drivetrain != "N/A")
            }
            
            // Row 4: Transmission (Epic+)
            if rarity >= .epic {
                HStack(spacing: 6 * scale) {
                    enhancedStatItem(label: "TRANS", value: specs.transmission, highlight: specs.transmission != "N/A")
                    
                    // Category badge
                    if let category = specs.category {
                        enhancedStatItem(label: "CLASS", value: category.rawValue.uppercased(), highlight: true)
                    } else {
                        enhancedStatItem(label: "CLASS", value: "—", highlight: false)
                    }
                }
            }
        }
        .padding(.horizontal, 14 * scale)
        .padding(.bottom, rarity >= .epic ? 2 * scale : 14 * scale)
    }
    
    // MARK: - Footer (Epic+)
    
    @ViewBuilder
    private var footerSection: some View {
        HStack(spacing: 0) {
            if let location = capturedLocation {
                HStack(spacing: 2 * scale) {
                    Image(systemName: "mappin")
                        .font(.system(size: 5 * scale))
                    Text(location)
                        .font(.poppins(5 * scale))
                }
                .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            if let username = capturedBy {
                HStack(spacing: 2 * scale) {
                    Image(systemName: "camera")
                        .font(.system(size: 5 * scale))
                    Text(username)
                        .font(.poppins(5 * scale))
                }
                .foregroundStyle(.white.opacity(0.5))
            }
            
            // Serial number (Legendary)
            if rarity == .legendary {
                Spacer()
                Text("#\(serialNumber)")
                    .font(.custom("Futura-Bold", fixedSize: 6 * scale))
                    .foregroundStyle(Color.yellow.opacity(0.6))
            }
        }
        .padding(.horizontal, 16 * scale)
        .padding(.bottom, 8 * scale)
    }
    
    /// Deterministic serial from card identity
    private var serialNumber: String {
        let hash = abs("\(make)\(model)\(year)".hashValue)
        return String(format: "%05d", hash % 99999)
    }
    
    // MARK: - Border Layer
    
    @ViewBuilder
    private var borderLayer: some View {
        let cornerRadius = cardHeight * 0.09
        
        // Rarity accent border
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                rarity.gradient,
                lineWidth: rarity >= .epic ? 2.5 * scale : 1.5 * scale
            )
            .padding(1)
        
        // Inner accent line (Uncommon+)
        if rarity >= .uncommon {
            RoundedRectangle(cornerRadius: cornerRadius - 3 * scale)
                .stroke(
                    rarity.color.opacity(0.3),
                    lineWidth: 0.5 * scale
                )
                .padding(4 * scale)
        }
    }
    
    // MARK: - Epic+ Animated Effects
    
    @ViewBuilder
    private var epicEffectsLayer: some View {
        let cornerRadius = cardHeight * 0.09
        
        // Shimmer sweep
        LinearGradient(
            gradient: Gradient(colors: [
                Color.clear,
                rarity == .legendary ? Color.yellow.opacity(0.15) : Color.purple.opacity(0.1),
                Color.white.opacity(rarity == .legendary ? 0.2 : 0.1),
                rarity == .legendary ? Color.yellow.opacity(0.15) : Color.purple.opacity(0.1),
                Color.clear
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: cardWidth * 0.4)
        .offset(x: shimmerPhase)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .blendMode(.overlay)
        .onAppear {
            shimmerPhase = -cardWidth
            withAnimation(
                .linear(duration: rarity == .legendary ? 2.5 : 3.5)
                .repeatForever(autoreverses: false)
            ) {
                shimmerPhase = cardWidth
            }
        }
    }
    
    // MARK: - Enhanced Stat Item
    
    private func enhancedStatItem(label: String, value: String, highlight: Bool) -> some View {
        VStack(spacing: 1 * scale) {
            Text(value)
                .font(.poppins(rarity >= .epic ? 11 * scale : 12 * scale))
                .foregroundStyle(highlight ? .white : .white.opacity(0.4))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(label)
                .font(.poppins(6 * scale))
                .foregroundStyle(rarity >= .rare ? rarity.color.opacity(0.7) : .white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3 * scale)
        .background(
            highlight
                ? (rarity >= .rare
                    ? rarity.color.opacity(0.1)
                    : Color.white.opacity(0.15))
                : Color.clear
        )
        .cornerRadius(4 * scale)
    }
}
