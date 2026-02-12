//
//  CardPreviewView.swift
//  Car Collector
//
//  Shows the saved card after AI identification
//  Tap anywhere to dismiss and return home
//

import SwiftUI

struct CardPreviewView: View {
    let cardImage: UIImage
    let make: String
    let model: String
    let generation: String
    let onWrongVehicle: (() -> Void)?  // NEW: Callback when user clicks "Not your vehicle?"
    @Environment(\.dismiss) private var dismiss
    
    @State private var allowDismiss = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                
                // Card preview (horizontal 16:9)
                Image(uiImage: cardImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 320, height: 180)
                    .cornerRadius(15)
                    .shadow(color: .white.opacity(0.3), radius: 10)
                
                // Car details
                VStack(spacing: 8) {
                    Text("\(make) \(model)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text(formatGeneration(generation))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                // Success message
                Text("Saved to Garage!")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.top, 20)
                
                // Continue button (replaces tap-anywhere)
                Button(action: {
                    if allowDismiss {
                        print("👆 User tapped Continue - dismissing preview")
                        dismiss()
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 200)
                        .padding()
                        .background(.green)
                        .cornerRadius(12)
                }
                .opacity(allowDismiss ? 1.0 : 0.5)
                .disabled(!allowDismiss)
                
                Spacer()
            }
            .zIndex(0)  // Main content layer
            
            // NEW: "Not your vehicle?" button in top-right corner
            if let onWrongVehicle = onWrongVehicle {
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            print("⚠️ User clicked 'Not your vehicle?' - fetching alternatives...")
                            dismiss()  // Dismiss preview first
                            onWrongVehicle()  // Then trigger alternative fetch
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text("Not your vehicle?")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.orange.opacity(0.9))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.3), radius: 5)
                        }
                        .padding()
                    }
                    Spacer()
                }
                .zIndex(1)  // Raise above tap gesture layer
            }
        }
        .onAppear {
            print("ðŸ“± CardPreviewView appeared")
            print("   - Make: \(make)")
            print("   - Model: \(model)")
            print("   - Generation: \(generation)")
            print("   - Image size: \(cardImage.size)")
            
            OrientationManager.lockOrientation(.portrait)
            
            // Wait 1.5 seconds before allowing dismiss
            // Prevents accidental taps and lets user see the card
            print("â±ï¸ Starting 1.5 second delay...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    print("âœ… Delay complete - taps now allowed")
                    allowDismiss = true
                }
            }
        }
        .onDisappear {
            print("ðŸ‘‹ CardPreviewView disappeared")
            OrientationManager.unlockOrientation()
        }
    }
    
    private func formatGeneration(_ gen: String) -> String {
        // If it's already a generation name (contains letters), return as-is
        if gen.contains(where: { $0.isLetter }) {
            return gen
        }
        
        // Otherwise it's years - convert "15-18" to "2015-2018" for display
        if gen.contains("-") {
            let parts = gen.split(separator: "-")
            if parts.count == 2,
               let start = Int(parts[0]),
               let end = Int(parts[1]) {
                let prefix = start > 50 ? "19" : "20"
                return "\(prefix)\(String(format: "%02d", start))-\(prefix)\(String(format: "%02d", end))"
            }
        } else if let year = Int(gen) {
            let prefix = year > 50 ? "19" : "20"
            return "\(prefix)\(String(format: "%02d", year))"
        }
        return gen
    }
}
