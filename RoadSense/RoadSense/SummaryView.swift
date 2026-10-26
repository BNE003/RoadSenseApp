//
//  SummaryView.swift
//  RoadSense
//

import SwiftUI

struct SummaryView: View {
    @Environment(AppModel.self) private var model

    private let breakdown: [(label: String, n: Int, pct: Double)] = [
        ("Potholes", 3, 27), ("Road cracks", 7, 64), ("Damaged signs", 1, 9),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { model.go(.home) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left").font(.system(size: 15, weight: .semibold))
                            Text("Done").rs(14, .semibold)
                        }
                    }
                    Spacer()
                    Text("Today, 09:41").rs(13, .medium).foregroundStyle(Color.rsMuted)
                }

                Text("Drive complete").rsEyebrow().padding(.top, 36)

                HStack(alignment: .bottom, spacing: 12) {
                    Text("11")
                        .rs(128, .heavy, tracking: -9)
                        .foregroundStyle(Color.rsGreen)
                    Text("road issues\nfound").rs(22, .bold, tracking: -0.44)
                        .padding(.bottom, 4)
                }
                .padding(.top, 6)

                VStack(spacing: 0) {
                    RSRule()
                    HStack(spacing: 0) {
                        stat("24.6", "km", "Distance")
                        RSVRule()
                        stat("38", "min", "Duration").padding(.leading, 16)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    RSRule()
                }
                .padding(.top, 32)

                ForEach(breakdown, id: \.label) { b in
                    VStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(b.label).rs(17, .bold)
                            Spacer()
                            Text("\(b.n)").rs(22, .heavy, tracking: -0.44)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.rsTrack)
                                Rectangle().fill(Color.rsInk).frame(width: g.size.width * b.pct / 100)
                            }
                        }
                        .frame(height: 6)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                        RSRule()
                    }
                    .padding(.top, 16)
                }

                HStack(spacing: 0) {
                    Button { model.go(.map) } label: {
                        Text("View on map").rs(16, .bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .background(Color.rsGreen)
                    }
                    Button { model.go(.history) } label: {
                        Text("Save").rs(16, .bold)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .overlay(Rectangle().strokeBorder(Color.rsInk, lineWidth: 2))
                    }
                }
                .buttonStyle(RSBlockButtonStyle())
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
            .foregroundStyle(Color.rsInk)
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }

    private func stat(_ value: String, _ unit: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value).rs(30, .heavy, tracking: -0.9)
                Text(" \(unit)").rs(14, .semibold)
            }
            Text(label).rs(12, .medium).foregroundStyle(Color.rsMuted)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
