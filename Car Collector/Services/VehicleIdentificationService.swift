//
//  VehicleIdentificationService.swift
//  Car-Collector
//
//  OPTIMIZED VERSION - Fast AI identification with multiple options
//

import Foundation
import Combine
import UIKit
import FirebaseAILogic
import FirebaseFirestore

/// Simplified response - just what we need
struct VehicleIdentification: Codable, Identifiable {
    var id: String { "\(make)_\(model)_\(generation)" }  // Computed ID
    let isVehicle: Bool  // NEW: Is this actually a vehicle?
    let isAppropriate: Bool  // NEW: Is the content appropriate?
    let rejectionReason: String?  // NEW: Why was it rejected (if applicable)
    let make: String
    let model: String
    let generation: String  // Year range like "15-18"
    let confidence: String?  // "high", "medium", "low" - optional for backward compatibility
    
    // Custom init for backward compatibility
    init(make: String, model: String, generation: String, confidence: String? = nil, isVehicle: Bool = true, isAppropriate: Bool = true, rejectionReason: String? = nil) {
        self.make = make
        self.model = model
        self.generation = generation
        self.confidence = confidence
        self.isVehicle = isVehicle
        self.isAppropriate = isAppropriate
        self.rejectionReason = rejectionReason
    }
    
    // Convenience computed property
    var isValid: Bool {
        return isVehicle && isAppropriate
    }
}

/// Multiple vehicle options for user selection
struct VehicleIdentificationOptions: Codable {
    let options: [VehicleIdentification]
}

/// Vehicle specifications - cached in Firestore for ALL users
struct VehicleSpecs: Codable {
    let engine: String
    let horsepower: String
    let torque: String
    let zeroToSixty: String
    let topSpeed: String
    let transmission: String
    let drivetrain: String
    let description: String
    let category: VehicleCategory?  // Optional category for Explore page
    
    // Metadata
    let fetchedAt: Date
    let fetchedBy: String?  // Optional user ID who contributed this
    
    // Coding keys for custom decoder
    enum CodingKeys: String, CodingKey {
        case engine, horsepower, torque, zeroToSixty, topSpeed
        case transmission, drivetrain, description, category
        case fetchedAt, fetchedBy
    }
    
    init(engine: String, horsepower: String, torque: String, zeroToSixty: String,
         topSpeed: String, transmission: String, drivetrain: String, description: String,
         fetchedAt: Date = Date(), fetchedBy: String? = nil, category: VehicleCategory? = nil) {
        self.engine = engine
        self.horsepower = horsepower
        self.torque = torque
        self.zeroToSixty = zeroToSixty
        self.topSpeed = topSpeed
        self.transmission = transmission
        self.drivetrain = drivetrain
        self.description = description
        self.fetchedAt = fetchedAt
        self.fetchedBy = fetchedBy
        self.category = category
    }
    
    // Custom decoder for backward compatibility (handles missing category field)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        engine = try container.decode(String.self, forKey: .engine)
        horsepower = try container.decode(String.self, forKey: .horsepower)
        torque = try container.decode(String.self, forKey: .torque)
        zeroToSixty = try container.decode(String.self, forKey: .zeroToSixty)
        topSpeed = try container.decode(String.self, forKey: .topSpeed)
        transmission = try container.decode(String.self, forKey: .transmission)
        drivetrain = try container.decode(String.self, forKey: .drivetrain)
        description = try container.decode(String.self, forKey: .description)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        fetchedBy = try container.decodeIfPresent(String.self, forKey: .fetchedBy)
        
        // NEW: category is optional for backward compatibility
        category = try container.decodeIfPresent(VehicleCategory.self, forKey: .category)
    }
    
    // Custom encoder to ensure category is included
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(engine, forKey: .engine)
        try container.encode(horsepower, forKey: .horsepower)
        try container.encode(torque, forKey: .torque)
        try container.encode(zeroToSixty, forKey: .zeroToSixty)
        try container.encode(topSpeed, forKey: .topSpeed)
        try container.encode(transmission, forKey: .transmission)
        try container.encode(drivetrain, forKey: .drivetrain)
        try container.encode(description, forKey: .description)
        try container.encode(fetchedAt, forKey: .fetchedAt)
        try container.encodeIfPresent(fetchedBy, forKey: .fetchedBy)
        try container.encodeIfPresent(category, forKey: .category)
        
        print("📝 Encoding specs with category: \(category?.rawValue ?? "none")")
    }
}

/// Result wrapper
enum VehicleIDResult {
    case success(VehicleIdentification)
    case failure(Error)
}

