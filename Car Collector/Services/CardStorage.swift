//
//  CardStorage.swift
//  CarCardCollector
//
//  Manages persistent storage of saved cards.
//  Images stored as individual files on disk; metadata as lightweight JSON.
//  Migrates from legacy UserDefaults storage on first launch.
//

import Foundation
import UIKit

class CardStorage {
    // MARK: - File Paths
    
    private static var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private static var vehicleMetadataURL: URL { docsDir.appendingPathComponent("vehicle_cards.json") }
    private static var driverMetadataURL: URL { docsDir.appendingPathComponent("driver_cards.json") }
    private static var locationMetadataURL: URL { docsDir.appendingPathComponent("location_cards.json") }
    
    // Legacy UserDefaults keys
    private static let legacyCardsKey = "savedCards"
    private static let legacyDriverCardsKey = "savedDriverCards"
    private static let legacyLocationCardsKey = "savedLocationCards"
    private static let migrationKey = "hasCompletedFileMigration_v1"
    
    // MARK: - Migration
    
    /// Call once at app startup to migrate from UserDefaults to file-based storage
    static func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        
        print("🔄 Starting card storage migration from UserDefaults to files...")
        
        let store = CardImageStore.shared
        
        // Migrate vehicle cards
        if let data = UserDefaults.standard.data(forKey: legacyCardsKey),
           let cards = try? JSONDecoder().decode([SavedCard].self, from: data) {
            
            for card in cards {
                // Write image to file
                if let image = UIImage(data: card.imageData) {
                    store.saveVehicleImage(image, for: card.id)
                }
                // Write original image if present
                if let origData = card.originalImageData, let origImage = UIImage(data: origData) {
                    store.saveVehicleOriginal(origImage, for: card.id)
                }
            }
            
            // Save metadata-only JSON (images stripped by encoder)
            var strippedCards = cards
            for i in strippedCards.indices {
                strippedCards[i].imageData = Data()
                strippedCards[i].originalImageData = nil
            }
            saveMetadata(strippedCards, to: vehicleMetadataURL)
            
            // Clear from UserDefaults
            UserDefaults.standard.removeObject(forKey: legacyCardsKey)
            print("✅ Migrated \(cards.count) vehicle cards")
        }
        
        // Migrate driver cards
        if let data = UserDefaults.standard.data(forKey: legacyDriverCardsKey),
           let cards = try? JSONDecoder().decode([DriverCard].self, from: data) {
            
            for card in cards {
                if let image = UIImage(data: card.imageData) {
                    store.saveDriverImage(image, for: card.id)
                }
            }
            
            var strippedCards = cards
            for i in strippedCards.indices {
                strippedCards[i].imageData = Data()
            }
            saveMetadata(strippedCards, to: driverMetadataURL)
            
            UserDefaults.standard.removeObject(forKey: legacyDriverCardsKey)
            print("✅ Migrated \(cards.count) driver cards")
        }
        
        // Migrate location cards
        if let data = UserDefaults.standard.data(forKey: legacyLocationCardsKey),
           let cards = try? JSONDecoder().decode([LocationCard].self, from: data) {
            
            for card in cards {
                if let image = UIImage(data: card.imageData) {
                    store.saveLocationImage(image, for: card.id)
                }
            }
            
            var strippedCards = cards
            for i in strippedCards.indices {
                strippedCards[i].imageData = Data()
            }
            saveMetadata(strippedCards, to: locationMetadataURL)
            
            UserDefaults.standard.removeObject(forKey: legacyLocationCardsKey)
            print("✅ Migrated \(cards.count) location cards")
        }
        
