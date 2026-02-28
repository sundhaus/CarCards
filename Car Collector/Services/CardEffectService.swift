//
//  CardEffectService.swift
//  CarCardCollector
//
//  Pro feature: AI-powered card effects using Gemini image generation
//  Generates unique visual effects (smoke, nitro, etc.) on card images
//
//  Flow:
//  1. User picks an effect from curated menu (sees 3 static preview examples)
//  2. Taps "Continue" → generates their card with the effect (1 API call)
//  3. If unhappy → 1 free reroll, pick between the two results
//
//  Cost: ~$0.04–$0.08 per effect use (1-2 Gemini API calls)
//

import Foundation
import FirebaseAI
import UIKit

// MARK: - Effect Types

enum CardEffect: String, CaseIterable, Identifiable, Codable {
    case smoke = "smoke"
    // Future effects:
    // case nitroBoost = "nitro_boost"
    // case burnout = "burnout"
    // case sparks = "sparks"
    // case rain = "rain"
    // case speedBlur = "speed_blur"
    // case lightning = "lightning"
    // case neonGlow = "neon_glow"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .smoke: return "Smoke Trail"
        }
    }
    
    var description: String {
        switch self {
        case .smoke: return "Dramatic smoke and exhaust effects billowing around your vehicle"
        }
    }
    
    var iconName: String {
        switch self {
        case .smoke: return "cloud.fill"
        }
    }
    
    /// The carefully crafted prompt template for this effect.
    /// {CAR_DESCRIPTION} will be replaced with the actual vehicle info.
    var promptTemplate: String {
        switch self {
        case .smoke:
            return """
            Take this car card image and add a dramatic smoke effect to it. \
            Add thick, volumetric white and light gray smoke billowing from behind \
            and around the lower half of the vehicle, as if the car just did a \
            massive burnout. The smoke should drift naturally across the scene, \
            partially obscuring the ground and lower body of the car. Keep the \
            upper portion of the vehicle clearly visible. The smoke should have \
            realistic depth and transparency, with some wisps curling upward. \
            Maintain the original card's 16:9 landscape aspect ratio exactly. \
            Do NOT add any text, watermarks, or borders. \
            The result should look like a premium collectible trading card with \
            cinematic smoke effects.
            """
        }
    }
}

// MARK: - Generation Result

struct EffectGenerationResult {
    let originalImage: UIImage
    let effectImage: UIImage
    let effect: CardEffect
    let timestamp: Date
    
    init(original: UIImage, effectImage: UIImage, effect: CardEffect) {
        self.originalImage = original
        self.effectImage = effectImage
        self.effect = effect
        self.timestamp = Date()
    }
}

// MARK: - Errors

enum CardEffectError: LocalizedError {
    case notProUser
    case noEffectsRemaining
    case invalidImage
    case generationFailed(String)
    case noImageInResponse
    
    var errorDescription: String? {
        switch self {
        case .notProUser:
            return "Card effects are a Pro subscription feature"
        case .noEffectsRemaining:
            return "No effect uses remaining this month"
        case .invalidImage:
            return "Could not process the card image"
        case .generationFailed(let message):
            return "Effect generation failed: \(message)"
        case .noImageInResponse:
            return "No image was returned from the AI model"
        }
    }
}

// MARK: - Card Effect Service

@MainActor
class CardEffectService: ObservableObject {
    static let shared = CardEffectService()
    
    @Published var isGenerating = false
    @Published var currentResult: EffectGenerationResult?
    @Published var rerollResult: EffectGenerationResult?
    @Published var hasUsedReroll = false
    
    private let ai: FirebaseAI
    private let model: GenerativeModel
    
    private init() {
        ai = FirebaseAI.firebaseAI(backend: .googleAI())
        
        // Use gemini-2.5-flash-image for image generation
        // This model supports responseModalities: [.text, .image]
        model = ai.generativeModel(
            modelName: "gemini-2.5-flash-preview-image",
            generationConfig: GenerationConfig(
                responseModalities: [.text, .image]
            )
        )
        
        #if DEBUG
        print("🎨 CardEffectService initialized")
        print("💨 Available effects: \(CardEffect.allCases.map { $0.displayName })")
        #endif
    }
    
    // MARK: - Generate Effect
    
