//
//  RSTabBar.swift
//  RoadSense
//

import SwiftUI

struct RSTabItem<Tab: Hashable>: Identifiable {
    let tab: Tab
    let title: LocalizedStringKey
    let systemImage: String

    var id: Tab { tab }
}

/// The design's square bottom bar: 2 pt rule on top, left-aligned icon and label per tab.
struct RSTabBar<Tab: Hashable>: View {
    let items: [RSTabItem<Tab>]
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item.tab == selection
                Button { selection = item.tab } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(height: 22)
                        Text(item.title).rs(11, .bold, tracking: 0.22)
                    }
                    .foregroundStyle(isSelected ? Color.rsGreen : Color.rsInk)
                    .padding(.leading, 20)
                    .frame(maxWidth: .infinity, minHeight: RSLayout.tabBarHeight, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .background { Color.rsPaper.ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) { RSRule() }
    }
}
