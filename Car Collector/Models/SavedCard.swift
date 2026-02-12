//
//  SavedCard.swift
//  CarCardCollector
//
//  Data model for saved car cards with specs
//

import SwiftUI

struct SavedCard: Identifiable, Codable {
    let id: UUID
    let imageData: Data  // Final rendered card image
    let make: String
    let model: String
    let color: String
    let year: String
    let specs: CarSpecs  // Car specifications
    let capturedBy: String?  // Username who captured the card
    let capturedLocation: String?  // City where captured
    let previousOwners: Int  // Number of previous owners
    
    init(
        id: UUID = UUID(),
        image: UIImage,
        make: String,
        model: String,
        color: String,
        year: String,
        specs: CarSpecs = .empty,
        capturedBy: String? = nil,
        capturedLocation: String? = nil,
        previousOwners: Int = 0
    ) {
        self.id = id
        self.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        self.make = make
        self.model = model
        self.color = color
        self.year = year
        self.specs = specs
        self.capturedBy = capturedBy
        self.capturedLocation = capturedLocation
        self.previousOwners = previousOwners
    }
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    // Key for spec lookup/caching
    var specKey: String {
        "\(make)|\(model)|\(year)"
    }
}
