//
//  Listing.swift
//  CarCardCollector
//
//  Data model for marketplace listings
//

import Foundation
import UIKit

struct Listing: Identifiable, Codable {
    let id: UUID
    let cardId: UUID  // Reference to original SavedCard
    let imageData: Data
    let make: String
    let model: String
    let year: String
    let minStartBid: Double
    let buyNowPrice: Double
    let duration: Int  // Hours
    let listingDate: Date
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    var expirationDate: Date {
        Calendar.current.date(byAdding: .hour, value: duration, to: listingDate) ?? listingDate
    }
    
    init(card: SavedCard, minStartBid: Double, buyNowPrice: Double, duration: Int) {
        self.id = UUID()
        self.cardId = card.id
        self.imageData = card.imageData
        self.make = card.make
        self.model = card.model
        self.year = card.year
        self.minStartBid = minStartBid
        self.buyNowPrice = buyNowPrice
        self.duration = duration
        self.listingDate = Date()
    }
}

// Storage manager for listings
class ListingStorage {
    private static let listingsKey = "activeListings"
    
    static func saveListings(_ listings: [Listing]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(listings)
            UserDefaults.standard.set(data, forKey: listingsKey)
        } catch {
            print("❌ Failed to save listings: \(error)")
        }
    }
    
    static func loadListings() -> [Listing] {
        guard let data = UserDefaults.standard.data(forKey: listingsKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let listings = try decoder.decode([Listing].self, from: data)
            return listings
        } catch {
            print("❌ Failed to load listings: \(error)")
            return []
        }
    }
    
    static func addListing(_ listing: Listing) {
        var listings = loadListings()
        listings.append(listing)
        saveListings(listings)
    }
    
    static func removeListing(_ listingId: UUID) {
        var listings = loadListings()
        listings.removeAll { $0.id == listingId }
        saveListings(listings)
    }
}