/// Custom errors
enum VehicleIDError: LocalizedError {
    case invalidImage
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .apiError(let message):
            return "AI error: \(message)"
        }
    }
}

/// Fast vehicle identification service
@MainActor
class VehicleIdentificationService: ObservableObject {
    
    @Published var isIdentifying = false
    @Published var lastResult: VehicleIDResult?
    
    private let ai: FirebaseAI
    private let model: GenerativeModel
    private var cache: [Int: VehicleIdentification] = [:]
    private let db = Firestore.firestore()
    
    init() {
        ai = FirebaseAI.firebaseAI(backend: .googleAI())
        model = ai.generativeModel(modelName: "gemini-2.5-flash")
        
        #if DEBUG
        print("🤖 VehicleIdentificationService initialized (OPTIMIZED)")
        print("⚡ Fast mode: minimal prompt, auto-save")
        #endif
    }
    
    /// Get top 3 most likely vehicle identifications for user selection
    func identifyVehicleMultiple(from image: UIImage) async -> Result<[VehicleIdentification], Error> {
        isIdentifying = true
        defer { isIdentifying = false }
        
        do {
            guard let imageData = prepareImage(image) else {
                return .failure(VehicleIDError.invalidImage)
            }
            
            #if DEBUG
            print("📸 Image: \(imageData.count / 1024)KB")
            print("⚡ Getting top 3 vehicle options...")
            #endif
            
            let prompt = """
            VALIDATE then IDENTIFY - Return TOP 3 matches:
            
            Step 1 - VALIDATION:
            - Does this contain a REAL vehicle?
            - Is content appropriate?
            
            Step 2 - Return JSON with 3 options:
            {"options":[
                {
                  "isVehicle": true,
                  "isAppropriate": true,
                  "rejectionReason": null,
                  "make":"Toyota",
                  "model":"Camry",
                  "generation":"8th Gen",
                  "confidence":"high"
                },
                {"make":"Toyota","model":"Camry","generation":"7th Gen","confidence":"medium","isVehicle":true,"isAppropriate":true,"rejectionReason":null},
                {"make":"Toyota","model":"Avalon","generation":"5th Gen","confidence":"low","isVehicle":true,"isAppropriate":true,"rejectionReason":null}
            ]}
            
            REJECTION CASES:
            - If NOT a vehicle or inappropriate, return SINGLE option with flags:
            {"options":[{"isVehicle":false,"isAppropriate":true,"rejectionReason":"No vehicle detected","make":"","model":"","generation":"","confidence":""}]}
            
            If VALID, return EXACTLY 3 vehicle options ordered by confidence:
            - make: manufacturer
            - model: model name  
            - generation: generation name (e.g. "Evo IX", "Mk7") - NOT years unless unknown
            - confidence: "high", "medium", or "low"
            - Focus on different generations/trims if uncertain
            
            Return ONLY JSON, no markdown.
            """
            
            let response = try await self.model.generateContent(
                prompt,
                InlineDataPart(data: imageData, mimeType: "image/jpeg")
            )
            
            guard let text = response.text else {
                return .failure(VehicleIDError.apiError("No response"))
            }
            
            #if DEBUG
            print("🔥 Response: \(text)")
            #endif
            
            let options = try parseMultipleResponse(text)
            return .success(options.options)
            
        } catch {
            print("❌ Error: \(error)")
            return .failure(VehicleIDError.apiError(error.localizedDescription))
        }
    }
    
