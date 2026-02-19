//
//  CardImageStore.swift
//  Car Collector
//
//  File-based image storage for card images.
//  Stores images as individual JPEG files on disk instead of
//  embedding them in UserDefaults/JSON, dramatically reducing
//  memory footprint at idle.
//

import UIKit

final class CardImageStore {
    static let shared = CardImageStore()
    
    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, UIImage>()
    
    // Separate directories for each card type
    private let vehicleDir: URL
    private let driverDir: URL
    private let locationDir: URL
    
    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let base = docs.appendingPathComponent("CardImages", isDirectory: true)
        
        vehicleDir = base.appendingPathComponent("vehicles", isDirectory: true)
        driverDir = base.appendingPathComponent("drivers", isDirectory: true)
        locationDir = base.appendingPathComponent("locations", isDirectory: true)
        
        // Create directories if needed
        for dir in [vehicleDir, driverDir, locationDir] {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        // Configure cache - limit to ~30MB decoded pixels in memory
        imageCache.totalCostLimit = 30 * 1024 * 1024
        imageCache.countLimit = 30
    }
    
    /// Estimated decoded memory size of a UIImage
    private func imageCost(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 500_000 }
        return cg.bytesPerRow * cg.height
    }
    
    // MARK: - Vehicle Card Images
    
    func saveVehicleImage(_ image: UIImage, for cardId: UUID) {
        let url = vehicleDir.appendingPathComponent("\(cardId.uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
            imageCache.setObject(image, forKey: cardId.uuidString as NSString, cost: imageCost(image))
        }
    }
    
    func saveVehicleOriginal(_ image: UIImage, for cardId: UUID) {
        let url = vehicleDir.appendingPathComponent("\(cardId.uuidString)_original.jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    func loadVehicleImage(for cardId: UUID) -> UIImage? {
        let key = cardId.uuidString as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        
        let url = vehicleDir.appendingPathComponent("\(cardId.uuidString).jpg")
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        
        imageCache.setObject(image, forKey: key, cost: imageCost(image))
        return image
    }
    
    func loadVehicleOriginal(for cardId: UUID) -> UIImage? {
        let url = vehicleDir.appendingPathComponent("\(cardId.uuidString)_original.jpg")
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        return image
    }
    
    func deleteVehicleImages(for cardId: UUID) {
        let main = vehicleDir.appendingPathComponent("\(cardId.uuidString).jpg")
        let original = vehicleDir.appendingPathComponent("\(cardId.uuidString)_original.jpg")
        try? fileManager.removeItem(at: main)
        try? fileManager.removeItem(at: original)
        imageCache.removeObject(forKey: cardId.uuidString as NSString)
    }
    
    func deleteVehicleOriginal(for cardId: UUID) {
        let original = vehicleDir.appendingPathComponent("\(cardId.uuidString)_original.jpg")
        try? fileManager.removeItem(at: original)
    }
    
    // MARK: - Driver Card Images
    
    func saveDriverImage(_ image: UIImage, for cardId: UUID) {
        let url = driverDir.appendingPathComponent("\(cardId.uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
            imageCache.setObject(image, forKey: "driver_\(cardId.uuidString)" as NSString, cost: imageCost(image))
        }
    }
    
    func loadDriverImage(for cardId: UUID) -> UIImage? {
        let key = "driver_\(cardId.uuidString)" as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        
        let url = driverDir.appendingPathComponent("\(cardId.uuidString).jpg")
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        
        imageCache.setObject(image, forKey: key, cost: imageCost(image))
        return image
    }
    
    func deleteDriverImage(for cardId: UUID) {
        let url = driverDir.appendingPathComponent("\(cardId.uuidString).jpg")
        try? fileManager.removeItem(at: url)
        imageCache.removeObject(forKey: "driver_\(cardId.uuidString)" as NSString)
    }
    
    // MARK: - Location Card Images
    
    func saveLocationImage(_ image: UIImage, for cardId: UUID) {
        let url = locationDir.appendingPathComponent("\(cardId.uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
            imageCache.setObject(image, forKey: "location_\(cardId.uuidString)" as NSString, cost: imageCost(image))
        }
    }
    
    func loadLocationImage(for cardId: UUID) -> UIImage? {
        let key = "location_\(cardId.uuidString)" as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        
        let url = locationDir.appendingPathComponent("\(cardId.uuidString).jpg")
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        
        imageCache.setObject(image, forKey: key, cost: imageCost(image))
        return image
    }
    
    func deleteLocationImage(for cardId: UUID) {
        let url = locationDir.appendingPathComponent("\(cardId.uuidString).jpg")
        try? fileManager.removeItem(at: url)
        imageCache.removeObject(forKey: "location_\(cardId.uuidString)" as NSString)
    }
    
    // MARK: - Utilities
    
    func clearCache() {
        imageCache.removeAllObjects()
    }
    
    /// Check if a vehicle image file exists on disk
    func vehicleImageExists(for cardId: UUID) -> Bool {
        let url = vehicleDir.appendingPathComponent("\(cardId.uuidString).jpg")
        return fileManager.fileExists(atPath: url.path)
    }
}
