//
//  HomeView.swift
//  RoadSense
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    let isInspectionPresented: Bool
    let onStartInspection: () -> Void
    let onShowHistory: () -> Void

    init(
        viewModel: HomeViewModel,
        isInspectionPresented: Bool = false,
        onStartInspection: @escaping () -> Void,
        onShowHistory: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.isInspectionPresented = isInspectionPresented
        self.onStartInspection = onStartInspection
        self.onShowHistory = onShowHistory
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    RSWordmark()
                    Spacer()
                    Text(viewModel.dateText).rs(13, .medium).foregroundStyle(Color.rsMuted)
                }

                Text("Ready\nto drive.")
                    .rs(54, .heavy, tracking: -2.4, scales: false)
                    .lineSpacing(-10)
                    .padding(.top, 44)

                Text("Mount your phone on the windshield. RoadSense does the rest.")
                    .rs(15)
                    .foregroundStyle(Color.rsBody)
                    .frame(maxWidth: 270, alignment: .leading)
                    .padding(.top, 14)

                statusRow.padding(.top, 28)

                RSBlockButton(
                    title: "Start inspection", minHeight: 84, fontSize: 22, tracking: -0.44,
                    action: onStartInspection
                ) {
                    Image(systemName: "arrow.right").font(.system(size: 24, weight: .semibold))
                }

                HStack {
                    Text("Recent")
                    Spacer()
                    Button("All", action: onShowHistory).foregroundStyle(Color.rsInk)
                }
                .rsEyebrow()
                .padding(.top, 30)

                recentList
            }
            .padding(.horizontal, RSLayout.screenInset)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .foregroundStyle(Color.rsInk)
        }
        .task { await viewModel.load() }
        .task { await viewModel.observeGPS() }
        // Watching stops while an inspection is open, which has its own location stream.
        .task(id: isInspectionPresented) {
            guard !isInspectionPresented else { return }
            await viewModel.watchForMovement(onMovement: onStartInspection)
        }
    }

    private var statusRow: some View {
        VStack(spacing: 0) {
            RSRule()
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(viewModel.gpsStatus == .locked ? Color.rsGreen : Color.rsMuted)
                        .frame(width: 8, height: 8)
                    Text(gpsText).rs(13, .medium)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                RSVRule().frame(height: 42)
                Text(viewModel.vehicleName).rs(13, .medium)
                    .padding(.leading, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gpsText: LocalizedStringKey {
        switch viewModel.gpsStatus {
        case .locked: "GPS locked"
        case .searching: "Searching for GPS"
        case .denied: "Location off"
        }
    }

    @ViewBuilder
    private var recentList: some View {
        if let error = viewModel.loadError {
            RSStateMessage(text: error) { Task { await viewModel.load() } }
                .padding(.top, 10)
        } else if viewModel.isLoaded && viewModel.recent.isEmpty {
            RSStateMessage(text: String(localized: "No drives yet. Your first inspection will show up here."))
                .padding(.top, 10)
        } else {
            ForEach(viewModel.recent) { drive in
                RSListRow(title: drive.name, meta: viewModel.meta(for: drive), count: drive.totalIssues)
                    .padding(.top, 10)
            }
        }
    }
}

#Preview {
    HomeView(
        viewModel: HomeViewModel(environment: .mock()),
        onStartInspection: {}, onShowHistory: {}
    )
}
