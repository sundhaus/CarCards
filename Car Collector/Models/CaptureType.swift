//
//  CaptureType.swift
//  CarCardCollector
//
//  Defines the type of capture being performed
//

import Foundation

enum CaptureType: CustomStringConvertible {
    case vehicle
    case driver
    case driverPlusVehicle
    case location
    
    var description: String {
        switch self {
        case .vehicle: return "vehicle"
        case .driver: return "driver"
        case .driverPlusVehicle: return "driverPlusVehicle"
        case .location: return "location"
        }
    }
}
