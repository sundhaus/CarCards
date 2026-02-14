//
//  CardStorage.swift
//  CarCardCollector
//
//  Manages persistent storage of saved cards (local UserDefaults)
//

import Foundation
import UIKit

class CardStorage {
    private static let cardsKey = "savedCards"
    
    // Save cards to persistent storage
    static func saveCards(_ cards: [SavedCard]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cards)
            UserDefaults.standard.set(data, forKey: cardsKey)
            print("✅ Successfully saved \(cards.count) cards")
            
            // Also save to CSV for rarity tracking
            saveCardsToCSV(cards)
        } catch {
            print("❌ Failed to save cards: \(error)")
        }
    }
    
    // Load cards from persistent storage
    static func loadCards() -> [SavedCard] {
        guard let data = UserDefaults.standard.data(forKey: cardsKey) else {
            print("ℹ️ No saved cards found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let cards = try decoder.decode([SavedCard].self, from: data)
            print("✅ Successfully loaded \(cards.count) cards")
            return cards
        } catch {
            print("❌ Failed to load cards: \(error)")
            return []
        }
    }
    
    // Delete all cards (for testing)
    static func deleteAllCards() {
        UserDefaults.standard.removeObject(forKey: cardsKey)
        print("🗑️ Deleted all saved cards")
    }
    
    // MARK: - CSV Export for Rarity Tracking
    
    // Save cards to CSV file in Documents directory
    static func saveCardsToCSV(_ cards: [SavedCard]) {
        let csvString = generateCSV(from: cards)
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("my_car_collection.csv")
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("📊 CSV saved: \(fileURL.path)")
        } catch {
            print("❌ Failed to save CSV: \(error)")
        }
    }
    
    // Generate CSV string from cards
    static func generateCSV(from cards: [SavedCard]) -> String {
        var csv = "Make,Model,Year,Color\n"
        for card in cards {
            csv += "\(card.make),\(card.model),\(card.year),\(card.color)\n"
        }
        return csv
    }
    
    // MARK: - Driver Card Storage
    
    private static let driverCardsKey = "savedDriverCards"
    
    static func saveDriverCards(_ cards: [DriverCard]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cards)
            UserDefaults.standard.set(data, forKey: driverCardsKey)
            print("✅ Successfully saved \(cards.count) driver cards")
        } catch {
            print("❌ Failed to save driver cards: \(error)")
        }
    }
    
    static func loadDriverCards() -> [DriverCard] {
        guard let data = UserDefaults.standard.data(forKey: driverCardsKey) else {
            print("ℹ️ No saved driver cards found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let cards = try decoder.decode([DriverCard].self, from: data)
            print("✅ Successfully loaded \(cards.count) driver cards")
            return cards
        } catch {
            print("❌ Failed to load driver cards: \(error)")
            return []
        }
    }
    
    // MARK: - Location Card Storage
    
    private static let locationCardsKey = "savedLocationCards"
    
    static func saveLocationCards(_ cards: [LocationCard]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cards)
            UserDefaults.standard.set(data, forKey: locationCardsKey)
            print("✅ Successfully saved \(cards.count) location cards")
        } catch {
            print("❌ Failed to save location cards: \(error)")
        }
    }
    
    static func loadLocationCards() -> [LocationCard] {
        guard let data = UserDefaults.standard.data(forKey: locationCardsKey) else {
            print("ℹ️ No saved location cards found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let cards = try decoder.decode([LocationCard].self, from: data)
            print("✅ Successfully loaded \(cards.count) location cards")
            return cards
        } catch {
            print("❌ Failed to load location cards: \(error)")
            return []
        }
    }
}
