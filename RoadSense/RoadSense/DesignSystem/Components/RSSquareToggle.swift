//
//  RSSquareToggle.swift
//  RoadSense
//

import SwiftUI

/// The design's square on/off switch.
struct RSSquareToggle: View {
    let isOn: Bool

    var body: some View {
        Rectangle()
            .fill(isOn ? Color.rsGreen : Color.clear)
            .overlay(Rectangle().strokeBorder(Color.rsInk, lineWidth: RSLayout.rule))
            .frame(width: 48, height: 26)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isOn ? Color.white : Color.rsInk)
                    .frame(width: 18, height: 18)
                    .padding(.leading, isOn ? 26 : 4)
            }
            .animation(.easeOut(duration: 0.15), value: isOn)
    }
}

/// A full-width settings row with a title, a caption and a square toggle.
struct RSToggleRow: View {
    let title: LocalizedStringKey
    let caption: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            VStack(spacing: 0) {
                RSRule()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).rs(17, .bold)
                        Text(caption).rs(13).foregroundStyle(Color.rsMuted)
                    }
                    Spacer()
                    RSSquareToggle(isOn: isOn)
                }
                .padding(.vertical, 14)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
        .accessibilityAddTraits(.isButton)
    }
}
