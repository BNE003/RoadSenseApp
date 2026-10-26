//
//  LiveView.swift
//  RoadSense
//

import SwiftUI

struct LiveView: View {
    @Environment(AppModel.self) private var model
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / 370
            let sy = geo.size.height / 824
            ZStack(alignment: .topLeading) {
                feed(in: geo.size)

                ForEach(model.activeDetections, id: \.at) { b in
                    DetectionBox(label: b.label)
                        .frame(width: b.w * sx, height: b.h * sy)
                        .offset(x: b.x * sx, y: b.y * sy)
                }

                topBar
                    .frame(maxHeight: .infinity, alignment: .top)
                bottomPanel
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background(Color.rsLiveGround)
        .ignoresSafeArea()
        .onAppear { pulse = true }
    }

    private func feed(in size: CGSize) -> some View {
        let horizon = size.height * 0.38
        return ZStack(alignment: .topLeading) {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x26302B), location: 0),
                    .init(color: Color(hex: 0x566159), location: 0.38),
                    .init(color: Color(hex: 0x18201C), location: 0.38),
                    .init(color: Color(hex: 0x26302B), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            // Lane centre dashes
            Path { p in
                var y = horizon
                while y < size.height {
                    p.addRect(CGRect(x: size.width / 2 - 1, y: y, width: 2, height: 26))
                    y += 60
                }
            }
            .fill(Color(white: 0.87))
            Rectangle().fill(.white.opacity(0.06))
                .frame(width: size.width * 0.6, height: size.height - horizon)
                .offset(x: size.width * 0.2, y: horizon)
            Text("Camera feed")
                .rs(11, .medium, tracking: 1.54)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.28))
                .frame(width: size.width, height: size.height)
        }
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
                Text(model.clock).rs(34, .heavy, tracking: -1.02).monospacedDigit()
                Text("\(model.distance) km").rs(13, .medium).opacity(0.7)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.top, 62)
    }

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                counter(model.potholes, "Potholes")
                RSVRule()
                counter(model.cracks, "Cracks").padding(.leading, 14)
                RSVRule()
                counter(model.signs, "Signs").padding(.leading, 14)
            }
            .fixedSize(horizontal: false, vertical: true)
            RSRule()

            Button { model.go(.summary) } label: {
                HStack {
                    Text("End inspection").rs(19, .bold)
                    Spacer()
                    Rectangle().fill(Color.rsGreen).frame(width: 16, height: 16)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 64)
                .background(Color.rsInk)
            }
            .buttonStyle(RSBlockButtonStyle())
            .padding(.top, 16)
        }
        .foregroundStyle(Color.rsInk)
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
        .background(Color.rsPaper)
    }

    private func counter(_ n: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(n)").rs(38, .heavy, tracking: -1.52)
            Text(label).rs(12, .medium).foregroundStyle(Color.rsMuted)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetectionBox: View {
    let label: String
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
                    .background(Color.rsMint)
                    .fixedSize()
                    .offset(x: -1, y: -23)
            }
    }
}
