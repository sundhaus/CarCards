//
//  CategoryMigrationService.swift
//  CarCardCollector
//
//  Service to backfill vehicle categories for existing cards in Firestore
//  Copies categories from vehicleSpecs to friend_activities
//

import Foundation
import FirebaseFirestore

@MainActor
class CategoryMigrationService: ObservableObject {
    @Published var migrationProgress: String = ""
    @Published var isRunning = false
    @Published var totalCards = 0
    @Published var processedCards = 0
    @Published var categorizedCards = 0
    @Published var skippedCards = 0
    
    private let db = Firestore.firestore()
    
    // Run migration for all cards without categories
    func migrateMissingCategories() async {
        guard !isRunning else {
            print("⚠️ Migration already running")
            return
        }
        
        isRunning = true
        migrationProgress = "Starting migration..."
        
        do {
            // Get all friend_activities
            let snapshot = try await db.collection("friend_activities")
                .getDocuments()
            
            totalCards = snapshot.documents.count
            processedCards = 0
            categorizedCards = 0
            skippedCards = 0
            
            print("🔄 Found \(totalCards) total friend_activities")
            migrationProgress = "Found \(totalCards) cards. Copying categories from vehicleSpecs..."
            
            // Process each card
            for document in snapshot.documents {
                let data = document.data()
                
                // Skip if already has category
                if let category = data["category"] as? String, !category.isEmpty {
                    print("⏭️ Already has category: \(category)")
                    skippedCards += 1
                    processedCards += 1
                    continue
                }
                
                // Get card info
                guard let make = data["cardMake"] as? String,
                      let model = data["cardModel"] as? String,
                      let year = data["cardYear"] as? String else {
                    print("⚠️ Missing make/model/year")
                    skippedCards += 1
                    processedCards += 1
                    continue
                }
                
                migrationProgress = "Processing \(make) \(model) (\(processedCards + 1)/\(totalCards))..."
                print("\n📋 [\(processedCards + 1)/\(totalCards)] \(make) \(model) \(year)")
                
                // Look up category from vehicleSpecs
                let normalizedMake = make.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedModel = model.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedYear = year.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let docId = "\(normalizedMake)_\(normalizedModel)_\(normalizedYear)"
                    .replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: "-", with: "_")
                    .replacingOccurrences(of: "/", with: "_")
                
                print("   🔍 Looking in vehicleSpecs: \(docId)")
                
                do {
                    let specsDoc = try await db.collection("vehicleSpecs").document(docId).getDocument()
                    
                    if specsDoc.exists, let specsData = specsDoc.data(), let category = specsData["category"] as? String {
                        // Found category in vehicleSpecs - copy to friend_activities
                        print("   ✅ Found category in vehicleSpecs: \(category)")
                        
                        try await document.reference.updateData([
                            "category": category
                        ])
                        
                        categorizedCards += 1
                        print("   ✅ Updated friend_activities with category: \(category)")
                    } else {
                        print("   ⚠️ No specs found or no category in vehicleSpecs")
                        print("   💡 Need to fetch specs for this car first")
                        skippedCards += 1
                    }
                } catch {
                    print("   ❌ Error: \(error.localizedDescription)")
                    skippedCards += 1
                }
                
                processedCards += 1
                
                // Small delay to avoid overwhelming Firestore
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            migrationProgress = "✅ Migration complete! Categorized: \(categorizedCards), Skipped: \(skippedCards)"
            print("\n✅ MIGRATION COMPLETE!")
            print("   📊 Total friend_activities: \(totalCards)")
            print("   ✅ Copied categories: \(categorizedCards)")
            print("   ⏭️ Already had category: \(totalCards - processedCards - skippedCards)")
            print("   ⚠️ Skipped (no vehicleSpecs): \(skippedCards)")
            
        } catch {
            migrationProgress = "❌ Error: \(error.localizedDescription)"
            print("❌ Migration failed: \(error)")
        }
        
        isRunning = false
    }
}
