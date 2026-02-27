//
//  LevelBadgeOverlay.swift
//  Car Collector
//
//  Prestige badge that appears on cards in Explore and social feeds
//  when the card's creator is Level 25+. Shows their level number
//  with a gold accent.
//

import SwiftUI

/// Small prestige badge overlaid on card thumbnails. Only shown
/// when the card's creator has reached Level 25 (prestige border unlock).
struct LevelBadgeOverlay: View {
    let level: Int
    
    /// Only render if the user qualifies for prestige.
    var showBadge: Bool {
        LevelGating.hasPrestigeBorder(at: level)
    }
    
    var body: some View {
        if showBadge {
            HStack(spacing: 3) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 8, weight: .bold))
                
                Text("\(level)")
                    .font(.poppins(9))
                    .fontWeight(.bold)
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.84, blue: 0.0),
                        Color(red: 0.85, green: 0.65, blue: 0.13)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.black.opacity(0.65))
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.6),
                                Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black
        
        VStack(spacing: 20) {
            // Level 25 — just unlocked
            LevelBadgeOverlay(level: 25)
            
            // Level 50 — veteran
            LevelBadgeOverlay(level: 50)
            
            // Level 100 — legend
            LevelBadgeOverlay(level: 100)
            
            // Level 10 — should not show
            LevelBadgeOverlay(level: 10)
        }
    }
}
