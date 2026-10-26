//
//  Theme.swift
//  RoadSense
//

import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let rsInk = Color(hex: 0x1D2B26)
    static let rsGreen = Color(hex: 0x4A7358)
    static let rsPaper = Color(hex: 0xFAF9F6)
    static let rsMuted = Color(hex: 0x66726B)
    static let rsBody = Color(hex: 0x3F4B45)
    static let rsMint = Color(hex: 0xB9D6B5)
    static let rsTrack = Color(hex: 0xD9DFD7)
    static let rsMapGround = Color(hex: 0xE6EBE3)
    static let rsLiveGround = Color(hex: 0x0F1613)
}

/// Archivo isn't bundled, so the system font stands in with matching weights and tracking.
enum RSFont {
    static func make(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }
}

extension View {
    func rs(_ size: CGFloat, _ weight: Font.Weight = .regular, tracking: CGFloat = 0) -> some View {
        font(RSFont.make(size, weight)).tracking(tracking)
    }

    /// Small uppercase section label used across screens.
    func rsEyebrow() -> some View {
        rs(12, .semibold, tracking: 0.96)
            .textCase(.uppercase)
            .foregroundStyle(Color.rsMuted)
    }
}

/// The 2pt ink rule used as the design's primary divider.
struct RSRule: View {
    var color: Color = .rsInk
    var body: some View {
        Rectangle().fill(color).frame(height: 2)
    }
}

struct RSVRule: View {
    var body: some View {
        Rectangle().fill(Color.rsInk).frame(width: 2)
    }
}

struct RSLogo: View {
    var size: CGFloat = 30
    var body: some View {
        Image("Logo")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(Color.rsInk)
    }
}

struct RSWordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            RSLogo()
            HStack(spacing: 0) {
                Text("RoadSense").foregroundStyle(Color.rsInk)
                Text(".").foregroundStyle(Color.rsGreen)
            }
            .rs(17, .heavy, tracking: -0.34)
        }
    }
}

/// Square-cornered button style: no radius anywhere in this system.
struct RSBlockButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}
