//
//  MapScreenView.swift
//  RoadSense
//

import SwiftUI

struct MapScreenView: View {
    @Environment(AppModel.self) private var model
    private let filters = ["All", "Potholes", "Cracks", "Signs"]

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / 370
            let sy = geo.size.height / 824
            ZStack(alignment: .top) {
                StylizedMap()
                    .frame(width: geo.size.width, height: geo.size.height)

                ForEach(model.visibleIssues) { p in
                    let selected = model.selectedIssue == p.id
                    let size: CGFloat = selected ? 24 : 16
                    Button { model.selectedIssue = p.id } label: {
                        Rectangle()
                            .fill(selected || p.kind == .pothole ? Color.rsGreen : Color.rsPaper)
                            .overlay(Rectangle().strokeBorder(Color.rsInk, lineWidth: 2))
                            .frame(width: size, height: size)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: p.x * sx, y: p.y * sy)
                    .animation(.easeOut(duration: 0.15), value: selected)
                    .accessibilityLabel("\(p.kind.rawValue), \(p.street)")
                }

                header.frame(maxHeight: .infinity, alignment: .top)
                detailCard.frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .ignoresSafeArea(edges: .top)
        .foregroundStyle(Color.rsInk)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Map").rs(32, .heavy, tracking: -1.28)
                Spacer()
                Text("\(model.visibleIssues.count) issues").rs(13, .medium).foregroundStyle(Color.rsMuted)
            }
            HStack(spacing: 0) {
                ForEach(filters, id: \.self) { f in
                    let on = model.mapFilter == f
                    Button { model.setFilter(f) } label: {
                        Text(f).rs(13, .semibold)
                            .foregroundStyle(on ? Color.white : Color.rsInk)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .background(on ? Color.rsInk : .clear)
                    }
                }
            }
            .overlay(Rectangle().strokeBorder(Color.rsInk, lineWidth: 2))
            .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 14)
        .background(Color.rsPaper)
        .overlay(alignment: .bottom) { RSRule() }
    }

    @ViewBuilder
    private var detailCard: some View {
        let sel = MapIssue.all.first { $0.id == model.selectedIssue } ?? MapIssue.all[0]
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(sel.kind.rawValue).rs(11, .semibold, tracking: 0.88)
                    .textCase(.uppercase).foregroundStyle(Color.rsGreen)
                Spacer()
                Text(sel.when).rs(12, .medium).foregroundStyle(Color.rsMuted)
            }
            Text(sel.street).rs(24, .heavy, tracking: -0.72).padding(.top, 6)
            Text(sel.note).rs(13).foregroundStyle(Color.rsBody).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(Color.rsPaper)
        .overlay(alignment: .top) { RSRule() }
    }
}

/// Greyscale street grid matching the design's placeholder map.
private struct StylizedMap: View {
    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 370, sy = size.height / 824
            func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat), _ w: CGFloat) {
                var p = Path()
                p.move(to: CGPoint(x: a.0 * sx, y: a.1 * sy))
                p.addLine(to: CGPoint(x: b.0 * sx, y: b.1 * sy))
                ctx.stroke(p, with: .color(.white), lineWidth: w)
            }
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.rsMapGround))

            var park = Path()
            park.move(to: CGPoint(x: -10 * sx, y: 720 * sy))
            park.addCurve(to: CGPoint(x: 380 * sx, y: 690 * sy),
                          control1: CGPoint(x: 100 * sx, y: 650 * sy),
                          control2: CGPoint(x: 220 * sx, y: 760 * sy))
            ctx.stroke(park, with: .color(Color(hex: 0xB9CDB4)), lineWidth: 30)

            line((-10, 210), (380, 160), 14)
            line((-10, 420), (380, 470), 14)
            line((90, -10), (130, 830), 14)
            line((280, -10), (240, 830), 14)
            line((-10, 320), (380, 330), 6)
            line((-10, 600), (380, 580), 6)
            line((190, -10), (180, 830), 6)
            line((20, -10), (50, 830), 6)
            line((340, -10), (320, 830), 6)
        }
    }
}
