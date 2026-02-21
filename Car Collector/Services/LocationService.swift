//
//  LocationService.swift
//  Car-Collector
//
//  Simple location service to get city name for card metadata
//

import Foundation
import Combine
@preconcurrency import CoreLocation
import MapKit

@MainActor
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    
    private let manager = CLLocationManager()
    @Published var currentCity: String = "Unknown"
    @Published var isAuthorized = false
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            currentCity = "Unknown"
            return
        }
        
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        case .notDetermined:
            break
        default:
            isAuthorized = false
            currentCity = "Unknown"
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        guard let request = MKReverseGeocodingRequest(location: location) else {
            Task { @MainActor in
                LocationService.shared.currentCity = "Unknown"
            }
            return
        }
        
        request.getMapItems { items, error in
            let city: String
            if error != nil {
                city = "Unknown"
            } else if let mapItem = items?.first {
                city = mapItem.addressRepresentations?.cityWithContext ?? mapItem.name ?? "Unknown"
            } else {
                city = "Unknown"
            }
            
            Task { @MainActor in
                LocationService.shared.currentCity = city
                print("📍 Location: \(city)")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error)")
        Task { @MainActor in
            LocationService.shared.currentCity = "Unknown"
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                LocationService.shared.isAuthorized = true
                LocationService.shared.manager.requestLocation()
            default:
                LocationService.shared.isAuthorized = false
                LocationService.shared.currentCity = "Unknown"
            }
        }
    }
}
