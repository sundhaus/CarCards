//
//  CloudCard.swift
//  CarCardCollector
//
//  Cloud card model - UPDATED with metadata fields
//

import Foundation
import FirebaseFirestore

struct CloudCard: Identifiable, Codable {
    var id: String  // Firestore document ID
    var ownerId: String
    var cardType: String  // "vehicle", "driver", "location"
    var make: String
    var model: String
    var color: String
    var year: String
    var imageURL: String
    var createdAt: Date
    
    // Driver-specific fields
    var firstName: String?
    var lastName: String?
    var nickname: String?
    
    // Location-specific fields
    var locationName: String?
    
    // ADDED: Metadata fields
    var capturedBy: String?
    var capturedLocation: String?
    var previousOwners: Int
    
    // ADDED: Customization fields
    var customFrame: String?
    
    // From Firestore document
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.ownerId = data["ownerId"] as? String ?? ""
        self.cardType = data["type"] as? String ?? "vehicle"
        self.imageURL = data["imageURL"] as? String ?? ""
        self.createdAt = (data["capturedDate"] as? Timestamp)?.dateValue()
            ?? (data["createdAt"] as? Timestamp)?.dateValue()
            ?? Date()
        
        // Parse based on card type
        switch cardType {
        case "driver":
            self.firstName = data["firstName"] as? String ?? ""
            self.lastName = data["lastName"] as? String ?? ""
            self.nickname = data["nickname"] as? String
            self.make = self.firstName ?? ""
            self.model = self.lastName ?? ""
            self.color = "Driver"
            self.year = (self.nickname?.isEmpty == false) ? self.nickname! : "Driver"
        case "location":
            self.locationName = data["locationName"] as? String ?? ""
            self.make = self.locationName ?? ""
            self.model = ""
            self.color = "Location"
            self.year = "Location"
        default: // vehicle
            self.make = data["make"] as? String ?? ""
            self.model = data["model"] as? String ?? ""
            self.color = data["color"] as? String ?? ""
            self.year = data["year"] as? String ?? ""
        }
        
        // ADDED: Load metadata
        self.capturedBy = data["capturedBy"] as? String
        self.capturedLocation = data["capturedLocation"] as? String
        self.previousOwners = data["previousOwners"] as? Int ?? 0
        
        // ADDED: Load customization
        self.customFrame = data["customFrame"] as? String
    }
    
    // New card
    init(
        id: String,
        ownerId: String,
        cardType: String = "vehicle",
        make: String,
        model: String,
        color: String,
        year: String,
        imageURL: String,
        capturedBy: String? = nil,
        capturedLocation: String? = nil,
        previousOwners: Int = 0,
        customFrame: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.cardType = cardType
        self.make = make
        self.model = model
        self.color = color
        self.year = year
        self.imageURL = imageURL
        self.createdAt = Date()
        self.capturedBy = capturedBy
        self.capturedLocation = capturedLocation
        self.previousOwners = previousOwners
        self.customFrame = customFrame
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "ownerId": ownerId,
            "make": make,
            "model": model,
            "color": color,
            "year": year,
            "imageURL": imageURL,
            "createdAt": Timestamp(date: createdAt),
            "previousOwners": previousOwners
        ]
        
        // ADDED: Include metadata if present
        if let capturedBy = capturedBy {
            dict["capturedBy"] = capturedBy
        }
        if let capturedLocation = capturedLocation {
            dict["capturedLocation"] = capturedLocation
        }
        
        // ADDED: Include customization if present
        if let customFrame = customFrame {
            dict["customFrame"] = customFrame
        }
        
        return dict
    }
}
