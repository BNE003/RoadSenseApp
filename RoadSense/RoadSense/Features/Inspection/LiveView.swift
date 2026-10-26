//
//  LiveView.swift
//  RoadSense
//

import SwiftUI

/// The live inspection screen: camera feed, detection boxes, counters and "End inspection".
struct LiveView: View {
    let viewModel: InspectionViewModel
    @State private var pulse = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                CameraFeedPlaceholder()
                ForEach(Array(viewModel.snapshot.boxes.enumerated()), id: \.offset) { _, box in
                    DetectionBox(label: box.kind.singularTitle)
                        .frame(width: box.rect.width * geometry.size.width, height: box.rect.height * geometry.size.height)
                        .offset(x: box.rect.x * geometry.size.width, y: box.rect.y * geometry.size.height)
                }
                topBar.frame(maxHeight: .infinity, alignment: .top)
                bottomPanel.frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background(Color.rsLiveGround)
        .ignoresSafeArea()
        .onAppear { pulse = true }
        .task { viewModel.start() }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            HStack(spacing: 8) {
                Rectangle().fill(Color.rsMint).frame(width: 10, height: 10)
                    .opacity(pulse ? 0.35 : 1)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                Text("Recording").rs(13, .bold, tracking: 1.04).textCase(.uppercase)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(viewModel.clockText).rs(34, .heavy, tracking: -1.02, scales: false).monospacedDigit()
                Text("\(viewModel.distanceText) km").rs(13, .medium).opacity(0.7)
            }
            .accessibilityElement(children: .combine)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, RSLayout.screenInset)
        .padding(.top, 62)
    }

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.counterKinds.enumerated()), id: \.element) { index, kind in
                    if index > 0 { RSVRule() }
                    RSStatTile(value: viewModel.count(of: kind).formatted(), caption: kind.pluralTitle, style: .counter)
                        .padding(.leading, index > 0 ? 14 : 0)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            RSRule()
            RSBlockButton(
                title: "End inspection", fill: .rsInk, minHeight: 64, fontSize: 19,
                action: viewModel.end
            ) {
                Rectangle().fill(Color.rsGreen).frame(width: 16, height: 16)
            }
            .padding(.top, 16)
        }
        .foregroundStyle(Color.rsInk)
        .padding(.horizontal, RSLayout.screenInset)
        .padding(.bottom, 34)
        .background { Color.rsPaper }
    }
}

/// Stand-in for the camera preview until Milestone 2.
private struct CameraFeedPlaceholder: View {
    var body: some View {
        GeometryReader { geometry in
            let horizon = geometry.size.height * 0.38
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    stops: [
                        .init(color: .rsFeedSky, location: 0),
                        .init(color: .rsFeedHorizon, location: 0.38),
                        .init(color: .rsFeedRoadside, location: 0.38),
                        .init(color: .rsFeedSky, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                Path { path in
                    var y = horizon
                    while y < geometry.size.height {
                        path.addRect(CGRect(x: geometry.size.width / 2 - 1, y: y, width: 2, height: 26))
                        y += 60
                    }
                }
                .fill(Color(white: 0.87))
                Rectangle().fill(.white.opacity(0.06))
                    .frame(width: geometry.size.width * 0.6, height: geometry.size.height - horizon)
                    .offset(x: geometry.size.width * 0.2, y: horizon)
                Text("Camera feed")
                    .rs(11, .medium, tracking: 1.54)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.28))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct DetectionBox: View {
    let label: LocalizedStringResource

    var body: some View {
        Rectangle()
            .strokeBorder(Color.rsMint, lineWidth: 2)
            .overlay(alignment: .topLeading) {
                Text(label)
                    .rs(11, .bold, tracking: 0.44)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.rsInk)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background { Color.rsMint }
                    .fixedSize()
                    .offset(x: -1, y: -23)
            }
    }
}

#Preview {
    LiveView(viewModel: InspectionViewModel(environment: .mock()))
}
