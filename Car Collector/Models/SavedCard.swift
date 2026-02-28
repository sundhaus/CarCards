//
//  SavedCard.swift
//  CarCardCollector
//
//  Data model for saved car cards with specs
//

import SwiftUI

struct SavedCard: Identifiable, Codable {
    let id: UUID
    var imageData: Data  // In-memory image data (may be empty if stored on disk)
    let make: String
    let model: String
    let color: String
    let year: String
    let specs: VehicleSpecs?  // Vehicle specifications from AI
    let capturedBy: String?  // Username who captured the card
    let capturedLocation: String?  // City where captured
    let previousOwners: Int  // Number of previous owners
    var customFrame: String?  // Custom frame/border ("none", "white", "black")
    var holoEffect: String?   // Holographic pattern effect ("geometric", "waves", or nil)
    var firebaseId: String?  // CloudCard ID from Firebase (for syncing)
    var mintNumber: Int?     // Global sequential mint number (Legendary cards only)
    var originalImageData: Data?  // Original image before background removal
    
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
        previousOwners: Int = 0,
        customFrame: String? = nil,
        holoEffect: String? = nil,
        firebaseId: String? = nil,
        mintNumber: Int? = nil,
        originalImage: UIImage? = nil
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
        self.customFrame = customFrame
        self.holoEffect = holoEffect
        self.firebaseId = firebaseId
        self.mintNumber = mintNumber
        self.originalImageData = originalImage?.jpegData(compressionQuality: 0.8)
    }
    
    // MARK: - Custom Decoder (handles older cards missing new fields)
    
    enum CodingKeys: String, CodingKey {
        case id, imageData, make, model, color, year
        case specs, capturedBy, capturedLocation, previousOwners, customFrame, holoEffect, firebaseId
        case mintNumber, originalImageData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        // imageData may be absent when loaded from metadata-only JSON
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData) ?? Data()
        make = try container.decode(String.self, forKey: .make)
        model = try container.decode(String.self, forKey: .model)
        color = try container.decode(String.self, forKey: .color)
        year = try container.decode(String.self, forKey: .year)
        
        // New fields - provide defaults if missing from older saved data
        specs = try container.decodeIfPresent(VehicleSpecs.self, forKey: .specs)
        capturedBy = try container.decodeIfPresent(String.self, forKey: .capturedBy)
        capturedLocation = try container.decodeIfPresent(String.self, forKey: .capturedLocation)
        previousOwners = try container.decodeIfPresent(Int.self, forKey: .previousOwners) ?? 0
        customFrame = try container.decodeIfPresent(String.self, forKey: .customFrame)
        holoEffect = try container.decodeIfPresent(String.self, forKey: .holoEffect)
        firebaseId = try container.decodeIfPresent(String.self, forKey: .firebaseId)
        mintNumber = try container.decodeIfPresent(Int.self, forKey: .mintNumber)
        originalImageData = try container.decodeIfPresent(Data.self, forKey: .originalImageData)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        // Only encode imageData if non-empty (metadata-only saves skip it)
        if !imageData.isEmpty {
            try container.encode(imageData, forKey: .imageData)
        }
        try container.encode(make, forKey: .make)
        try container.encode(model, forKey: .model)
        try container.encode(color, forKey: .color)
        try container.encode(year, forKey: .year)
        try container.encodeIfPresent(specs, forKey: .specs)
        try container.encodeIfPresent(capturedBy, forKey: .capturedBy)
        try container.encodeIfPresent(capturedLocation, forKey: .capturedLocation)
        try container.encode(previousOwners, forKey: .previousOwners)
        try container.encodeIfPresent(customFrame, forKey: .customFrame)
        try container.encodeIfPresent(holoEffect, forKey: .holoEffect)
        try container.encodeIfPresent(firebaseId, forKey: .firebaseId)
        try container.encodeIfPresent(mintNumber, forKey: .mintNumber)
        // originalImageData NOT encoded to metadata JSON - stored as separate file
    }
    
    // MARK: - Image Access (lazy loads from disk if needed)
    
    /// Thumbnail for grid/list views — small memory footprint
    var thumbnail: UIImage? {
        CardImageStore.shared.loadVehicleThumbnail(for: id)
    }
    
    /// Full-res for fullscreen detail — loaded on demand
    var image: UIImage? {
        if !imageData.isEmpty {
            return UIImage(data: imageData)
        }
        return CardImageStore.shared.loadVehicleImage(for: id)
    }
    
    var originalImage: UIImage? {
        if let data = originalImageData, !data.isEmpty {
            return UIImage(data: data)
        }
        return CardImageStore.shared.loadVehicleOriginal(for: id)
    }
    
    /// Whether this card has an original (pre-bg-removal) image stored
    var hasOriginalImage: Bool {
        if let data = originalImageData, !data.isEmpty { return true }
        return CardImageStore.shared.loadVehicleOriginal(for: id) != nil
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
    
    var asAnyCard: AnyCard {
        return .vehicle(self)
    }
    
    /// Convert VehicleSpecs → CarSpecs for battle stat calculations
    var carSpecs: CarSpecs {
        CarSpecs(
            horsepower: parseHP(),
            torque: parseTorque(),
            zeroToSixty: parseZeroToSixty(),
            topSpeed: parseTopSpeed(),
            engineType: getEngine(),
            displacement: parseDisplacement(),
            transmission: specs?.transmission != "N/A" ? specs?.transmission : nil,
            drivetrain: getDrivetrain(),
            category: specs?.category
        )
    }
    
    /// Parse displacement in liters from engine string
    /// e.g. "8.0L Quad-Turbo W16" → 8.0, "3.8L Twin-Turbo V8" → 3.8,
    ///      "6.2L Supercharged V8" → 6.2, "Electric Motor" → nil
    func parseDisplacement() -> Double? {
        guard let engine = specs?.engine, engine != "N/A" else { return nil }
        // Match patterns like "8.0L", "3.8-liter", "6200cc"
        // Pattern 1: X.XL or X.X L
        if let range = engine.range(of: #"(\d+\.?\d*)\s*[Ll]"#, options: .regularExpression) {
            let match = String(engine[range])
            let cleaned = match.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            return Double(cleaned)
        }
        // Pattern 2: X.X-liter or X.X liter
        if let range = engine.range(of: #"(\d+\.?\d*)\s*-?\s*[Ll]iter"#, options: .regularExpression) {
            let match = String(engine[range])
            let cleaned = match.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            return Double(cleaned)
        }
        // Pattern 3: XXXXcc → convert to liters
        if let range = engine.range(of: #"(\d{3,5})\s*cc"#, options: .regularExpression) {
            let match = String(engine[range])
            let cleaned = match.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let cc = Double(cleaned) {
                return cc / 1000.0
            }
        }
        return nil
    }
}
