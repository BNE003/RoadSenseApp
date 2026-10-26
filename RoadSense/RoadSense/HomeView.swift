//
//  HomeView.swift
//  RoadSense
//

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    private var dateText: String {
        Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    RSWordmark()
                    Spacer()
                    Text(dateText).rs(13, .medium).foregroundStyle(Color.rsMuted)
                }

                Text("Ready\nto drive.")
                    .rs(54, .heavy, tracking: -2.4)
                    .lineSpacing(-12)
                    .padding(.top, 44)

                Text("Mount your phone on the windshield. RoadSense does the rest.")
                    .rs(15)
                    .foregroundStyle(Color.rsBody)
                    .frame(maxWidth: 270, alignment: .leading)
                    .padding(.top, 14)

                VStack(spacing: 0) {
                    RSRule()
                    HStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Rectangle().fill(Color.rsGreen).frame(width: 8, height: 8)
                            Text("GPS locked").rs(13, .medium)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        RSVRule().frame(height: 42)
                        Text("Volvo XC40").rs(13, .medium)
                            .padding(.leading, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 28)

                Button { model.go(.live) } label: {
                    HStack {
                        Text("Start inspection").rs(22, .bold, tracking: -0.44)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 84)
                    .background(Color.rsGreen)
                }
                .buttonStyle(RSBlockButtonStyle())

                HStack {
                    Text("Recent")
                    Spacer()
                    Button("All") { model.go(.history) }
                        .foregroundStyle(Color.rsInk)
                }
                .rsEyebrow()
                .padding(.top, 30)

                ForEach(Array(DriveRecord.all.prefix(2))) { r in
                    VStack(spacing: 0) {
                        RSRule()
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).rs(17, .bold, tracking: -0.17)
                                Text(shortMeta(r.meta)).rs(13).foregroundStyle(Color.rsMuted)
                            }
                            Spacer()
                            Text("\(r.issues)").rs(28, .heavy, tracking: -0.84)
                        }
                        .padding(.vertical, 12)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .foregroundStyle(Color.rsInk)
        }
    }

    /// "Today · 24.6 km · 38 min" → "Today · 24.6 km"
    private func shortMeta(_ meta: String) -> String {
        meta.split(separator: "·").prefix(2).joined(separator: "·")
            .trimmingCharacters(in: .whitespaces)
    }
}
