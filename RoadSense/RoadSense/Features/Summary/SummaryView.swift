//
//  SummaryView.swift
//  RoadSense
//

import SwiftUI

struct SummaryView: View {
    @State private var viewModel: SummaryViewModel
    let onClose: () -> Void
    let onShowMap: (Drive.ID) -> Void
    let onShowHistory: () -> Void

    init(
        viewModel: SummaryViewModel,
        onClose: @escaping () -> Void,
        onShowMap: @escaping (Drive.ID) -> Void,
        onShowHistory: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
        self.onShowMap = onShowMap
        self.onShowHistory = onShowHistory
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: done) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left").font(.system(size: 15, weight: .semibold))
                            Text("Done").rs(14, .semibold)
                        }
                        .frame(minHeight: 44)
                    }
                    Spacer()
                    Text(viewModel.dateText).rs(13, .medium).foregroundStyle(Color.rsMuted)
                }

                Text("Drive complete").rsEyebrow().padding(.top, 36)

                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(viewModel.totalIssues.formatted())
                        .rs(128, .heavy, tracking: -9, scales: false)
                        .foregroundStyle(Color.rsGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text("road issues\nfound").rs(22, .bold, tracking: -0.44)
                        .padding(.bottom, 4)
                }
                .padding(.top, 6)
                .accessibilityElement(children: .combine)

                VStack(spacing: 0) {
                    RSRule()
                    HStack(spacing: 0) {
                        RSStatTile(value: viewModel.distanceText, caption: "Distance", style: .measure(unit: "km"))
                        RSVRule()
                        RSStatTile(value: viewModel.minutesText, caption: "Duration", style: .measure(unit: "min"))
                            .padding(.leading, 16)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    RSRule()
                }
                .padding(.top, 32)

                ForEach(viewModel.breakdown) { row in
                    VStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.kind.breakdownTitle).rs(17, .bold)
                            Spacer()
                            Text(row.count.formatted()).rs(22, .heavy, tracking: -0.44)
                        }
                        RSBarMeter(fraction: row.fraction)
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                        RSRule()
                    }
                    .padding(.top, 16)
                    .accessibilityElement(children: .combine)
                }

                HStack(spacing: 0) {
                    RSBlockButton("View on map") {
                        Task { if await viewModel.save() { onShowMap(viewModel.drive.id) } }
                    }
                    RSBlockButton("Save", outlined: true) {
                        Task { if await viewModel.save() { onShowHistory() } }
                    }
                }
                .padding(.top, 22)
                .disabled(viewModel.saveState == .saving)

                if let error = viewModel.errorText {
                    Text(error).rs(13).foregroundStyle(Color.rsMuted).padding(.top, 10)
                }
            }
            .foregroundStyle(Color.rsInk)
            .padding(.horizontal, RSLayout.screenInset)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .confirmationDialog("Discard this drive?", isPresented: $viewModel.isConfirmingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: onClose)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("It has not been saved.")
        }
    }

    private func done() {
        if viewModel.isSaved { onClose() } else { viewModel.isConfirmingDiscard = true }
    }
}

#Preview {
    SummaryView(
        viewModel: SummaryViewModel(drive: .sample(), environment: .mock()),
        onClose: {}, onShowMap: { _ in }, onShowHistory: {}
    )
}
