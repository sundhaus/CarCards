//
//  AnyCard.swift
//  CarCardCollector
//
//  Unified card type for displaying all card types in the garage
//

import SwiftUI

enum AnyCard: Identifiable {
    case vehicle(SavedCard)
    case driver(DriverCard)
    case location(LocationCard)
    
    var id: UUID {
        switch self {
        case .vehicle(let card): return card.id
        case .driver(let card): return card.id
        case .location(let card): return card.id
        }
    }
    
    var image: UIImage? {
        switch self {
        case .vehicle(let card): return card.image
        case .driver(let card): return card.image
        case .location(let card): return card.image
        }
    }
    
    var displayTitle: String {
        switch self {
        case .vehicle(let card):
            return "\(card.make) \(card.model)"
        case .driver(let card):
            return card.displayName
        case .location(let card):
            return card.locationName
        }
    }
    
    var displaySubtitle: String? {
        switch self {
        case .vehicle(let card):
            return card.year
        case .driver(let card):
            if card.isDriverPlusVehicle && !card.vehicleName.isEmpty {
                return card.vehicleName
            }
            return nil
        case .location(let card):
            return card.capturedLocation
        }
    }
    
    var customFrame: String? {
        switch self {
        case .vehicle(let card):
            return card.customFrame
        case .driver(let card):
            return card.customFrame
        case .location(let card):
            return card.customFrame
        }
    }
    
    var firebaseId: String? {
        switch self {
        case .vehicle(let card): return card.firebaseId
        case .driver(let card): return card.firebaseId
        case .location(let card): return card.firebaseId
        }
    }
    
    var capturedDate: Date {
        switch self {
        case .vehicle:
            return Date() // SavedCard doesn't have capturedDate
        case .driver(let card):
            return card.capturedDate
        case .location(let card):
            return card.capturedDate
        }
    }
    
    var cardType: String {
        switch self {
        case .vehicle: return "Vehicle"
        case .driver: return "Driver"
        case .location: return "Location"
        }
    }
    
    /// Light-weight text for top-left of card (e.g. make / first name / location name)
    var titleLine1: String {
        switch self {
        case .vehicle(let card): return card.make
        case .driver(let card): return card.firstName
        case .location(let card): return card.locationName
        }
    }
    
    /// Bold text for top-left of card (e.g. model / last name / subtitle)
    var titleLine2: String {
        switch self {
        case .vehicle(let card): return card.model
        case .driver(let card): return card.lastName
        case .location(let card): return card.capturedLocation ?? ""
        }
    }
}
