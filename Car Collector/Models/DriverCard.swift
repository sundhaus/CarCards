//
//  DriverCard.swift
//  CarCardCollector
//
//  Data model for driver cards
//

import SwiftUI

struct DriverCard: Identifiable, Codable {
    let id: UUID
    var imageData: Data  // In-memory image data (may be empty if stored on disk)
    let firstName: String
    let lastName: String
    let nickname: String
    let vehicleName: String
    let isDriverPlusVehicle: Bool
    let capturedBy: String?  // Username who captured the card
    let capturedLocation: String?  // City where captured
    let capturedDate: Date
    var firebaseId: String?  // CloudCard ID from Firebase (for syncing)
    var customFrame: String?  // Border customization: "White", "Black", etc.
    
    init(
        id: UUID = UUID(),
        image: UIImage,
        firstName: String,
        lastName: String,
        nickname: String = "",
        vehicleName: String = "",
        isDriverPlusVehicle: Bool = false,
        capturedBy: String? = nil,
        capturedLocation: String? = nil,
        capturedDate: Date = Date(),
        firebaseId: String? = nil,
        customFrame: String? = nil
    ) {
        self.id = id
        self.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        self.firstName = firstName
        self.lastName = lastName
        self.nickname = nickname
        self.vehicleName = vehicleName
        self.isDriverPlusVehicle = isDriverPlusVehicle
        self.capturedBy = capturedBy
        self.capturedLocation = capturedLocation
        self.capturedDate = capturedDate
        self.firebaseId = firebaseId
        self.customFrame = customFrame
    }
    
    enum CodingKeys: String, CodingKey {
        case id, imageData, firstName, lastName, nickname, vehicleName
        case isDriverPlusVehicle, capturedBy, capturedLocation, capturedDate, firebaseId, customFrame
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData) ?? Data()
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        vehicleName = try container.decodeIfPresent(String.self, forKey: .vehicleName) ?? ""
        isDriverPlusVehicle = try container.decodeIfPresent(Bool.self, forKey: .isDriverPlusVehicle) ?? false
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
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(vehicleName, forKey: .vehicleName)
        try container.encode(isDriverPlusVehicle, forKey: .isDriverPlusVehicle)
        try container.encodeIfPresent(capturedBy, forKey: .capturedBy)
        try container.encodeIfPresent(capturedLocation, forKey: .capturedLocation)
        try container.encode(capturedDate, forKey: .capturedDate)
        try container.encodeIfPresent(firebaseId, forKey: .firebaseId)
        try container.encodeIfPresent(customFrame, forKey: .customFrame)
    }
    
    var thumbnail: UIImage? {
        CardImageStore.shared.loadDriverThumbnail(for: id)
    }
    
    var image: UIImage? {
        if !imageData.isEmpty {
            return UIImage(data: imageData)
        }
        return CardImageStore.shared.loadDriverImage(for: id)
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var displayName: String {
        if nickname.isEmpty {
            return fullName
        } else {
            return "\(fullName) (\(nickname))"
        }
    }
}
