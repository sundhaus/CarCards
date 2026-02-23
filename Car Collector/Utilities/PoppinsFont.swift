//
//  PoppinsFont.swift
//  Car Collector
//
//  Global Futura-Bold font extension for all non-card UI text
//  Sizes scale dynamically based on device screen size
//

import SwiftUI

extension Font {
    static func poppins(_ size: CGFloat) -> Font {
        .custom("Futura-Bold", fixedSize: DeviceScale.f(size))
    }
    
    // Text style equivalents using Futura-Bold (responsive)
    static let pLargeTitle = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(34))
    static let pTitle = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(28))
    static let pTitle2 = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(22))
    static let pTitle3 = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(20))
    static let pHeadline = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(17))
    static let pBody = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(17))
    static let pCallout = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(16))
    static let pSubheadline = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(15))
    static let pFootnote = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(13))
    static let pCaption = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(12))
    static let pCaption2 = Font.custom("Futura-Bold", fixedSize: DeviceScale.f(11))
}
