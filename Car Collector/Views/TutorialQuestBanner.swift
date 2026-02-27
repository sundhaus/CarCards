//
//  TutorialQuestBanner.swift
//  Car Collector
//
//  Compact tutorial quest checklist that appears on the Home tab
//  for new users who have completed their first capture but haven't
//  finished all 3 tutorial quests yet.
//
//  Shows:  ☑ Capture 3 cars (1/3)  ☐ Enter a battle  ☐ Follow a friend
//
//  Tapping a quest navigates to the relevant section of the app.
//

import SwiftUI

struct TutorialQuestBanner: View {
    @ObservedObject private var tutorialService = TutorialQuestService.shared
    let onNavigate: (Int, String?) -> Void  // (tabIndex, navigationAction)
    
    @State private var showConfetti = false
    @State private var animateIn = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DeviceScale.h(10)) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .foregroundStyle(.cyan)
                    .font(.system(size: 16))
                
                Text("GETTING STARTED")
                    .font(.poppins(14))
                    .foregroundStyle(.white.opacity(0.8))
                
                Spacer()
                
                // Progress indicator
                Text("\(tutorialService.completedCount)/\(tutorialService.totalCount)")
                    .font(.poppins(12))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(8)
            }
            
            // Quest rows
            ForEach(tutorialService.quests) { quest in
                Button(action: {
                    if !quest.isComplete {
                        if let tab = quest.destinationTab {
                            onNavigate(tab, quest.navigationAction)
                        }
                    }
                }) {
                    questRow(quest)
                }
                .buttonStyle(.plain)
                .disabled(quest.isComplete)
            }
            
            // Overall progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * overallProgress,
                            height: 4
                        )
                        .animation(.easeInOut(duration: 0.5), value: overallProgress)
                }
            }
            .frame(height: 4)
            .padding(.top, 4)
        }
        .padding(DeviceScale.w(14))
        .solidGlass(cornerRadius: 14)
        .padding(.horizontal)
        .opacity(animateIn ? 1.0 : 0.0)
        .offset(y: animateIn ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                animateIn = true
            }
        }
    }
    
    // MARK: - Quest Row
    
    private func questRow(_ quest: TutorialQuest) -> some View {
        HStack(spacing: 12) {
            // Completion indicator
            ZStack {
                Circle()
                    .fill(quest.isComplete ? Color.green : Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                if quest.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: quest.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            // Quest info
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title)
                    .font(.poppins(13))
                    .foregroundStyle(quest.isComplete ? .white.opacity(0.5) : .white)
                    .strikethrough(quest.isComplete, color: .white.opacity(0.3))
                
                if !quest.isComplete {
                    Text(quest.description)
                        .font(.poppins(11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Progress or completion
            if quest.isComplete {
                Text("Done")
                    .font(.poppins(11))
                    .foregroundStyle(.green)
            } else if quest.target > 1 {
                Text("\(quest.progress)/\(quest.target)")
                    .font(.poppins(12))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helpers
    
    private var overallProgress: Double {
        guard tutorialService.totalCount > 0 else { return 0 }
        let totalProgress = tutorialService.quests.reduce(0.0) { sum, quest in
            sum + quest.progressFraction
        }
        return totalProgress / Double(tutorialService.totalCount)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TutorialQuestBanner(onNavigate: { _, _ in })
    }
}
