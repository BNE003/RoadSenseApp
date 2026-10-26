//
//  Typography.swift
//  RoadSense
//

import CoreText
import SwiftUI
import UIKit

/// Archivo, the design's typeface, bundled as a variable font.
enum RSFont {
    private static let weightAxis = 2_003_265_652  // 'wght'

    /// Registers the bundled font. Call once at launch.
    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "Archivo", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func make(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        // The font's default weight axis value is 600, so the weight is always set explicitly.
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: "Archivo",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [weightAxis: axisValue(weight)],
        ])
        return Font(UIFont(descriptor: descriptor, size: size) as CTFont)
    }

    private static func axisValue(_ weight: Font.Weight) -> Int {
        switch weight {
        case .ultraLight: 100
        case .thin: 200
        case .light: 300
        case .regular: 400
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
    }
}

private struct RSTextStyle: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let tracking: CGFloat
    let scales: Bool
    @ScaledMetric(relativeTo: .body) private var factor: CGFloat = 1

    func body(content: Content) -> some View {
        let scaled = scales ? factor : 1
        content
            .font(RSFont.make(size * scaled, weight))
            .tracking(tracking * scaled)
    }
}

extension View {
    /// Design type style: size in points, weight, tracking in points. Text scales with Dynamic Type
    /// unless `scales` is false (large display numerals that would break their layout).
    func rs(_ size: CGFloat, _ weight: Font.Weight = .regular, tracking: CGFloat = 0, scales: Bool = true) -> some View {
        modifier(RSTextStyle(size: size, weight: weight, tracking: tracking, scales: scales))
    }
}
