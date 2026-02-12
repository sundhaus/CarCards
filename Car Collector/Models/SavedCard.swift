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
    let specs: VehicleSpecs?  // Vehicle specifications from AI
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
        specs: VehicleSpecs? = nil,
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
    
    // MARK: - Custom Decoder (handles older cards missing new fields)
    
    enum CodingKeys: String, CodingKey {
        case id, imageData, make, model, color, year
        case specs, capturedBy, capturedLocation, previousOwners
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        imageData = try container.decode(Data.self, forKey: .imageData)
        make = try container.decode(String.self, forKey: .make)
        model = try container.decode(String.self, forKey: .model)
        color = try container.decode(String.self, forKey: .color)
        year = try container.decode(String.self, forKey: .year)
        
        // New fields - provide defaults if missing from older saved data
        specs = try container.decodeIfPresent(VehicleSpecs.self, forKey: .specs)
        capturedBy = try container.decodeIfPresent(String.self, forKey: .capturedBy)
        capturedLocation = try container.decodeIfPresent(String.self, forKey: .capturedLocation)
        previousOwners = try container.decodeIfPresent(Int.self, forKey: .previousOwners) ?? 0
    }
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    // Key for spec lookup/caching
    var specKey: String {
        "\(make)|\(model)|\(year)"
    }
    
    // MARK: - Helper Methods to Parse Specs
    
    func parseHP() -> Int? {
        guard let specs = specs, specs.horsepower != "N/A" else { return nil }
        let cleaned = specs.horsepower.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(cleaned)
    }
    
    func parseTorque() -> Int? {
        guard let specs = specs, specs.torque != "N/A" else { return nil }
        let cleaned = specs.torque.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(cleaned)
    }
    
    func parseZeroToSixty() -> Double? {
        guard let specs = specs, specs.zeroToSixty != "N/A" else { return nil }
        let cleaned = specs.zeroToSixty.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleaned)
    }
    
    func parseTopSpeed() -> Int? {
        guard let specs = specs, specs.topSpeed != "N/A" else { return nil }
        let cleaned = specs.topSpeed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(cleaned)
    }
    
    func getEngine() -> String? {
        guard let specs = specs, specs.engine != "N/A" else { return nil }
        return specs.engine
    }
    
    func getDrivetrain() -> String? {
        guard let specs = specs, specs.drivetrain != "N/A" else { return nil }
        return specs.drivetrain
    }
}
