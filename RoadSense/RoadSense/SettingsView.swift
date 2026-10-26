//
//  SettingsView.swift
//  RoadSense
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    private let heights = ["Low", "Standard", "High"]
    private let toggles: [(String, String)] = [
        ("Auto-start", "Begin when the car moves"),
        ("Alert sounds", "Soft tone on detection"),
        ("Upload on Wi-Fi only", "Save mobile data"),
    ]

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings").rs(40, .heavy, tracking: -1.8)

                Text("Vehicle").rsEyebrow().padding(.top, 34).padding(.bottom, 10)
                RSRule()
                HStack(alignment: .firstTextBaseline) {
                    Text("Volvo XC40").rs(17, .bold)
                    Spacer()
                    Text("Change").rs(13, .medium).foregroundStyle(Color.rsMuted)
                }
                .padding(.vertical, 14)
                RSRule()
                Text("Mount height").rs(17, .bold).padding(.top, 14).padding(.bottom, 10)
                HStack(spacing: 0) {
                    ForEach(heights.indices, id: \.self) { i in
                        let on = model.mountHeight == i
                        Button { model.mountHeight = i } label: {
                            Text(heights[i]).rs(14, .semibold)
                                .foregroundStyle(on ? Color.white : Color.rsInk)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                                .background(on ? Color.rsInk : .clear)
                        }
                    }
                }
                .overlay(Rectangle().strokeBorder(Color.rsInk, lineWidth: 2))

                Text("Inspection").rsEyebrow().padding(.top, 34).padding(.bottom, 10)
                ForEach(toggles.indices, id: \.self) { i in
                    Button { model.toggles[i].toggle() } label: {
                        VStack(spacing: 0) {
                            RSRule()
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(toggles[i].0).rs(17, .bold)
                                    Text(toggles[i].1).rs(13).foregroundStyle(Color.rsMuted)
                                }
                                Spacer()
                                SquareToggle(isOn: model.toggles[i])
                            }
                            .padding(.vertical, 14)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isToggle)
                }

                Text("App").rsEyebrow().padding(.top, 34).padding(.bottom, 10)
                RSRule()
                row("Units", "Kilometres")
                RSRule()
                row("Version", "1.0")
                RSRule()
            }
            .foregroundStyle(Color.rsInk)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).rs(17, .bold)
            Spacer()
            Text(value).rs(14, .medium).foregroundStyle(Color.rsMuted)
        }
        .padding(.vertical, 14)
    }
}

private struct SquareToggle: View {
    let isOn: Bool
    var body: some View {
        Rectangle()
            .fill(isOn ? Color.rsGreen : .clear)
            .overlay(Rectangle().strokeBorder(Color.rsInk, lineWidth: 2))
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
