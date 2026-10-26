//
//  InspectionFlowView.swift
//  RoadSense
//

import SwiftUI

/// Full-screen flow: live inspection, then the drive summary.
struct InspectionFlowView: View {
    private let environment: AppEnvironment
    @State private var viewModel: InspectionViewModel
    let onClose: () -> Void
    let onShowMap: (Drive.ID) -> Void
    let onShowHistory: () -> Void

    init(
        environment: AppEnvironment,
        finishedDrive: Drive?,
        onClose: @escaping () -> Void,
        onShowMap: @escaping (Drive.ID) -> Void,
        onShowHistory: @escaping () -> Void
    ) {
        self.environment = environment
        _viewModel = State(initialValue: InspectionViewModel(environment: environment, finishedDrive: finishedDrive))
        self.onClose = onClose
        self.onShowMap = onShowMap
        self.onShowHistory = onShowHistory
    }

    var body: some View {
        ZStack {
            Color.rsPaper.ignoresSafeArea()
            switch viewModel.phase {
            case .recording:
                LiveView(viewModel: viewModel)
            case .failed(let message):
                InspectionFailureView(message: message, onClose: onClose)
            case .finished(let drive):
                SummaryView(
                    viewModel: SummaryViewModel(drive: drive, environment: environment),
                    onClose: onClose, onShowMap: onShowMap, onShowHistory: onShowHistory
                )
            }
        }
        .preferredColorScheme(.light)
    }
}

/// Shown when an inspection cannot start, for example without camera permission.
private struct InspectionFailureView: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Can't start").rs(40, .heavy, tracking: -1.8, scales: false)
            Text(message).rs(15).foregroundStyle(Color.rsBody).padding(.top, 14)
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: settingsURL) {
                    Text("Open Settings").rs(16, .bold).padding(.top, 20).foregroundStyle(Color.rsGreen)
                }
            }
            Spacer()
            RSBlockButton("Back", fill: .rsInk, minHeight: 64, fontSize: 19, action: onClose)
        }
        .padding(.horizontal, RSLayout.screenInset)
        .padding(.bottom, 24)
        .foregroundStyle(Color.rsInk)
    }
}

#Preview("Failure") {
    InspectionFailureView(message: CameraError.accessDenied.localizedDescription, onClose: {})
}
