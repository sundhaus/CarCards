//
//  CardImageStore.swift
//  Car Collector
//
//  File-based image storage for card images.
//  Stores full-res images + compressed thumbnails on disk.
//  Grid views use thumbnails (~50KB decoded), fullscreen loads full-res on demand.
//

import UIKit
import ImageIO

final class CardImageStore {
    static let shared = CardImageStore()
    
    private let fileManager = FileManager.default
    
    // Separate caches for thumbnails and full-res
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let fullResCache = NSCache<NSString, UIImage>()
    
    // Separate directories for each card type
    private let vehicleDir: URL
    private let driverDir: URL
    private let locationDir: URL
    private let thumbnailDir: URL
    
    // Thumbnail size — 400px wide covers 2-column grid at 3x retina
    private let thumbnailMaxDimension: CGFloat = 400
    
    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let base = docs.appendingPathComponent("CardImages", isDirectory: true)
        
        vehicleDir = base.appendingPathComponent("vehicles", isDirectory: true)
        driverDir = base.appendingPathComponent("drivers", isDirectory: true)
        locationDir = base.appendingPathComponent("locations", isDirectory: true)
        thumbnailDir = base.appendingPathComponent("thumbnails", isDirectory: true)
        
        for dir in [vehicleDir, driverDir, locationDir, thumbnailDir] {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        // Thumbnails: generous cache since they're tiny (~50KB decoded each)
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024
        thumbnailCache.countLimit = 200
        
        // Full-res: strict limit since they're huge (~8MB decoded each)
        fullResCache.totalCostLimit = 40 * 1024 * 1024
        fullResCache.countLimit = 5
    }
    
