//
//  Colors.swift
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
    static let rsLiveGround = Color(hex: 0x0F1613)
    // Camera placeholder (replaced by the real preview in Milestone 2)
    static let rsFeedSky = Color(hex: 0x26302B)
    static let rsFeedHorizon = Color(hex: 0x566159)
    static let rsFeedRoadside = Color(hex: 0x18201C)
}