    /// Fast identification - only returns essentials (kept for backward compatibility)
    func identifyVehicle(from image: UIImage) async -> VehicleIDResult {
        isIdentifying = true
        defer { isIdentifying = false }
        
        // Check cache
        let imageHash = hashImage(image)
        if let cached = cache[imageHash] {
            print("✅ Using cached result")
            return .success(cached)
        }
        
        do {
            guard let imageData = prepareImage(image) else {
                return .failure(VehicleIDError.invalidImage)
            }
            
            #if DEBUG
            print("📸 Image: \(imageData.count / 1024)KB")
            print("⚡ Sending optimized request...")
            #endif
            
            let prompt = """
            VALIDATE then IDENTIFY this image:
            
            Step 1 - VALIDATION (Critical):
            - Does this image contain a REAL vehicle (car, truck, motorcycle, bus)?
            - Is the content appropriate (no offensive material, nudity, violence)?
            
            Step 2 - Return JSON:
            {
              "isVehicle": true/false,
              "isAppropriate": true/false,
              "rejectionReason": "reason if rejected, null if valid",
              "make": "Toyota",
              "model": "Camry",
              "generation": "8th Gen"
            }
            
            REJECTION RULES:
            - NOT a vehicle: Set isVehicle=false, rejectionReason="No vehicle detected in image"
            - Screenshot/meme: Set isVehicle=false, rejectionReason="Please capture a real vehicle with your camera"
            - Drawing/toy car: Set isVehicle=false, rejectionReason="Please capture a real, full-size vehicle"
            - Inappropriate content: Set isAppropriate=false, rejectionReason="Inappropriate content detected"
            - Valid vehicle: Set both true, rejectionReason=null
            
            If VALID vehicle:
            - make: manufacturer name
            - model: model name
            - generation: generation name (e.g. "8th Gen", "Mk7", "E90") - NOT years unless unknown
            
            Return ONLY the JSON, no markdown, no explanation.
            """
            
            let response = try await self.model.generateContent(
                prompt,
                InlineDataPart(data: imageData, mimeType: "image/jpeg")
            )
            
            guard let text = response.text else {
                return .failure(VehicleIDError.apiError("No response"))
            }
            
            #if DEBUG
            print("🔥 Response: \(text)")
            #endif
            
            let identification = try parseResponse(text)
            cache[imageHash] = identification
            
            let result = VehicleIDResult.success(identification)
            lastResult = result
            return result
            
        } catch {
            print("❌ Error: \(error)")
            let result = VehicleIDResult.failure(error)
            lastResult = result
            return result
        }
    }
    
    /// Fetch vehicle specs - checks FIRESTORE first (shared by all users!)
    func fetchSpecs(make: String, model: String, year: String) async throws -> VehicleSpecs {
        // Normalize the document ID - remove special chars, extra spaces, lowercase
        let normalizedMake = make.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = model.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedYear = year.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let docId = "\(normalizedMake)_\(normalizedModel)_\(normalizedYear)"
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        
        print("🔍 Looking for specs with docId: '\(docId)'")
        
        // Check Firestore first (shared cache)
        print("☁️ Checking Firestore for \(make) \(model) \(year)...")
        let docRef = db.collection("vehicleSpecs").document(docId)
        
        do {
            let snapshot = try await docRef.getDocument()
            
            if snapshot.exists {
                print("📄 Document exists in Firestore!")
                if let data = snapshot.data() {
                    print("📦 Document data: \(data.keys.joined(separator: ", "))")
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        var cached = try decoder.decode(VehicleSpecs.self, from: jsonData)
                        
                        // If cached specs don't have category, fetch and update
                        if cached.category == nil {
                            print("⚠️ Cached specs missing category - fetching from AI now")
                            
                            // Fetch category from AI
                            let categoryPrompt = """
                            Categorize: \(year) \(make) \(model)
                            
                            Return ONLY ONE category from this list (copy exactly):
                            Hypercar, Supercar, Sports Car, Muscle, Track, Off-Road, Rally, SUV, Truck, Van, Luxury, Sedan, Coupe, Convertible, Wagon, Electric, Hybrid, Classic, Concept, Hatchback
                            
                            Just the category name, nothing else.
                            """
                            
                            if let categoryResponse = try? await self.model.generateContent(categoryPrompt),
                               let categoryText = categoryResponse.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                               let category = VehicleCategory(rawValue: categoryText) {
                                
                                print("✅ Fetched category: \(category.rawValue)")
                                
                                // Update cached specs with category
                                cached = VehicleSpecs(
                                    engine: cached.engine,
                                    horsepower: cached.horsepower,
                                    torque: cached.torque,
                                    zeroToSixty: cached.zeroToSixty,
                                    topSpeed: cached.topSpeed,
                                    transmission: cached.transmission,
                                    drivetrain: cached.drivetrain,
                                    description: cached.description,
                                    fetchedAt: cached.fetchedAt,
                                    fetchedBy: cached.fetchedBy,
                                    category: category
                                )
                                
                                // Update Firestore with category
                                Task {
                                    do {
                                        let encoder = JSONEncoder()
                                        encoder.dateEncodingStrategy = .iso8601
                                        let jsonData = try encoder.encode(cached)
                                        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
                                        try await docRef.setData(json, merge: true)
                                        print("✅ Updated Firestore with category: \(category.rawValue)")
                                    } catch {
                                        print("⚠️ Failed to update Firestore: \(error)")
                                    }
                                }
                            } else {
                                print("⚠️ Could not fetch category for cached specs")
                            }
                        }
                        
                        print("✅ Successfully decoded specs from Firestore!")
                        print("✅ Category: \(cached.category?.rawValue ?? "none")")
                        return cached
                    } catch {
                        print("❌ Failed to decode specs data: \(error)")
                    }
                } else {
                    print("❌ Document exists but has no data")
                }
            } else {
                print("❌ Document does not exist in Firestore: \(docId)")
            }
        } catch {
            print("⚠️ Firestore check failed: \(error)")
        }
        
