//
//  VehicleCategory.swift
//  CarCardCollector
//
//  Categories for vehicle classification - determined by AI
//

import Foundation

enum VehicleCategory: String, Codable, CaseIterable {
    // Performance
    case hypercar = "Hypercar"
    case supercar = "Supercar"
    case sportsCar = "Sports Car"
    case muscle = "Muscle"
    case track = "Track"
    
    // Off-Road & Utility
    case offRoad = "Off-Road"
    case rally = "Rally"
    case suv = "SUV"
    case truck = "Truck"
    case van = "Van"
    
    // Luxury & Comfort
    case luxury = "Luxury"
    case sedan = "Sedan"
    case coupe = "Coupe"
    case convertible = "Convertible"
    case wagon = "Wagon"
    
    // Specialty
    case electric = "Electric"
    case hybrid = "Hybrid"
    case classic = "Classic"
    case concept = "Concept"
    case hatchback = "Hatchback"
    
    var emoji: String {
        switch self {
        case .hypercar: return "🏎️"
        case .supercar: return "🏁"
        case .sportsCar: return "🚗"
        case .muscle: return "💪"
        case .track: return "🏆"
        case .offRoad: return "🏔️"
        case .rally: return "🌲"
        case .suv: return "🚙"
        case .truck: return "🚚"
        case .van: return "🚐"
        case .luxury: return "✨"
        case .sedan: return "🚘"
        case .coupe: return "🎯"
        case .convertible: return "☀️"
        case .wagon: return "📦"
        case .electric: return "⚡"
        case .hybrid: return "🔋"
        case .classic: return "🕰️"
        case .concept: return "🔮"
        case .hatchback: return "🚗"
        }
    }
    
    var description: String {
        switch self {
        case .hypercar: return "Ultimate performance machines"
        case .supercar: return "Exotic high-performance cars"
        case .sportsCar: return "Driver-focused performance"
        case .muscle: return "American V8 power"
        case .track: return "Circuit-ready racers"
        case .offRoad: return "Built for the trails"
        case .rally: return "Stage champions"
        case .suv: return "Sport utility vehicles"
        case .truck: return "Pickup trucks"
        case .van: return "Vans and people movers"
        case .luxury: return "Premium comfort"
        case .sedan: return "Four-door sedans"
        case .coupe: return "Two-door coupes"
        case .convertible: return "Open-top cruisers"
        case .wagon: return "Station wagons"
        case .electric: return "Battery-powered"
        case .hybrid: return "Electric + gas"
        case .classic: return "Vintage classics"
        case .concept: return "Concept and custom"
        case .hatchback: return "Practical hatchbacks"
        }
    }
}
