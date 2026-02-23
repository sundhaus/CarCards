//
//  DeviceScale.swift
//  Car Collector
//
//  Provides responsive scaling based on device screen size.
//  All UI sizes flow through this so the app looks good on
//  iPhone SE, iPhone 12, iPhone 15 Pro, and iPad.
//
//  Reference device: iPhone 15 Pro (393pt wide, 852pt tall)
//

import SwiftUI

struct DeviceScale {
    /// Reference width (iPhone 15 Pro)
    static let referenceWidth: CGFloat = 393
    /// Reference height (iPhone 15 Pro)
    static let referenceHeight: CGFloat = 852
    
    /// Screen dimensions (cached at launch)
    static let screenWidth: CGFloat = UIScreen.main.bounds.width
    static let screenHeight: CGFloat = UIScreen.main.bounds.height
    
    /// Width scale factor relative to iPhone 15 Pro
    /// iPhone SE: ~0.87, iPhone 12: 0.99, iPhone 15 Pro: 1.0, iPad 11": ~1.56
    static let widthScale: CGFloat = {
        let raw = screenWidth / referenceWidth
        // Clamp iPad scaling so things don't get too large
        return min(raw, 1.4)
    }()
    
    /// Height scale factor
    static let heightScale: CGFloat = {
        let raw = screenHeight / referenceHeight
        return min(raw, 1.4)
    }()
    
    /// Combined scale (average of width and height, good for fonts/icons)
    static let scale: CGFloat = {
        (widthScale + heightScale) / 2.0
    }()
    
    /// Whether this is an iPad
    static let isIPad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    
    /// Whether this is a small phone (SE, iPhone 12 mini, etc)
    static let isSmallPhone: Bool = screenWidth < 380
    
    /// Scale a size value proportionally to screen width
    static func w(_ value: CGFloat) -> CGFloat {
        value * widthScale
    }
    
    /// Scale a size value proportionally to screen height
    static func h(_ value: CGFloat) -> CGFloat {
        value * heightScale
    }
    
    /// Scale for fonts/icons (uses combined scale)
    static func f(_ value: CGFloat) -> CGFloat {
        value * scale
    }
}
