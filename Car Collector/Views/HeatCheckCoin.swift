//
//  HeatCheckCoin.swift
//  CarCardCollector
//
//  Single source of truth for all coin icons throughout the app.
//
//  ─── HOW TO SWAP IN YOUR SVG ────────────────────────────────────────────────
//  1. Add your SVG file to the Xcode project (Assets.xcassets or as a bundled
//     resource named "heatcheck_coin").
//  2. Change `coinMode` below from `.system` to `.svg`.
//  3. Build — every coin in the app updates automatically.
//  ────────────────────────────────────────────────────────────────────────────

import SwiftUI

// MARK: - Coin Mode Toggle

private enum CoinDisplayMode {
    /// Uses the SF Symbol fallback (current default)
    case system
    /// Uses the custom SVG asset named "heatcheck_coin"
    case svg
}

/// ⬇️  Change this ONE line to flip all coins across the entire app
private let coinMode: CoinDisplayMode = .svg

// MARK: - HeatCheckCoin View

/// Drop-in replacement for every coin icon in the app.
/// Use exactly like an `Image` — provide a `size` and optional `tint`.
///
/// Examples:
///   HeatCheckCoin(size: 20)
///   HeatCheckCoin(size: 16, tint: .orange)
///   HeatCheckCoin(size: 24, tint: .white)
struct HeatCheckCoin: View {

    /// Point size (width & height). Defaults to 20.
    var size: CGFloat = 20

    /// Tint applied to the coin image. Defaults to gold/yellow.
    var tint: Color = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        switch coinMode {
        case .system:
            systemCoin
        case .svg:
            svgCoin
        }
    }

    // MARK: - System fallback (SF Symbol)

    private var systemCoin: some View {
        Image(systemName: "dollarsign.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }

    // MARK: - SVG asset

    private var svgCoin: some View {
        // Uses the "HeatCheckCoin" asset from Assets.xcassets
        Image("HeatCheckCoin")
            .resizable()
            .renderingMode(.template)   // Allows tinting with foregroundStyle
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }
}

// MARK: - Convenience row helper

/// Pairs a HeatCheckCoin with a numeric coin amount — used in headers,
/// balance badges, price labels, etc.
///
/// Example:
///   CoinLabel(amount: 1250)
///   CoinLabel(amount: 500, size: 16, tint: .white, font: .subheadline)
struct CoinLabel: View {

    let amount: Int
    var size: CGFloat = 20
    var tint: Color = Color(red: 1.0, green: 0.84, blue: 0.0)
    var font: Font = .system(size: 16, weight: .semibold)
    var textColor: Color = .primary
    var spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            HeatCheckCoin(size: size, tint: tint)
            Text("\(amount)")
                .font(font)
                .foregroundStyle(textColor)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        Text("Coin Sizes")
            .font(.headline)

        HStack(spacing: 16) {
            HeatCheckCoin(size: 14)
            HeatCheckCoin(size: 20)
            HeatCheckCoin(size: 28)
            HeatCheckCoin(size: 36)
        }

        Divider()

        Text("Coin Labels")
            .font(.headline)

        CoinLabel(amount: 1250)
        CoinLabel(amount: 500, size: 16, tint: .orange, font: .subheadline, textColor: .secondary)

        ZStack {
            Color.black.ignoresSafeArea()
            CoinLabel(amount: 750, tint: .yellow, textColor: .white)
        }
        .frame(height: 60)
        .cornerRadius(12)
    }
    .padding()
}