        // Not in Firestore - fetch from AI
        print("🔍 Fetching specs from AI for \(make) \(model) \(year)")
        
        let prompt = """
        For the \(year) \(make) \(model), provide:
        
        LINE 1: Category (choose ONE from this list, copy exactly):
        Hypercar, Supercar, Sports Car, Muscle, Track, Off-Road, Rally, SUV, Truck, Van, Luxury, Sedan, Coupe, Convertible, Wagon, Electric, Hybrid, Classic, Concept, Hatchback
        
        LINE 2 onwards: Specs as JSON:
        {"engine":"","horsepower":"","torque":"","zeroToSixty":"","topSpeed":"","transmission":"","drivetrain":"","description":""}
        
        Example format:
        Sports Car
        {"engine":"3.0L V6","horsepower":"400 hp",...}
        
        Specs details:
        - engine: engine type (e.g. "2.5L I4", "5.0L V8")
        - horsepower: HP (e.g. "300 hp")
        - torque: lb-ft (e.g. "280 lb-ft")
        - zeroToSixty: 0-60 time (e.g. "5.2s")
        - topSpeed: (e.g. "155 mph")
        - transmission: (e.g. "6-speed manual", "8-speed auto")
        - drivetrain: RWD/FWD/AWD/4WD
        - description: Punchy 2-3 sentence summary in FIFA Ultimate Team card style
        
        Use "N/A" if unknown. No markdown, no code blocks.
        """
        
        let response = try await self.model.generateContent(prompt)
        guard let text = response.text else {
            throw VehicleIDError.apiError("No specs response")
        }
        
        print("📥 Raw AI response:")
        print(text)
        
        // Parse category from first line, specs from rest
        let lines = text.components(separatedBy: .newlines)
        var category: VehicleCategory? = nil
        var specsText = text
        
