//
//  LocationCard.swift
//  CarCardCollector
//
//  Data model for location cards
//

import SwiftUI

struct LocationCard: Identifiable, Codable {
    let id: UUID
    var imageData: Data  // In-memory image data (may be empty if stored on disk)
    let locationName: String
    let capturedBy: String?  // Username who captured the card
    let capturedLocation: String?  // City where captured (can be different from locationName)
    let capturedDate: Date
    var firebaseId: String?  // CloudCard ID from Firebase (for syncing)
    var customFrame: String?  // Border customization: "White", "Black", etc.
    
    init(
        id: UUID = UUID(),
        image: UIImage,
        locationName: String,
        capturedBy: String? = nil,
        capturedLocation: String? = nil,
        capturedDate: Date = Date(),
        firebaseId: String? = nil,
        customFrame: String? = nil
    ) {
        self.id = id
        self.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        self.locationName = locationName
        self.capturedBy = capturedBy
        self.capturedLocation = capturedLocation
        self.capturedDate = capturedDate
        self.firebaseId = firebaseId
        self.customFrame = customFrame
    }
    
    enum CodingKeys: String, CodingKey {
        case id, imageData, locationName, capturedBy, capturedLocation, capturedDate, firebaseId, customFrame
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData) ?? Data()
        locationName = try container.decode(String.self, forKey: .locationName)
        capturedBy = try container.decodeIfPresent(String.self, forKey: .capturedBy)
        capturedLocation = try container.decodeIfPresent(String.self, forKey: .capturedLocation)
        capturedDate = try container.decodeIfPresent(Date.self, forKey: .capturedDate) ?? Date()
        firebaseId = try container.decodeIfPresent(String.self, forKey: .firebaseId)
        customFrame = try container.decodeIfPresent(String.self, forKey: .customFrame)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if !imageData.isEmpty {
            try container.encode(imageData, forKey: .imageData)
        }
        try container.encode(locationName, forKey: .locationName)
        try container.encodeIfPresent(capturedBy, forKey: .capturedBy)
        try container.encodeIfPresent(capturedLocation, forKey: .capturedLocation)
        try container.encode(capturedDate, forKey: .capturedDate)
        try container.encodeIfPresent(firebaseId, forKey: .firebaseId)
        try container.encodeIfPresent(customFrame, forKey: .customFrame)
    }
    
    var thumbnail: UIImage? {
        CardImageStore.shared.loadLocationThumbnail(for: id)
    }
    
    var image: UIImage? {
        if !imageData.isEmpty {
            return UIImage(data: imageData)
        }
        return CardImageStore.shared.loadLocationImage(for: id)
    }
}
