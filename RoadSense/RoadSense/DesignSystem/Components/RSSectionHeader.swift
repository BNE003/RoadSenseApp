//
//  RSSectionHeader.swift
//  RoadSense
//

import SwiftUI

extension View {
    /// Small uppercase label that opens a section.
    func rsEyebrow() -> some View {
        rs(12, .semibold, tracking: 0.96)
            .textCase(.uppercase)
            .foregroundStyle(Color.rsMuted)
    }
}

/// A section label with its spacing, e.g. "Vehicle".
struct RSSectionHeader: View {
    let title: LocalizedStringKey
    var top: CGFloat = 34
    var bottom: CGFloat = 10

    var body: some View {
        Text(title)
            .rsEyebrow()
            .padding(.top, top)
            .padding(.bottom, bottom)
            .accessibilityAddTraits(.isHeader)
    }
}
