//
//  SettingsView.swift
//  RoadSense
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings").rs(40, .heavy, tracking: -1.8, scales: false)
                    .accessibilityAddTraits(.isHeader)

                RSSectionHeader(title: "Vehicle")
                RSRule()
                HStack(alignment: .firstTextBaseline) {
                    Text(viewModel.vehicleName).rs(17, .bold)
                    Spacer()
                    Text("Change").rs(13, .medium).foregroundStyle(Color.rsMuted)
                }
                .padding(.vertical, 14)
                RSRule()
                Text("Mount height").rs(17, .bold).padding(.top, 14).padding(.bottom, 10)
                RSSegmentedControl(
                    options: MountHeight.allCases, title: { $0.title }, selection: $viewModel.mountHeight,
                    minHeight: 40, fontSize: 14, horizontalPadding: 12
                )

                RSSectionHeader(title: "Inspection")
                RSToggleRow(title: "Auto-start", caption: "Begin when the car moves", isOn: $viewModel.autoStart)
                RSToggleRow(title: "Alert sounds", caption: "Soft tone on detection", isOn: $viewModel.alertSounds)
                RSToggleRow(title: "Upload on Wi-Fi only", caption: "Save mobile data", isOn: $viewModel.wifiOnlyUpload)

                RSSectionHeader(title: "App")
                RSRule()
                RSValueRow(title: "Units", value: String(localized: "Kilometres"))
                RSRule()
                RSValueRow(title: "Version", value: viewModel.appVersion)
                RSRule()
            }
            .foregroundStyle(Color.rsInk)
            .padding(.horizontal, RSLayout.screenInset)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(environment: .mock()))
}