        // Try to get category from first line
        if let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), !firstLine.isEmpty {
            // Check if first line is a valid category
            if let parsedCategory = VehicleCategory(rawValue: firstLine) {
                print("✅ Found category on first line: \(firstLine)")
                category = parsedCategory
                // Remove first line for specs parsing
                specsText = lines.dropFirst().joined(separator: "\n")
            } else {
                print("⚠️ First line '\(firstLine)' is not a valid category, treating as part of specs")
            }
        }
        
        // Parse specs
        var specs = try parseSpecs(specsText)
        
        // Add metadata and category
        let uid = FirebaseManager.shared.currentUserId
        specs = VehicleSpecs(
            engine: specs.engine,
            horsepower: specs.horsepower,
            torque: specs.torque,
            zeroToSixty: specs.zeroToSixty,
            topSpeed: specs.topSpeed,
            transmission: specs.transmission,
            drivetrain: specs.drivetrain,
            description: specs.description,
            fetchedAt: Date(),
            fetchedBy: uid,
            category: category
        )
        
        print("✅ Final specs with category: \(category?.rawValue ?? "NONE - THIS IS A PROBLEM!")")
        
        // Save to Firestore for ALL users
        Task {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(specs)
                let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
                
                print("💾 Saving to Firestore with category: \(json["category"] ?? "MISSING")")
                
                try await docRef.setData(json)
                print("☁️ Saved specs to Firestore with docId: '\(docId)'")
                print("✅ Now available to ALL users!")
            } catch {
                print("⚠️ Failed to save to Firestore: \(error)")
            }
        }
        
        return specs
    }
    
    private func parseSpecs(_ text: String) throws -> VehicleSpecs {
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown
        if cleanText.hasPrefix("```json") {
            cleanText = cleanText.replacingOccurrences(of: "```json", with: "")
        }
        if cleanText.hasPrefix("```") {
            cleanText = cleanText.replacingOccurrences(of: "```", with: "")
        }
        if cleanText.hasSuffix("```") {
            cleanText = String(cleanText.dropLast(3))
        }
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanText.data(using: .utf8) else {
            throw VehicleIDError.apiError("Parse error")
        }
        
        // Parse the basic fields
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] ?? [:]
        
        let specs = VehicleSpecs(
            engine: dict["engine"] ?? "N/A",
            horsepower: dict["horsepower"] ?? "N/A",
            torque: dict["torque"] ?? "N/A",
            zeroToSixty: dict["zeroToSixty"] ?? "N/A",
            topSpeed: dict["topSpeed"] ?? "N/A",
            transmission: dict["transmission"] ?? "N/A",
            drivetrain: dict["drivetrain"] ?? "N/A",
            description: dict["description"] ?? ""
        )
        
        print("✅ Parsed specs from AI")
        return specs
    }
    
    private func prepareImage(_ image: UIImage) -> Data? {
        // Smaller size for faster upload
        let maxDimension: CGFloat = 800
        let size = image.size
        
        var scaledImage = image
        if size.width > maxDimension || size.height > maxDimension {
            let scale = min(maxDimension / size.width, maxDimension / size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        }
        
        return scaledImage.jpegData(compressionQuality: 0.7)
    }
    
    private func parseResponse(_ text: String) throws -> VehicleIdentification {
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown
        if cleanText.hasPrefix("```json") {
            cleanText = cleanText.replacingOccurrences(of: "```json", with: "")
        }
        if cleanText.hasPrefix("```") {
            cleanText = cleanText.replacingOccurrences(of: "```", with: "")
        }
        if cleanText.hasSuffix("```") {
            cleanText = String(cleanText.dropLast(3))
        }
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanText.data(using: .utf8) else {
            throw VehicleIDError.apiError("Parse error")
        }
        
        do {
            // Try parsing with new validation fields
            let decoder = JSONDecoder()
            
            // First try to decode as dictionary to check validation
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let isVehicle = dict["isVehicle"] as? Bool ?? true
                let isAppropriate = dict["isAppropriate"] as? Bool ?? true
                let rejectionReason = dict["rejectionReason"] as? String
                let make = dict["make"] as? String ?? "Unknown"
                let model = dict["model"] as? String ?? "Unknown"
                let generation = dict["generation"] as? String ?? ""
                let confidence = dict["confidence"] as? String
                
                let identification = VehicleIdentification(
                    make: make,
                    model: model,
                    generation: generation,
                    confidence: confidence,
                    isVehicle: isVehicle,
                    isAppropriate: isAppropriate,
                    rejectionReason: rejectionReason
                )
                
                print("✅ Parsed validation: isVehicle=\(isVehicle), isAppropriate=\(isAppropriate)")
                if !identification.isValid {
                    print("⚠️ Rejected: \(rejectionReason ?? "unknown reason")")
                } else {
                    print("✅ Valid: \(make) \(model) \(generation)")
                }
                
                return identification
            }
            
            // Fallback to direct decode
            let identification = try decoder.decode(VehicleIdentification.self, from: data)
            return identification
            
        } catch {
            print("❌ Parse error: \(error)")
            // Return rejection instead of unknown vehicle
            return VehicleIdentification(
                make: "Unknown",
                model: "Unknown",
                generation: "",
                confidence: nil,
                isVehicle: false,
                isAppropriate: false,
                rejectionReason: "Failed to parse AI response"
            )
        }
    }
    
    private func parseMultipleResponse(_ text: String) throws -> VehicleIdentificationOptions {
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown
        if cleanText.hasPrefix("```json") {
            cleanText = cleanText.replacingOccurrences(of: "```json", with: "")
        }
        if cleanText.hasPrefix("```") {
            cleanText = cleanText.replacingOccurrences(of: "```", with: "")
        }
        if cleanText.hasSuffix("```") {
            cleanText = String(cleanText.dropLast(3))
        }
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanText.data(using: .utf8) else {
            throw VehicleIDError.apiError("Parse error")
        }
        
        do {
            let options = try JSONDecoder().decode(VehicleIdentificationOptions.self, from: data)
            print("✅ Parsed \(options.options.count) options:")
            for (index, option) in options.options.enumerated() {
                print("   \(index + 1). \(option.make) \(option.model) \(option.generation) (\(option.confidence ?? "unknown"))")
            }
            return options
        } catch {
            print("❌ Parse error: \(error)")
            throw VehicleIDError.apiError("Failed to parse options: \(error.localizedDescription)")
        }
    }
    
    private func hashImage(_ image: UIImage) -> Int {
        guard let data = image.jpegData(compressionQuality: 0.1) else {
            return UUID().hashValue
        }
        return data.hashValue
    }
    
    func clearCache() {
        cache.removeAll()
    }
}
