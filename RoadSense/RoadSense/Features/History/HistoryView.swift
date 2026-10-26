//
//  HistoryView.swift
//  RoadSense
//

import SwiftUI

struct HistoryView: View {
    @State private var viewModel: HistoryViewModel
    let onSelectDrive: (Drive.ID) -> Void

    init(viewModel: HistoryViewModel, onSelectDrive: @escaping (Drive.ID) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectDrive = onSelectDrive
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("History").rs(40, .heavy, tracking: -1.8, scales: false)
                    .accessibilityAddTraits(.isHeader)
                Text(viewModel.subtitle).rs(14).foregroundStyle(Color.rsMuted).padding(.top, 8)

                if let error = viewModel.loadError {
                    RSStateMessage(text: error) { Task { await viewModel.load() } }.padding(.top, 26)
                } else if viewModel.isEmpty {
                    RSStateMessage(text: String(localized: "No drives yet. Finish an inspection and save it to see it here."))
                        .padding(.top, 26)
                }

                ForEach(viewModel.sections) { section in
                    Text(section.title).rsEyebrow().padding(.top, 26).padding(.bottom, 10)
                    ForEach(section.drives) { drive in
                        Button { onSelectDrive(drive.id) } label: {
                            RSListRow(
                                title: drive.name, meta: viewModel.meta(for: drive), count: drive.totalIssues,
                                titleSize: 18, countSize: 30, countColor: drive.totalIssues > 10 ? .rsGreen : .rsInk,
                                verticalPadding: 14
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .foregroundStyle(Color.rsInk)
            .padding(.horizontal, RSLayout.screenInset)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .task { await viewModel.load() }
    }
}

#Preview {
    HistoryView(viewModel: HistoryViewModel(environment: .mock()), onSelectDrive: { _ in })
}
