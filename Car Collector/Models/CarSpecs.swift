//
//  CarSpecs.swift
//  CarCardCollector
//
//  Data model for car performance specifications
//

import Foundation

struct CarSpecs: Codable, Equatable {
    let horsepower: Int?        // HP
    let torque: Int?            // lb-ft
    let zeroToSixty: Double?    // seconds
    let topSpeed: Int?          // mph
    let engineType: String?     // "V6", "I4", "V8", etc.
    let displacement: Double?   // liters
    let transmission: String?   // "6-speed manual", "Auto", etc.
    let drivetrain: String?     // "RWD", "AWD", "FWD"
    
    // Initialize with all optional values
    init(
        horsepower: Int? = nil,
        torque: Int? = nil,
        zeroToSixty: Double? = nil,
        topSpeed: Int? = nil,
        engineType: String? = nil,
        displacement: Double? = nil,
        transmission: String? = nil,
        drivetrain: String? = nil
    ) {
        self.horsepower = horsepower
        self.torque = torque
        self.zeroToSixty = zeroToSixty
        self.topSpeed = topSpeed
        self.engineType = engineType
        self.displacement = displacement
        self.transmission = transmission
        self.drivetrain = drivetrain
    }
    
    // MARK: - Custom Decoder (handles String or Int/Double from older saves)
    
    enum CodingKeys: String, CodingKey {
        case horsepower, torque, zeroToSixty, topSpeed
        case engineType, displacement, transmission, drivetrain
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // horsepower: could be Int, String like "300 hp", or missing
        horsepower = Self.decodeIntOrString(from: container, key: .horsepower)
        
        // torque: could be Int, String like "280 lb-ft", or missing
        torque = Self.decodeIntOrString(from: container, key: .torque)
        
        // zeroToSixty: could be Double, String like "4.6s", or missing
        zeroToSixty = Self.decodeDoubleOrString(from: container, key: .zeroToSixty)
        
        // topSpeed: could be Int, String like "155 mph", or missing
        topSpeed = Self.decodeIntOrString(from: container, key: .topSpeed)
        
        // engineType: always String or missing
        engineType = try container.decodeIfPresent(String.self, forKey: .engineType)
        
        // displacement: could be Double, String, or missing
        displacement = Self.decodeDoubleOrString(from: container, key: .displacement)
        
        // transmission: always String or missing
        transmission = try container.decodeIfPresent(String.self, forKey: .transmission)
        
        // drivetrain: always String or missing
        drivetrain = try container.decodeIfPresent(String.self, forKey: .drivetrain)
    }
    
    // MARK: - Flexible Decode Helpers
    
    /// Tries Int first, then parses Int from String (e.g. "300 hp" -> 300)
    private static func decodeIntOrString(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        // Try Int directly
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        // Try String and extract number
        if let str = try? container.decodeIfPresent(String.self, forKey: key), str != "N/A" {
            let cleaned = str.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            return Int(cleaned)
        }
        return nil
    }
    
    /// Tries Double first, then parses Double from String (e.g. "4.6s" -> 4.6)
    private static func decodeDoubleOrString(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        // Try Double directly
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        // Try Int (e.g. displacement saved as 3 instead of 3.0)
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        // Try String and extract number
        if let str = try? container.decodeIfPresent(String.self, forKey: key), str != "N/A" {
            let cleaned = str.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            return Double(cleaned)
        }
        return nil
    }
    
    // Check if specs are complete (has at least HP and torque)
    var isComplete: Bool {
        horsepower != nil && torque != nil
    }
    
    // Convert to Firestore dictionary
    var toDictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let hp = horsepower { dict["horsepower"] = hp }
        if let tq = torque { dict["torque"] = tq }
        if let zts = zeroToSixty { dict["zeroToSixty"] = zts }
        if let ts = topSpeed { dict["topSpeed"] = ts }
        if let et = engineType { dict["engineType"] = et }
        if let disp = displacement { dict["displacement"] = disp }
        if let trans = transmission { dict["transmission"] = trans }
        if let dt = drivetrain { dict["drivetrain"] = dt }
        return dict
    }
    
    // Create from Firestore dictionary
    static func fromDictionary(_ dict: [String: Any]) -> CarSpecs {
        return CarSpecs(
            horsepower: dict["horsepower"] as? Int,
            torque: dict["torque"] as? Int,
            zeroToSixty: dict["zeroToSixty"] as? Double,
            topSpeed: dict["topSpeed"] as? Int,
            engineType: dict["engineType"] as? String,
            displacement: dict["displacement"] as? Double,
            transmission: dict["transmission"] as? String,
            drivetrain: dict["drivetrain"] as? String
        )
    }
}

// Empty specs placeholder
extension CarSpecs {
    static var empty: CarSpecs {
        CarSpecs()
    }
}
