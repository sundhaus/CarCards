//
//  LocationCard.swift
//  CarCardCollector
//
//  Data model for location cards
//

import SwiftUI

struct LocationCard: Identifiable, Codable {
    let id: UUID
    let imageData: Data  // Final rendered card image
    let locationName: String
    let capturedBy: String?  // Username who captured the card
    let capturedLocation: String?  // City where captured (can be different from locationName)
    let capturedDate: Date
    var firebaseId: String?  // CloudCard ID from Firebase (for syncing)
    
    init(
        id: UUID = UUID(),
        image: UIImage,
        locationName: String,
        capturedBy: String? = nil,
        capturedLocation: String? = nil,
        capturedDate: Date = Date(),
        firebaseId: String? = nil
    ) {
        self.id = id
        self.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        self.locationName = locationName
        self.capturedBy = capturedBy
        self.capturedLocation = capturedLocation
        self.capturedDate = capturedDate
        self.firebaseId = firebaseId
    }
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
}
