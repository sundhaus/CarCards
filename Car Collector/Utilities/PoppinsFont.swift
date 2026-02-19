//
//  PoppinsFont.swift
//  Car Collector
//
//  Global Poppins-Bold font extension for all non-card UI text
//

import SwiftUI

extension Font {
    static func poppins(_ size: CGFloat) -> Font {
        .custom("Poppins-Bold", size: size)
    }
    
    // Text style equivalents using Poppins-Bold
    static let pLargeTitle = Font.custom("Poppins-Bold", size: 34)
    static let pTitle = Font.custom("Poppins-Bold", size: 28)
    static let pTitle2 = Font.custom("Poppins-Bold", size: 22)
    static let pTitle3 = Font.custom("Poppins-Bold", size: 20)
    static let pHeadline = Font.custom("Poppins-Bold", size: 17)
    static let pBody = Font.custom("Poppins-Bold", size: 17)
    static let pCallout = Font.custom("Poppins-Bold", size: 16)
    static let pSubheadline = Font.custom("Poppins-Bold", size: 15)
    static let pFootnote = Font.custom("Poppins-Bold", size: 13)
    static let pCaption = Font.custom("Poppins-Bold", size: 12)
    static let pCaption2 = Font.custom("Poppins-Bold", size: 11)
}
