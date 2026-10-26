//
//  RSBlockButton.swift
//  RoadSense
//

import SwiftUI

/// Square, full-width action button. `outlined` draws an ink border instead of a fill.
struct RSBlockButton<Trailing: View>: View {
    let title: LocalizedStringKey
    var fill: Color = .rsGreen
    var foreground: Color = .white
    var outlined = false
    var minHeight: CGFloat = 56
    var fontSize: CGFloat = 16
    var tracking: CGFloat = 0
    var action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).rs(fontSize, .bold, tracking: tracking)
                Spacer(minLength: 8)
                trailing()
            }
            .foregroundStyle(outlined ? Color.rsInk : foreground)
            .padding(.horizontal, minHeight >= 64 ? 20 : 16)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background { outlined ? Color.clear : fill }
            .overlay { if outlined { Rectangle().strokeBorder(Color.rsInk, lineWidth: RSLayout.rule) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(RSPressStyle())
    }
}

extension RSBlockButton where Trailing == EmptyView {
    init(
        _ title: LocalizedStringKey, fill: Color = .rsGreen, foreground: Color = .white,
        outlined: Bool = false, minHeight: CGFloat = 56, fontSize: CGFloat = 16, tracking: CGFloat = 0,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title, fill: fill, foreground: foreground, outlined: outlined,
            minHeight: minHeight, fontSize: fontSize, tracking: tracking, action: action,
            trailing: { EmptyView() }
        )
    }
}

/// Dims the label while pressed. No scale or rounding: the design is flat.
struct RSPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}
