//
//  PoppinsFont.swift
//  Car Collector
//
//  Global Futura-Bold font extension for all non-card UI text
//

import SwiftUI

extension Font {
    static func poppins(_ size: CGFloat) -> Font {
        .custom("Futura-Bold", size: size)
    }
    
    // Text style equivalents using Futura-Bold
    static let pLargeTitle = Font.custom("Futura-Bold", size: 34)
    static let pTitle = Font.custom("Futura-Bold", size: 28)
    static let pTitle2 = Font.custom("Futura-Bold", size: 22)
    static let pTitle3 = Font.custom("Futura-Bold", size: 20)
    static let pHeadline = Font.custom("Futura-Bold", size: 17)
    static let pBody = Font.custom("Futura-Bold", size: 17)
    static let pCallout = Font.custom("Futura-Bold", size: 16)
    static let pSubheadline = Font.custom("Futura-Bold", size: 15)
    static let pFootnote = Font.custom("Futura-Bold", size: 13)
    static let pCaption = Font.custom("Futura-Bold", size: 12)
    static let pCaption2 = Font.custom("Futura-Bold", size: 11)
}
