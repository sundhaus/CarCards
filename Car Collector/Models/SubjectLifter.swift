//
//  SubjectLifter.swift
//  CarCardCollector
//
//  Removes background from images using Vision framework
//

import UIKit
import Vision
import CoreImage

class SubjectLifter {
    // MARK: - Privacy Blur
    
    static func blurPrivacyRegions(in image: UIImage, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "SubjectLifter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])))
            return
        }
        
        var regionsToBlur: [CGRect] = []
        
        // Detect license plates via OCR
        let textRequest = VNRecognizeTextRequest { request, error in
            if let observations = request.results as? [VNRecognizedTextObservation] {
                for observation in observations {
                    guard let text = observation.topCandidates(1).first?.string else { continue }
                    
                    // License plate pattern: 5-8 characters, mix of letters and numbers
                    let cleanText = text.replacingOccurrences(of: " ", with: "")
                    if isLicensePlatePattern(cleanText) {
                        let boundingBox = observation.boundingBox
                        let imageRect = VNImageRectForNormalizedRect(
                            boundingBox,
                            Int(image.size.width),
                            Int(image.size.height)
                        )
                        // Expand the box significantly for better coverage
                        let expandedRect = imageRect.insetBy(dx: -20, dy: -15)
                        regionsToBlur.append(expandedRect)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if regionsToBlur.isEmpty {
                    // No plates found, return original
                    completion(.success(image))
                } else {
                    // Apply pixelation to detected plates
                    if let pixelated = applyBlur(to: image, regions: regionsToBlur) {
                        completion(.success(pixelated))
                    } else {
                        completion(.failure(NSError(domain: "SubjectLifter", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to apply pixelation"])))
                    }
                }
            }
        }
        textRequest.recognitionLevel = .accurate
        
        // Perform request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([textRequest])
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private static func isLicensePlatePattern(_ text: String) -> Bool {
        // Remove spaces and special characters
        let clean = text.uppercased().replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
        
        // Must be 5-8 characters
        guard clean.count >= 5 && clean.count <= 8 else { return false }
        
        // Must contain both letters and numbers
        let hasLetters = clean.rangeOfCharacter(from: CharacterSet.letters) != nil
        let hasNumbers = clean.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
        
        return hasLetters && hasNumbers
    }
    
    private static func applyBlur(to image: UIImage, regions: [CGRect]) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        var outputImage = ciImage
        
        // Apply pixelation to each region
        for region in regions {
            // Create pixelate filter
            guard let pixelateFilter = CIFilter(name: "CIPixellate") else { continue }
            pixelateFilter.setValue(outputImage.cropped(to: region), forKey: kCIInputImageKey)
            pixelateFilter.setValue(20.0, forKey: kCIInputScaleKey) // Larger pixels = more privacy
            
            guard let pixelatedRegion = pixelateFilter.outputImage else { continue }
            
            // Composite pixelated region over original
            outputImage = pixelatedRegion.composited(over: outputImage)
        }
        
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // MARK: - Subject Lifting
    
    static func liftSubject(from image: UIImage, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "SubjectLifter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])))
            return
        }
        
        // Create request handler first
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Create request to generate foreground instance mask
        let request = VNGenerateForegroundInstanceMaskRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let result = request.results?.first as? VNInstanceMaskObservation else {
                completion(.failure(NSError(domain: "SubjectLifter", code: -2, userInfo: [NSLocalizedDescriptionKey: "No subject detected"])))
                return
            }
            
            do {
                // Generate mask - use handler here
                let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                
                // Apply mask to original image
                if let maskedImage = applyMask(maskPixelBuffer, to: cgImage) {
                    completion(.success(maskedImage))
                } else {
                    completion(.failure(NSError(domain: "SubjectLifter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to apply mask"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        // Perform the request
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private static func applyMask(_ maskPixelBuffer: CVPixelBuffer, to image: CGImage) -> UIImage? {
        let ciImage = CIImage(cgImage: image)
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        // Scale mask to match image size
        let scaleX = ciImage.extent.width / maskImage.extent.width
        let scaleY = ciImage.extent.height / maskImage.extent.height
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // Create white background
        let whiteBackground = CIImage(color: .white).cropped(to: ciImage.extent)
        
        // Blend using mask
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
        blendFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blendFilter.setValue(whiteBackground, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(scaledMask, forKey: kCIInputMaskImageKey)
        
        guard let outputImage = blendFilter.outputImage else { return nil }
        
        // Convert back to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Apply mask with transparency (alpha channel preserved) for background compositing
    private static func applyMaskTransparent(_ maskPixelBuffer: CVPixelBuffer, to image: CGImage) -> UIImage? {
        let ciImage = CIImage(cgImage: image)
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        
        let scaleX = ciImage.extent.width / maskImage.extent.width
        let scaleY = ciImage.extent.height / maskImage.extent.height
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // Use clear/transparent background instead of white
        let clearBackground = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: ciImage.extent)
        
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
        blendFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blendFilter.setValue(clearBackground, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(scaledMask, forKey: kCIInputMaskImageKey)
        
        guard let outputImage = blendFilter.outputImage else { return nil }
        
        let context = CIContext()
        // Use RGBA8 color space to preserve alpha
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let cgResult = context.createCGImage(outputImage, from: outputImage.extent, format: .RGBA8, colorSpace: colorSpace) else { return nil }
        
        return UIImage(cgImage: cgResult)
    }
    
    /// Lift subject with transparent background (for compositing over custom backgrounds)
    static func liftSubjectTransparent(from image: UIImage, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "SubjectLifter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])))
            return
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        let request = VNGenerateForegroundInstanceMaskRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let result = request.results?.first as? VNInstanceMaskObservation else {
                completion(.failure(NSError(domain: "SubjectLifter", code: -2, userInfo: [NSLocalizedDescriptionKey: "No subject detected"])))
                return
            }
            
            do {
                let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                
                if let maskedImage = applyMaskTransparent(maskPixelBuffer, to: cgImage) {
                    completion(.success(maskedImage))
                } else {
                    completion(.failure(NSError(domain: "SubjectLifter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to apply transparent mask"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
}