        UserDefaults.standard.set(true, forKey: migrationKey)
        UserDefaults.standard.synchronize()
        print("🏁 Card storage migration complete")
    }
    
    // MARK: - Vehicle Cards
    
    static func saveCards(_ cards: [SavedCard]) {
        let store = CardImageStore.shared
        
        // Write images to individual files
        for card in cards {
            if !card.imageData.isEmpty, let image = UIImage(data: card.imageData) {
                store.saveVehicleImage(image, for: card.id)
            }
            if let origData = card.originalImageData, !origData.isEmpty,
               let origImage = UIImage(data: origData) {
                store.saveVehicleOriginal(origImage, for: card.id)
            } else if card.originalImageData == nil {
                // Original was cleared (bg restored) — delete file if it exists
                store.deleteVehicleOriginal(for: card.id)
            }
        }
        
        // Save metadata-only JSON (imageData will be empty → skipped by encoder)
        var metadataCards = cards
        for i in metadataCards.indices {
            metadataCards[i].imageData = Data()
            metadataCards[i].originalImageData = nil
        }
        saveMetadata(metadataCards, to: vehicleMetadataURL)
        
        print("✅ Saved \(cards.count) cards (images on disk, metadata JSON)")
        
        // Also save to CSV for rarity tracking
        saveCardsToCSV(cards)
        
        // Notify garage to refresh
        NotificationCenter.default.post(name: NSNotification.Name("CardSaved"), object: nil)
    }
    
    static func loadCards() -> [SavedCard] {
        // Try file-based first
        if let cards: [SavedCard] = loadMetadata(from: vehicleMetadataURL) {
            print("✅ Loaded \(cards.count) vehicle cards (metadata from file)")
            return cards
        }
        
        // Fallback to UserDefaults (pre-migration)
        guard let data = UserDefaults.standard.data(forKey: legacyCardsKey) else {
            print("ℹ️ No saved cards found")
            return []
        }
        
        do {
            let cards = try JSONDecoder().decode([SavedCard].self, from: data)
            print("✅ Loaded \(cards.count) cards from UserDefaults (legacy)")
            return cards
        } catch {
            print("❌ Failed to load cards: \(error)")
            return []
        }
    }
    
    static func deleteAllCards() {
        try? FileManager.default.removeItem(at: vehicleMetadataURL)
        UserDefaults.standard.removeObject(forKey: legacyCardsKey)
        print("🗑️ Deleted all saved cards")
    }
    
    // MARK: - Driver Cards
    
    static func saveDriverCards(_ cards: [DriverCard]) {
        let store = CardImageStore.shared
        
        for card in cards {
            if !card.imageData.isEmpty, let image = UIImage(data: card.imageData) {
                store.saveDriverImage(image, for: card.id)
            }
        }
        
        var metadataCards = cards
        for i in metadataCards.indices {
            metadataCards[i].imageData = Data()
        }
        saveMetadata(metadataCards, to: driverMetadataURL)
        
        print("✅ Saved \(cards.count) driver cards")
        NotificationCenter.default.post(name: NSNotification.Name("CardSaved"), object: nil)
    }
    
    static func loadDriverCards() -> [DriverCard] {
        if let cards: [DriverCard] = loadMetadata(from: driverMetadataURL) {
            print("✅ Loaded \(cards.count) driver cards (metadata from file)")
            return cards
        }
        
        guard let data = UserDefaults.standard.data(forKey: legacyDriverCardsKey) else {
            print("ℹ️ No saved driver cards found")
            return []
        }
        
        do {
            let cards = try JSONDecoder().decode([DriverCard].self, from: data)
            print("✅ Loaded \(cards.count) driver cards from UserDefaults (legacy)")
            return cards
        } catch {
            print("❌ Failed to load driver cards: \(error)")
            return []
        }
    }
    
    // MARK: - Location Cards
    
    static func saveLocationCards(_ cards: [LocationCard]) {
        let store = CardImageStore.shared
        
        for card in cards {
            if !card.imageData.isEmpty, let image = UIImage(data: card.imageData) {
                store.saveLocationImage(image, for: card.id)
            }
        }
        
        var metadataCards = cards
        for i in metadataCards.indices {
            metadataCards[i].imageData = Data()
        }
        saveMetadata(metadataCards, to: locationMetadataURL)
        
        print("✅ Saved \(cards.count) location cards")
        NotificationCenter.default.post(name: NSNotification.Name("CardSaved"), object: nil)
    }
    
    static func loadLocationCards() -> [LocationCard] {
        if let cards: [LocationCard] = loadMetadata(from: locationMetadataURL) {
            print("✅ Loaded \(cards.count) location cards (metadata from file)")
            return cards
        }
        
        guard let data = UserDefaults.standard.data(forKey: legacyLocationCardsKey) else {
            print("ℹ️ No saved location cards found")
            return []
        }
        
        do {
            let cards = try JSONDecoder().decode([LocationCard].self, from: data)
            print("✅ Loaded \(cards.count) location cards from UserDefaults (legacy)")
            return cards
        } catch {
            print("❌ Failed to load location cards: \(error)")
            return []
        }
    }
    
    // MARK: - Generic Metadata Helpers
    
    private static func saveMetadata<T: Encodable>(_ items: T, to url: URL) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("❌ Failed to save metadata to \(url.lastPathComponent): \(error)")
        }
    }
    
    private static func loadMetadata<T: Decodable>(from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("❌ Failed to load metadata from \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    // MARK: - CSV Export for Rarity Tracking
    
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
    
    static func generateCSV(from cards: [SavedCard]) -> String {
        var csv = "Make,Model,Year,Color\n"
        for card in cards {
            csv += "\(card.make),\(card.model),\(card.year),\(card.color)\n"
        }
        return csv
    }
}
