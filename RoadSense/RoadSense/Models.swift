//
//  Models.swift
//  RoadSense
//

import SwiftUI

enum IssueKind: String, CaseIterable {
    case pothole = "Pothole"
    case crack = "Crack"
    case sign = "Sign"

    var filterTitle: String { rawValue + "s" }
}

struct MapIssue: Identifiable {
    let id: Int
    let kind: IssueKind
    /// Position in the 370 × 824 design canvas.
    let x: CGFloat
    let y: CGFloat
    let street: String
    let note: String
    let when: String

    static let all: [MapIssue] = [
        .init(id: 0, kind: .pothole, x: 110, y: 250, street: "Rosenstrasse 14", note: "Deep, 40 cm wide. Lane 1.", when: "Today"),
        .init(id: 1, kind: .crack, x: 230, y: 330, street: "Mühlenweg", note: "Longitudinal crack, 12 m.", when: "Today"),
        .init(id: 2, kind: .sign, x: 160, y: 440, street: "Hauptstrasse 3", note: "Speed limit sign bent.", when: "Yesterday"),
        .init(id: 3, kind: .pothole, x: 290, y: 520, street: "Bahnhofplatz", note: "Two potholes, cluster.", when: "Yesterday"),
        .init(id: 4, kind: .crack, x: 80, y: 560, street: "Am Kanal", note: "Edge cracking.", when: "22 Oct"),
        .init(id: 5, kind: .crack, x: 200, y: 200, street: "Lindenallee", note: "Network of fine cracks.", when: "22 Oct"),
        .init(id: 6, kind: .pothole, x: 300, y: 640, street: "Gartenstrasse 40", note: "Shallow, 25 cm.", when: "20 Oct"),
    ]
}

struct DriveRecord: Identifiable {
    let id = UUID()
    let section: String?
    let name: String
    let meta: String
    let issues: Int

    static let all: [DriveRecord] = [
        .init(section: "This week", name: "Commute, Nord–Süd", meta: "Today · 24.6 km · 38 min", issues: 11),
        .init(section: nil, name: "Airport run", meta: "Yesterday · 41.2 km · 52 min", issues: 6),
        .init(section: nil, name: "Old town loop", meta: "22 Oct · 8.9 km · 21 min", issues: 14),
        .init(section: "Earlier", name: "Ring road", meta: "18 Oct · 33.0 km · 40 min", issues: 3),
        .init(section: nil, name: "Harbour district", meta: "15 Oct · 12.4 km · 29 min", issues: 9),
    ]
}

/// A detection box that appears on the simulated camera feed.
struct LiveDetection {
    let at: Int
    let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
    let label: String

    static let all: [LiveDetection] = [
        .init(at: 2, x: 150, y: 400, w: 96, h: 52, label: "Pothole"),
        .init(at: 5, x: 40, y: 330, w: 70, h: 90, label: "Sign"),
        .init(at: 8, x: 240, y: 470, w: 110, h: 40, label: "Crack"),
    ]
}

enum Screen: String, CaseIterable, Identifiable {
    case home, live, summary, map, history, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .live: "Live inspection"
        case .summary: "Drive summary"
        case .map: "Map"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var hasTabBar: Bool {
        switch self {
        case .home, .map, .history, .settings: true
        case .live, .summary: false
        }
    }
}

@Observable
final class AppModel {
    var screen: Screen = .home
    var tick = 0
    var mapFilter = "All"
    var selectedIssue = 0
    var mountHeight = 1
    var toggles = [true, true, false]

    private var timer: Timer?

    func go(_ s: Screen) {
        if s == .live { tick = 0; startTimer() } else { stopTimer() }
        screen = s
    }

    func setFilter(_ f: String) {
        mapFilter = f
        if let first = MapIssue.all.first(where: { f == "All" || $0.kind.filterTitle == f }) {
            selectedIssue = first.id
        }
    }

    var visibleIssues: [MapIssue] {
        MapIssue.all.filter { mapFilter == "All" || $0.kind.filterTitle == mapFilter }
    }

    var activeDetections: [LiveDetection] {
        LiveDetection.all.filter { tick >= $0.at && tick < $0.at + 4 }
    }

    var clock: String { String(format: "%02d:%02d", tick / 60, tick % 60) }
    var distance: String { String(format: "%.1f", Double(tick) * 0.011 + 0.4) }
    var potholes: Int { LiveDetection.all[0].at < tick ? 1 + tick / 9 : 0 }
    var cracks: Int { tick / 3 }
    var signs: Int { tick > 5 ? 1 : 0 }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