    private func imageCost(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 500_000 }
        return cg.bytesPerRow * cg.height
    }
    
    // MARK: - Thumbnail Generation
    
    private func generateThumbnail(from image: UIImage) -> UIImage? {
        let maxDim = thumbnailMaxDimension
        let size = image.size
        let scale = maxDim / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Generate thumbnail from JPEG on disk using ImageIO — never decodes full image
    private func generateThumbnailFromDisk(at url: URL) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxDimension
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    private func saveThumbnail(_ thumbnail: UIImage, key: String) {
        let url = thumbnailDir.appendingPathComponent("\(key)_thumb.jpg")
        if let data = thumbnail.jpegData(compressionQuality: 0.7) {
            try? data.write(to: url, options: .atomic)
        }
        thumbnailCache.setObject(thumbnail, forKey: key as NSString, cost: imageCost(thumbnail))
    }
    
    private func loadThumbnail(key: String, fullResURL: URL) -> UIImage? {
        if let cached = thumbnailCache.object(forKey: key as NSString) {
            return cached
        }
        
        let thumbURL = thumbnailDir.appendingPathComponent("\(key)_thumb.jpg")
        if let data = try? Data(contentsOf: thumbURL),
           let thumb = UIImage(data: data) {
            thumbnailCache.setObject(thumb, forKey: key as NSString, cost: imageCost(thumb))
            return thumb
        }
        
        if let thumb = generateThumbnailFromDisk(at: fullResURL) {
            saveThumbnail(thumb, key: key)
            return thumb
        }
        
        return nil
    }
    
    /// Load using ImageIO downsampling to a capped dimension
    private func loadDownsampled(from url: URL, maxDimension: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Vehicle Card Images
    
    func saveVehicleImage(_ image: UIImage, for cardId: UUID) {
        let url = vehicleDir.appendingPathComponent("\(cardId.uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
        }
        if let thumb = generateThumbnail(from: image) {
            saveThumbnail(thumb, key: cardId.uuidString)
        }
    }
    
    func saveVehicleOriginal(_ image: UIImage, for cardId: UUID) {
        let url = vehicleDir.appendingPathComponent("\(cardId.uuidString)_original.jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    func loadVehicleThumbnail(for cardId: UUID) -> UIImage? {
        loadThumbnail(key: cardId.uuidString, fullResURL: vehicleDir.appendingPathComponent("\(cardId.uuidString).jpg"))
    }
    
    func loadVehicleImage(for cardId: UUID) -> UIImage? {
        let key = cardId.uuidString as NSString
        if let cached = fullResCache.object(forKey: key) { return cached }
        let url = vehicleDir.appendingPathComponent("\(cardId.uuidString).jpg")
        guard let image = loadDownsampled(from: url, maxDimension: 2048) else { return nil }
        fullResCache.setObject(image, forKey: key, cost: imageCost(image))
        return image
    }
    
    func loadVehicleOriginal(for cardId: UUID) -> UIImage? {
        let url = vehicleDir.appendingPathComponent("\(cardId.uuidString)_original.jpg")
        return loadDownsampled(from: url, maxDimension: 2048)
    }
    
    func deleteVehicleImages(for cardId: UUID) {
        for suffix in [".jpg", "_original.jpg"] {
            try? fileManager.removeItem(at: vehicleDir.appendingPathComponent("\(cardId.uuidString)\(suffix)"))
        }
        try? fileManager.removeItem(at: thumbnailDir.appendingPathComponent("\(cardId.uuidString)_thumb.jpg"))
        fullResCache.removeObject(forKey: cardId.uuidString as NSString)
        thumbnailCache.removeObject(forKey: cardId.uuidString as NSString)
    }
    
    func deleteVehicleOriginal(for cardId: UUID) {
        try? fileManager.removeItem(at: vehicleDir.appendingPathComponent("\(cardId.uuidString)_original.jpg"))
    }
    
    // MARK: - Driver Card Images
    
    func saveDriverImage(_ image: UIImage, for cardId: UUID) {
        let url = driverDir.appendingPathComponent("\(cardId.uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
        }
        if let thumb = generateThumbnail(from: image) {
            saveThumbnail(thumb, key: "driver_\(cardId.uuidString)")
        }
    }
    
    func loadDriverThumbnail(for cardId: UUID) -> UIImage? {
        loadThumbnail(key: "driver_\(cardId.uuidString)", fullResURL: driverDir.appendingPathComponent("\(cardId.uuidString).jpg"))
    }
    
    func loadDriverImage(for cardId: UUID) -> UIImage? {
        let key = "driver_\(cardId.uuidString)" as NSString
        if let cached = fullResCache.object(forKey: key) { return cached }
        let url = driverDir.appendingPathComponent("\(cardId.uuidString).jpg")
        guard let image = loadDownsampled(from: url, maxDimension: 2048) else { return nil }
        fullResCache.setObject(image, forKey: key, cost: imageCost(image))
        return image
    }
    
    func deleteDriverImage(for cardId: UUID) {
        try? fileManager.removeItem(at: driverDir.appendingPathComponent("\(cardId.uuidString).jpg"))
        try? fileManager.removeItem(at: thumbnailDir.appendingPathComponent("driver_\(cardId.uuidString)_thumb.jpg"))
        fullResCache.removeObject(forKey: "driver_\(cardId.uuidString)" as NSString)
        thumbnailCache.removeObject(forKey: "driver_\(cardId.uuidString)" as NSString)
    }
    
    // MARK: - Location Card Images
    
    func saveLocationImage(_ image: UIImage, for cardId: UUID) {
        let url = locationDir.appendingPathComponent("\(cardId.uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
        }
        if let thumb = generateThumbnail(from: image) {
            saveThumbnail(thumb, key: "location_\(cardId.uuidString)")
        }
    }
    
    func loadLocationThumbnail(for cardId: UUID) -> UIImage? {
        loadThumbnail(key: "location_\(cardId.uuidString)", fullResURL: locationDir.appendingPathComponent("\(cardId.uuidString).jpg"))
    }
    
    func loadLocationImage(for cardId: UUID) -> UIImage? {
        let key = "location_\(cardId.uuidString)" as NSString
        if let cached = fullResCache.object(forKey: key) { return cached }
        let url = locationDir.appendingPathComponent("\(cardId.uuidString).jpg")
        guard let image = loadDownsampled(from: url, maxDimension: 2048) else { return nil }
        fullResCache.setObject(image, forKey: key, cost: imageCost(image))
        return image
    }
    
    func deleteLocationImage(for cardId: UUID) {
        try? fileManager.removeItem(at: locationDir.appendingPathComponent("\(cardId.uuidString).jpg"))
        try? fileManager.removeItem(at: thumbnailDir.appendingPathComponent("location_\(cardId.uuidString)_thumb.jpg"))
        fullResCache.removeObject(forKey: "location_\(cardId.uuidString)" as NSString)
        thumbnailCache.removeObject(forKey: "location_\(cardId.uuidString)" as NSString)
    }
    
    // MARK: - Utilities
    
    func clearCache() {
        thumbnailCache.removeAllObjects()
        fullResCache.removeAllObjects()
    }
    
    func vehicleImageExists(for cardId: UUID) -> Bool {
        fileManager.fileExists(atPath: vehicleDir.appendingPathComponent("\(cardId.uuidString).jpg").path)
    }
}
