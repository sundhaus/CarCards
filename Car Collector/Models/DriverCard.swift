//
//  DriverCard.swift
//  CarCardCollector
//
//  Data model for driver cards
//

import SwiftUI

struct DriverCard: Identifiable, Codable {
    let id: UUID
    let imageData: Data  // Final rendered card image (with signature if added)
    let firstName: String
    let lastName: String
    let nickname: String
    let vehicleName: String
    let isDriverPlusVehicle: Bool
    let capturedBy: String?  // Username who captured the card
    let capturedLocation: String?  // City where captured
    let capturedDate: Date
    var firebaseId: String?  // CloudCard ID from Firebase (for syncing)
    
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
        firebaseId: String? = nil
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
    }
    
    var image: UIImage? {
        UIImage(data: imageData)
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
