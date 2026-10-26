//
//  MapView.swift
//  RoadSense
//

import SwiftUI

struct MapView: View {
    @State private var viewModel: MapViewModel
    let focus: MapFocus

    init(viewModel: MapViewModel, focus: MapFocus) {
        _viewModel = State(initialValue: viewModel)
        self.focus = focus
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                StylizedMap()
                ForEach(viewModel.pins) { pin in
                    PinButton(
                        isSelected: viewModel.selectedID == pin.id,
                        isPothole: pin.issue.kind == .pothole,
                        label: Text(pin.issue.kind.singularTitle)
                    ) { viewModel.select(pin.id) }
                    .position(x: pin.x * geometry.size.width, y: pin.y * geometry.size.height)
                }
                header.frame(maxHeight: .infinity, alignment: .top)
                if let issue = viewModel.selected {
                    detailCard(for: issue).frame(maxHeight: .infinity, alignment: .bottom)
                } else if viewModel.isLoaded {
                    emptyCard.frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .foregroundStyle(Color.rsInk)
        .task(id: focus) { await viewModel.load(focus: focus) }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Map").rs(32, .heavy, tracking: -1.28)
                Spacer()
                Text(viewModel.countText).rs(13, .medium).foregroundStyle(Color.rsMuted)
            }
            RSSegmentedControl(
                options: viewModel.filters, title: { $0.title },
                selection: Binding(get: { viewModel.filter }, set: { viewModel.setFilter($0) })
            )
            .padding(.top, 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 14)
        .background { Color.rsPaper }
        .overlay(alignment: .bottom) { RSRule() }
    }

    private func detailCard(for issue: DetectedIssue) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(issue.kind.singularTitle).rs(11, .semibold, tracking: 0.88)
                    .textCase(.uppercase).foregroundStyle(Color.rsGreen)
                Spacer()
                Text(viewModel.whenText(for: issue)).rs(12, .medium).foregroundStyle(Color.rsMuted)
            }
            Text(viewModel.placeText(for: issue)).rs(24, .heavy, tracking: -0.72).padding(.top, 6)
            if let note = issue.note {
                Text(note).rs(13).foregroundStyle(Color.rsBody).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background { Color.rsPaper }
        .overlay(alignment: .top) { RSRule() }
        .accessibilityElement(children: .combine)
    }

    private var emptyCard: some View {
        Text(viewModel.loadError ?? String(localized: "No issues to show."))
            .rs(14)
            .foregroundStyle(Color.rsMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background { Color.rsPaper }
            .overlay(alignment: .top) { RSRule() }
    }
}

private struct PinButton: View {
    let isSelected: Bool
    let isPothole: Bool
    let label: Text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Rectangle()
                .fill(isSelected || isPothole ? Color.rsGreen : Color.rsPaper)
                .overlay(Rectangle().strokeBorder(Color.rsInk, lineWidth: RSLayout.rule))
                .frame(width: isSelected ? 24 : 16, height: isSelected ? 24 : 16)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The design's greyscale street grid.
private struct StylizedMap: View {
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 370, sy = size.height / 824
            func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat), _ width: CGFloat) {
                var path = Path()
                path.move(to: CGPoint(x: a.0 * sx, y: a.1 * sy))
                path.addLine(to: CGPoint(x: b.0 * sx, y: b.1 * sy))
                context.stroke(path, with: .color(.white), lineWidth: width)
            }
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.rsMapGround))

            var park = Path()
            park.move(to: CGPoint(x: -10 * sx, y: 720 * sy))
            park.addCurve(
                to: CGPoint(x: 380 * sx, y: 690 * sy),
                control1: CGPoint(x: 100 * sx, y: 650 * sy),
                control2: CGPoint(x: 220 * sx, y: 760 * sy)
            )
            context.stroke(park, with: .color(.rsMapPark), lineWidth: 30)

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
        .accessibilityHidden(true)
    }
}

#Preview {
    MapView(viewModel: MapViewModel(environment: .mock()), focus: .all)
}
