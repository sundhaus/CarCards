//
//  CategoryMigrationService.swift
//  CarCardCollector
//
//  Service to backfill vehicle categories for existing cards in Firestore
//  Run this once to add categories to all existing friend_activities
//

import Foundation
import FirebaseFirestore
import FirebaseAILogic

@MainActor
class CategoryMigrationService: ObservableObject {
    @Published var migrationProgress: String = ""
    @Published var isRunning = false
    @Published var totalCards = 0
    @Published var processedCards = 0
    @Published var categorizedCards = 0
    @Published var skippedCards = 0
    
    private let db = Firestore.firestore()
    private let ai: FirebaseAI
    private let model: GenerativeModel
    
    init() {
        ai = FirebaseAI.firebaseAI(backend: .googleAI())
        model = ai.generativeModel(modelName: "gemini-2.5-flash")
    }
    
    // Run migration for all cards without categories
    func migrateMissingCategories() async {
        guard !isRunning else {
            print("⚠️ Migration already running")
            return
        }
        
        isRunning = true
        migrationProgress = "Starting migration..."
        
        do {
            // Get all friend_activities without category field
            let snapshot = try await db.collection("friend_activities")
                .getDocuments()
            
            totalCards = snapshot.documents.count
            processedCards = 0
            categorizedCards = 0
            skippedCards = 0
            
            print("🔄 Found \(totalCards) total cards")
            migrationProgress = "Found \(totalCards) cards. Checking for missing categories..."
            
            // Process each card
            for document in snapshot.documents {
                let data = document.data()
                
                // Skip if already has category
                if let category = data["category"] as? String, !category.isEmpty {
                    skippedCards += 1
                    processedCards += 1
                    continue
                }
                
                // Get card info
                guard let make = data["cardMake"] as? String,
                      let model = data["cardModel"] as? String,
                      let year = data["cardYear"] as? String else {
                    skippedCards += 1
                    processedCards += 1
                    continue
                }
                
                // Determine category using AI
                migrationProgress = "Categorizing \(make) \(model) (\(processedCards + 1)/\(totalCards))..."
                
                if let category = await determineCategory(make: make, model: model, year: year) {
                    // Update document with category
                    try await document.reference.updateData([
                        "category": category.rawValue
                    ])
                    categorizedCards += 1
                    print("✅ \(make) \(model) → \(category.rawValue)")
                } else {
                    skippedCards += 1
                    print("⏭️ Skipped \(make) \(model) (couldn't determine category)")
                }
                
                processedCards += 1
                
                // Small delay to avoid rate limits
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            migrationProgress = "✅ Migration complete! Categorized: \(categorizedCards), Skipped: \(skippedCards)"
            print("✅ Migration complete!")
            print("   Categorized: \(categorizedCards)")
            print("   Already had category: \(totalCards - processedCards)")
            print("   Skipped: \(skippedCards)")
            
        } catch {
            migrationProgress = "❌ Error: \(error.localizedDescription)"
            print("❌ Migration failed: \(error)")
        }
        
        isRunning = false
    }
    
    // Determine category for a vehicle using AI
    private func determineCategory(make: String, model: String, year: String) async -> VehicleCategory? {
        let prompt = """
        Categorize this vehicle: \(year) \(make) \(model)
        
        Choose ONE category (exact match required):
        Hypercar, Supercar, Sports Car, Muscle, Track,
        Off-Road, Rally, SUV, Truck, Van,
        Luxury, Sedan, Coupe, Convertible, Wagon,
        Electric, Hybrid, Classic, Concept, Hatchback
        
        Rules:
        - Choose MOST SPECIFIC category
        - Hypercar: $1M+ supercars (Bugatti, Koenigsegg, Pagani)
        - Supercar: High-performance exotics (Ferrari, Lamborghini, McLaren)
        - Track: Track-focused variants (GT3, Cup, R, Track Pack)
        - Sports Car: Performance 2-doors (911, Corvette, Supra)
        - Muscle: American V8 coupes (Mustang, Camaro, Challenger)
        - Off-Road: Trail-capable (Bronco, Wrangler, 4Runner)
        - Rally: Rally-heritage (WRX, Evo, GR Yaris)
        - Electric: Battery EVs (Tesla, Taycan, Mach-E)
        - Hybrid: Gas+Electric (Prius, i8, NSX)
        - Classic: Pre-1995 or classic styling
        - Luxury: Premium sedans/coupes (S-Class, 7 Series, A8)
        
        Examples:
        - Bugatti Chiron → Hypercar
        - Ferrari 488 → Supercar
        - Porsche 911 GT3 → Track
        - Mazda MX-5 → Sports Car
        - Dodge Charger → Muscle
        - Toyota Camry → Sedan
        - Honda Civic → Sedan
        - Tesla Model 3 → Electric
        
        Return ONLY the category name, nothing else.
        """
        
        do {
            let response = try await self.model.generateContent(prompt)
            guard let text = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }
            
            // Try to match to a valid category
            return VehicleCategory.allCases.first { category in
                text.lowercased().contains(category.rawValue.lowercased())
            }
        } catch {
            print("❌ AI error for \(make) \(model): \(error)")
            return nil
        }
    }
    
    // Estimate time remaining
    var estimatedTimeRemaining: String {
        guard processedCards > 0, totalCards > processedCards else {
            return "Calculating..."
        }
        
        let cardsRemaining = totalCards - processedCards
        let secondsPerCard = 0.5 // Approximate (AI call + delay)
        let secondsRemaining = Double(cardsRemaining) * secondsPerCard
        
        let minutes = Int(secondsRemaining / 60)
        if minutes > 0 {
            return "~\(minutes)m remaining"
        } else {
            return "<1m remaining"
        }
    }
}
