//
//  RSStatTile.swift
//  RoadSense
//

import SwiftUI

/// A number with a caption underneath: live counters and drive totals.
struct RSStatTile: View {
    enum Style {
        /// 38 pt counter.
        case counter
        /// 30 pt value with unit.
        case measure(unit: LocalizedStringKey)
    }

    let value: String
    let caption: LocalizedStringResource
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch style {
            case .counter:
                Text(value).rs(38, .heavy, tracking: -1.52, scales: false)
            case .measure(let unit):
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).rs(30, .heavy, tracking: -0.9, scales: false)
                    Text(unit).rs(14, .semibold)
                }
            }
            Text(caption).rs(12, .medium).foregroundStyle(Color.rsMuted)
        }
        .padding(.vertical, isCounter ? 16 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var isCounter: Bool {
        if case .counter = style { true } else { false }
    }
}
