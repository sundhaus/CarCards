//
//  SolidGlass.swift
//  Car Collector
//
//  Lightweight replacement for .glassEffect() that uses a solid
//  semi-transparent background instead of real-time backdrop blur.
//  Visually similar on dark backgrounds, zero GPU compositing cost.
//
//  To revert to real glass: delete this file and remove "Solid" from
//  all .solidGlass* calls (find-replace back to .glassEffect).
//

import SwiftUI

// MARK: - Solid Glass Style

/// A subtle dark translucent fill with a thin bright border —
/// mimics Liquid Glass on dark backgrounds without any blur.
struct SolidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    
    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        shape
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    }
            }
            .clipShape(shape)
    }
}

extension View {
    /// Solid replacement for `.glassEffect(.regular, in: .rect(cornerRadius:))`
    func solidGlass(cornerRadius: CGFloat) -> some View {
        modifier(SolidGlassModifier(shape: RoundedRectangle(cornerRadius: cornerRadius)))
    }
    
    /// Solid replacement for `.solidGlassCircle()`
    func solidGlassCircle() -> some View {
        modifier(SolidGlassModifier(shape: Circle()))
    }
    
    /// Solid replacement for `.solidGlassCapsule()`
    func solidGlassCapsule() -> some View {
        modifier(SolidGlassModifier(shape: Capsule()))
    }
}
