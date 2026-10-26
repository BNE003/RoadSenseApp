//
//  AppRouter.swift
//  RoadSense
//

import Foundation
import Observation

enum AppTab: CaseIterable, Hashable {
    case home, map, history, settings
}

/// Which tab is selected, what the map shows, and whether the inspection flow is open.
@MainActor @Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var mapFocus: MapFocus = .all
    var isInspectionPresented = false
    /// Debug only: open the inspection flow directly on a finished drive.
    var previewDrive: Drive?

    func startInspection() {
        previewDrive = nil
        isInspectionPresented = true
    }

    func showMap(focus: MapFocus = .all) {
        mapFocus = focus
        selectedTab = .map
        isInspectionPresented = false
    }

    func showHistory() {
        selectedTab = .history
        isInspectionPresented = false
    }

    func finishInspection() {
        isInspectionPresented = false
    }
}
