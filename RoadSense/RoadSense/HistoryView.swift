//
//  HistoryView.swift
//  RoadSense
//

import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("History").rs(40, .heavy, tracking: -1.8)
                Text("23 drives · 412 km inspected").rs(14).foregroundStyle(Color.rsMuted).padding(.top, 8)

                ForEach(DriveRecord.all) { h in
                    if let section = h.section {
                        Text(section).rsEyebrow().padding(.top, 26).padding(.bottom, 10)
                    }
                    Button { model.go(.map) } label: {
                        VStack(spacing: 0) {
                            RSRule()
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(h.name).rs(18, .bold, tracking: -0.27)
                                    Text(h.meta).rs(13).foregroundStyle(Color.rsMuted)
                                }
                                Spacer()
                                Text("\(h.issues)").rs(30, .heavy, tracking: -0.9)
                                    .foregroundStyle(h.issues > 10 ? Color.rsGreen : Color.rsInk)
                            }
                            .padding(.vertical, 14)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(Color.rsInk)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}
