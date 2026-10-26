//
//  RSRule.swift
//  RoadSense
//

import SwiftUI

/// Horizontal 2 pt ink rule.
struct RSRule: View {
    var color: Color = .rsInk

    var body: some View {
        Rectangle().fill(color).frame(height: RSLayout.rule)
    }
}

/// Vertical 2 pt ink rule.
struct RSVRule: View {
    var body: some View {
        Rectangle().fill(Color.rsInk).frame(width: RSLayout.rule)
    }
}
