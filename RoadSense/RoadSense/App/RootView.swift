//
//  RootView.swift
//  RoadSense
//

import SwiftUI

/// The four tabs with the custom tab bar, and the full-screen inspection flow on top.
struct RootView: View {
    let environment: AppEnvironment
    @State private var router: AppRouter
    @State private var isReady = false

    init(environment: AppEnvironment, launch: LaunchOptions = LaunchOptions()) {
        self.environment = environment
        let router = AppRouter()
        switch launch.screen {
        case .home, nil: break
        case .map: router.selectedTab = .map
        case .history: router.selectedTab = .history
        case .settings: router.selectedTab = .settings
        case .live: router.startInspection()
        case .summary:
            router.previewDrive = .sample(now: environment.now())
            router.isInspectionPresented = true
        }
        _router = State(initialValue: router)
    }

    var body: some View {
        ZStack {
            Color.rsPaper.ignoresSafeArea()
            if isReady { content }
        }
        // Recovery runs before any screen loads, so a recovered drive is in the first History load.
        .task {
            await environment.recoverUnfinishedDrives()
            isReady = true
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RSTabBar(items: tabItems, selection: $router.selectedTab)
        }
        .fullScreenCover(isPresented: $router.isInspectionPresented) {
            InspectionFlowView(
                environment: environment,
                finishedDrive: router.previewDrive,
                onClose: router.finishInspection,
                onShowMap: { router.showMap(focus: .drive($0)) },
                onShowHistory: router.showHistory
            )
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch router.selectedTab {
            case .home:
                HomeView(
                    viewModel: HomeViewModel(environment: environment),
                    isInspectionPresented: router.isInspectionPresented,
                    onStartInspection: router.startInspection,
                    onShowHistory: router.showHistory
                )
            case .map:
                MapView(viewModel: MapViewModel(environment: environment), focus: router.mapFocus)
            case .history:
                HistoryView(
                    viewModel: HistoryViewModel(environment: environment),
                    onSelectDrive: { router.showMap(focus: .drive($0)) }
                )
            case .settings:
                SettingsView(viewModel: SettingsViewModel(environment: environment))
            }
        }
    }

    private var tabItems: [RSTabItem<AppTab>] {
        [
            RSTabItem(tab: .home, title: "Home", systemImage: "house"),
            RSTabItem(tab: .map, title: "Map", systemImage: "map"),
            RSTabItem(tab: .history, title: "History", systemImage: "clock.arrow.circlepath"),
            RSTabItem(tab: .settings, title: "Settings", systemImage: "line.3.horizontal"),
        ]
    }
}

#Preview {
    RootView(environment: .mock())
}
