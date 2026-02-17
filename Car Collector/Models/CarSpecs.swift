//
//  CarSpecs.swift
//  CarCardCollector
//
//  Data model for car performance specifications with category
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
    let category: VehicleCategory?  // NEW: Vehicle category for Explore page
    
    // Initialize with all optional values
    init(
        horsepower: Int? = nil,
        torque: Int? = nil,
        zeroToSixty: Double? = nil,
        topSpeed: Int? = nil,
        engineType: String? = nil,
        displacement: Double? = nil,
        transmission: String? = nil,
        drivetrain: String? = nil,
        category: VehicleCategory? = nil
    ) {
        self.horsepower = horsepower
        self.torque = torque
        self.zeroToSixty = zeroToSixty
        self.topSpeed = topSpeed
        self.engineType = engineType
        self.displacement = displacement
        self.transmission = transmission
        self.drivetrain = drivetrain
        self.category = category
    }
    
    // Check if specs are complete (has category and basic specs)
    var isComplete: Bool {
        category != nil && horsepower != nil && torque != nil
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
        if let cat = category { dict["category"] = cat.rawValue }
        return dict
    }
    
    // Create from Firestore dictionary
    static func fromDictionary(_ dict: [String: Any]) -> CarSpecs {
        let categoryString = dict["category"] as? String
        let category = categoryString != nil ? VehicleCategory(rawValue: categoryString!) : nil
        
        return CarSpecs(
            horsepower: dict["horsepower"] as? Int,
            torque: dict["torque"] as? Int,
            zeroToSixty: dict["zeroToSixty"] as? Double,
            topSpeed: dict["topSpeed"] as? Int,
            engineType: dict["engineType"] as? String,
            displacement: dict["displacement"] as? Double,
            transmission: dict["transmission"] as? String,
            drivetrain: dict["drivetrain"] as? String,
            category: category
        )
    }
}

// Empty specs placeholder
extension CarSpecs {
    static var empty: CarSpecs {
        CarSpecs()
    }
}
