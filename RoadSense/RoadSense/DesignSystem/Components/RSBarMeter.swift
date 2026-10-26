//
//  RSBarMeter.swift
//  RoadSense
//

import SwiftUI

/// A 6 pt bar showing a share of the whole.
struct RSBarMeter: View {
    /// 0...1
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.rsTrack)
                Rectangle().fill(Color.rsInk).frame(width: geometry.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