    /// Generate an effect on the given card image.
    /// This is the main generation call (~$0.04 per call).
    func generateEffect(
        on cardImage: UIImage,
        effect: CardEffect,
        carDescription: String = ""
    ) async throws -> EffectGenerationResult {
        isGenerating = true
        hasUsedReroll = false
        rerollResult = nil
        
        defer { isGenerating = false }
        
        guard let imageData = prepareImage(cardImage) else {
            throw CardEffectError.invalidImage
        }
        
        let prompt = effect.promptTemplate
        
        #if DEBUG
        print("🎨 Generating \(effect.displayName) effect...")
        print("📸 Image size: \(imageData.count / 1024)KB")
        #endif
        
        do {
            let response = try await model.generateContent(
                InlineDataPart(data: imageData, mimeType: "image/jpeg"),
                prompt
            )
            
            // Extract the generated image from response
            guard let candidate = response.candidates.first else {
                throw CardEffectError.noImageInResponse
            }
            
            for part in candidate.content.parts {
                if let inlineDataPart = part as? InlineDataPart {
                    guard let generatedImage = UIImage(data: inlineDataPart.data) else {
                        throw CardEffectError.generationFailed("Could not decode generated image")
                    }
                    
                    // Resize to match card dimensions (360 x 202.5 at 2x = 720 x 405)
                    let finalImage = resizeToCardDimensions(generatedImage)
                    
                    let result = EffectGenerationResult(
                        original: cardImage,
                        effectImage: finalImage,
                        effect: effect
                    )
                    
                    currentResult = result
                    
                    #if DEBUG
                    print("✅ Effect generated successfully!")
                    #endif
                    
                    return result
                }
            }
            
            throw CardEffectError.noImageInResponse
            
        } catch let error as CardEffectError {
            throw error
        } catch {
            #if DEBUG
            print("❌ Effect generation error: \(error)")
            #endif
            throw CardEffectError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Reroll
    
    /// Generate a second version of the effect (1 free reroll per use).
    /// User can then pick between the two results.
    func reroll(
        on cardImage: UIImage,
        effect: CardEffect
    ) async throws -> EffectGenerationResult {
        guard !hasUsedReroll else {
            throw CardEffectError.generationFailed("Reroll already used")
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        guard let imageData = prepareImage(cardImage) else {
            throw CardEffectError.invalidImage
        }
        
        // Slightly varied prompt for different output
        let prompt = effect.promptTemplate + " Make this variation distinct from previous generations — vary the smoke density, direction, and spread pattern."
        
        #if DEBUG
        print("🔄 Rerolling \(effect.displayName) effect...")
        #endif
        
        do {
            let response = try await model.generateContent(
                InlineDataPart(data: imageData, mimeType: "image/jpeg"),
                prompt
            )
            
            guard let candidate = response.candidates.first else {
                throw CardEffectError.noImageInResponse
            }
            
            for part in candidate.content.parts {
                if let inlineDataPart = part as? InlineDataPart {
                    guard let generatedImage = UIImage(data: inlineDataPart.data) else {
                        throw CardEffectError.generationFailed("Could not decode reroll image")
                    }
                    
                    let finalImage = resizeToCardDimensions(generatedImage)
                    
                    let result = EffectGenerationResult(
                        original: cardImage,
                        effectImage: finalImage,
                        effect: effect
                    )
                    
                    rerollResult = result
                    hasUsedReroll = true
                    
                    #if DEBUG
                    print("✅ Reroll generated successfully!")
                    #endif
                    
                    return result
                }
            }
            
            throw CardEffectError.noImageInResponse
            
        } catch let error as CardEffectError {
            throw error
        } catch {
            throw CardEffectError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Reset
    
    /// Reset state for a new effect generation session
    func reset() {
        currentResult = nil
        rerollResult = nil
        hasUsedReroll = false
        isGenerating = false
    }
    
    // MARK: - Image Helpers
    
    /// Prepare card image for API upload — compress and scale appropriately
    private func prepareImage(_ image: UIImage) -> Data? {
        // Target ~1024px on longest edge for good quality at reasonable token cost
        let maxDimension: CGFloat = 1024
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
        
        return scaledImage.jpegData(compressionQuality: 0.85)
    }
    
    /// Resize generated image to match card dimensions (16:9, 720x405 @2x)
    private func resizeToCardDimensions(_ image: UIImage) -> UIImage {
        let targetSize = CGSize(width: 720, height: 405) // 360x202.5 @2x
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resized
    }
}
