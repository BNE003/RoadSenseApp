//
//  RSWordmark.swift
//  RoadSense
//

import SwiftUI

struct RSLogo: View {
    var size: CGFloat = 30

    var body: some View {
        Image("Logo")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(Color.rsInk)
            .accessibilityHidden(true)
    }
}

/// Logo plus "RoadSense." with the green full stop.
struct RSWordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            RSLogo()
            HStack(spacing: 0) {
                Text(verbatim: "RoadSense").foregroundStyle(Color.rsInk)
                Text(verbatim: ".").foregroundStyle(Color.rsGreen)
            }
            .rs(17, .heavy, tracking: -0.34)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "RoadSense"))
    }
}
