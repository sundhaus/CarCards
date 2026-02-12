//
//  CarSpecsService.swift
//  CarCardCollector
//
//  Service for fetching car specifications (uses VehicleIdentificationService)
//

import Foundation

@MainActor
class CarSpecsService: ObservableObject {
    static let shared = CarSpecsService()
    
    private let vehicleService = VehicleIdentificationService()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Get specs for a car (from Firestore cache or generate new)
    func getSpecs(make: String, model: String, year: String) async -> CarSpecs {
        print("🔍 Fetching specs for \(make) \(model) \(year)")
        
        do {
            // VehicleIdentificationService handles Firestore caching automatically
            let vehicleSpecs = try await vehicleService.fetchSpecs(
                make: make,
                model: model,
                year: year
            )
            
            // Convert VehicleSpecs to CarSpecs
            let carSpecs = convertToCarSpecs(vehicleSpecs)
            print("✅ Got specs: HP=\(carSpecs.horsepower ?? 0), TQ=\(carSpecs.torque ?? 0)")
            return carSpecs
            
        } catch {
            print("❌ Failed to fetch specs: \(error)")
            return .empty
        }
    }
    
    // MARK: - Private Methods
    
    private func convertToCarSpecs(_ vehicleSpecs: VehicleSpecs) -> CarSpecs {
        // Parse string values to proper types
        let hp = parseIntFromString(vehicleSpecs.horsepower)
        let tq = parseIntFromString(vehicleSpecs.torque)
        let zts = parseDoubleFromString(vehicleSpecs.zeroToSixty)
        let ts = parseIntFromString(vehicleSpecs.topSpeed)
        
        // Extract displacement from engine if present (e.g. "3.0L V6" -> 3.0)
        let displacement = extractDisplacement(from: vehicleSpecs.engine)
        
        return CarSpecs(
            horsepower: hp,
            torque: tq,
            zeroToSixty: zts,
            topSpeed: ts,
            engineType: vehicleSpecs.engine != "N/A" ? vehicleSpecs.engine : nil,
            displacement: displacement,
            transmission: vehicleSpecs.transmission != "N/A" ? vehicleSpecs.transmission : nil,
            drivetrain: vehicleSpecs.drivetrain != "N/A" ? vehicleSpecs.drivetrain : nil
        )
    }
    
    private func parseIntFromString(_ string: String) -> Int? {
        // Handle formats like "320 hp", "315", "N/A"
        if string == "N/A" { return nil }
        
        let cleaned = string.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return Int(cleaned)
    }
    
    private func parseDoubleFromString(_ string: String) -> Double? {
        // Handle formats like "4.6 sec", "4.6", "N/A"
        if string == "N/A" { return nil }
        
        let cleaned = string.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(cleaned)
    }
    
    private func extractDisplacement(from engine: String) -> Double? {
        // Try to extract displacement from strings like "3.0L V6", "2.0L I4"
        if engine == "N/A" { return nil }
        
        let pattern = "(\\d+\\.\\d+)L"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: engine, range: NSRange(engine.startIndex..., in: engine)),
           let range = Range(match.range(at: 1), in: engine) {
            return Double(engine[range])
        }
        
        return nil
    }
}
