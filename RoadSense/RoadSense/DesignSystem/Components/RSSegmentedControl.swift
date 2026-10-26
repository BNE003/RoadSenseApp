//
//  RSSegmentedControl.swift
//  RoadSense
//

import SwiftUI

/// Equal-width, square options inside a 2 pt ink border. The selected option is filled with ink.
struct RSSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> LocalizedStringResource
    @Binding var selection: Option
    var minHeight: CGFloat = 36
    var fontSize: CGFloat = 13
    var horizontalPadding: CGFloat = 10

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    Text(title(option))
                        .rs(fontSize, .semibold)
                        .foregroundStyle(isSelected ? Color.white : Color.rsInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, horizontalPadding)
                        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
                        .background { isSelected ? Color.rsInk : Color.clear }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .overlay(Rectangle().strokeBorder(Color.rsInk, lineWidth: RSLayout.rule))
    }
}
