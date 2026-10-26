//
//  ContentView.swift
//  RoadSense
//
//  Created by Benedikt Held on 26.10.26.
//

import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        ZStack {
            Color.rsPaper.ignoresSafeArea()
            switch model.screen {
            case .home: HomeView()
            case .live: LiveView()
            case .summary: SummaryView()
            case .map: MapScreenView()
            case .history: HistoryView()
            case .settings: SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.screen.hasTabBar { RSTabBar() }
        }
        .environment(model)
        .preferredColorScheme(.light)
    }
}

private struct RSTabBar: View {
    @Environment(AppModel.self) private var model

    private let tabs: [(Screen, String, String)] = [
        (.home, "Home", "house"),
        (.map, "Map", "map"),
        (.history, "History", "clock.arrow.circlepath"),
        (.settings, "Settings", "line.3.horizontal"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { screen, label, icon in
                let on = model.screen == screen
                Button { model.go(screen) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Image(systemName: icon).font(.system(size: 19, weight: .semibold)).frame(height: 22)
                        Text(label).rs(11, .bold, tracking: 0.22)
                    }
                    .foregroundStyle(on ? Color.rsGreen : Color.rsInk)
                    .padding(.leading, 20)
                    .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.rsPaper.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { RSRule() }
    }
}

#Preview {
    ContentView()
}
