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
    var make: String
    var model: String
    var color: String
    var year: String
    var imageURL: String
    var createdAt: Date
    
    // ADDED: Metadata fields
    var capturedBy: String?
    var capturedLocation: String?
    var previousOwners: Int
    
    // From Firestore document
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.ownerId = data["ownerId"] as? String ?? ""
        self.make = data["make"] as? String ?? ""
        self.model = data["model"] as? String ?? ""
        self.color = data["color"] as? String ?? ""
        self.year = data["year"] as? String ?? ""
        self.imageURL = data["imageURL"] as? String ?? ""
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // ADDED: Load metadata
        self.capturedBy = data["capturedBy"] as? String
        self.capturedLocation = data["capturedLocation"] as? String
        self.previousOwners = data["previousOwners"] as? Int ?? 0
    }
    
    // New card
    init(
        id: String,
        ownerId: String,
        make: String,
        model: String,
        color: String,
        year: String,
        imageURL: String,
        capturedBy: String? = nil,
        capturedLocation: String? = nil,
        previousOwners: Int = 0
    ) {
        self.id = id
        self.ownerId = ownerId
        self.make = make
        self.model = model
        self.color = color
        self.year = year
        self.imageURL = imageURL
        self.createdAt = Date()
        self.capturedBy = capturedBy
        self.capturedLocation = capturedLocation
        self.previousOwners = previousOwners
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
        
        return dict
    }
}
