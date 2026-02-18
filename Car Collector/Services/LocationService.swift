//
//  LocationService.swift
//  Car-Collector
//
//  Simple location service to get city name for card metadata
//

import Foundation
@preconcurrency import CoreLocation
import MapKit

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
        // Location will be requested automatically in authorization callback
    }
    
    func getCurrentLocation() {
        // Don't call requestLocation here - let the authorization callback handle it
        // This method is now just for checking status
        guard CLLocationManager.locationServicesEnabled() else {
            currentCity = "Unknown"
            return
        }
        
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            // Don't request location here - will be called from authorization callback
        case .notDetermined:
            // Authorization will be requested by requestPermission()
            break
        default:
            isAuthorized = false
            currentCity = "Unknown"
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        // Reverse geocode using MapKit (iOS 26 replacement for CLGeocoder)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            Task { @MainActor [weak self] in
                self?.currentCity = "Unknown"
            }
            return
        }
        
        request.getMapItems { [weak self] items, error in
            Task { @MainActor in
                guard let self else { return }
                
                if let error = error {
                    print("❌ Geocoding error: \(error)")
                    self.currentCity = "Unknown"
                    return
                }
                
                if let mapItem = items?.first {
                    // Use addressRepresentations for city name (iOS 26)
                    let city = mapItem.addressRepresentations?.cityWithContext ?? mapItem.name ?? "Unknown"
                    self.currentCity = city
                    print("📍 Location: \(city)")
                } else {
                    self.currentCity = "Unknown"
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error)")
        Task { @MainActor in
            self.currentCity = "Unknown"
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isAuthorized = true
                // Request location - CLLocationManager must be called from main thread
                self.manager.requestLocation()
            default:
                self.isAuthorized = false
                self.currentCity = "Unknown"
            }
        }
    }
}
