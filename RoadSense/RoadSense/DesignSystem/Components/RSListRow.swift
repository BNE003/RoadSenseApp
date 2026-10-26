//
//  RSListRow.swift
//  RoadSense
//

import SwiftUI

/// A drive row: ink rule on top, name and meta on the left, issue count on the right.
struct RSListRow: View {
    let title: String
    let meta: String
    let count: Int
    var titleSize: CGFloat = 17
    var countSize: CGFloat = 28
    var countColor: Color = .rsInk
    var verticalPadding: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            RSRule()
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).rs(titleSize, .bold, tracking: -0.01 * titleSize)
                    Text(meta).rs(13).foregroundStyle(Color.rsMuted)
                }
                Spacer(minLength: 8)
                Text(count.formatted())
                    .rs(countSize, .heavy, tracking: -0.03 * countSize, scales: false)
                    .foregroundStyle(countColor)
            }
            .padding(.vertical, verticalPadding)
        }
        .foregroundStyle(Color.rsInk)
        .accessibilityElement(children: .combine)
    }
}

/// A two-column value row: bold label left, muted value right.
struct RSValueRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(title).rs(17, .bold)
            Spacer()
            Text(value).rs(14, .medium).foregroundStyle(Color.rsMuted)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
