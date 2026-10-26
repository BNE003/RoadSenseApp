//
//  MapViewModel.swift
//  RoadSense
//

import Foundation
import Observation

@MainActor @Observable
final class MapViewModel {
    enum Filter: Hashable {
        case all
        case kind(IssueKind)

        var title: LocalizedStringResource {
            switch self {
            case .all: "All"
            case .kind(let kind): kind.pluralTitle
            }
        }
    }

    struct Pin: Identifiable {
        let issue: DetectedIssue
        let coordinate: Coordinate
        var id: DetectedIssue.ID { issue.id }
    }

    private let drives: any DriveRepository
    private let now: @Sendable () -> Date
    private let kinds: [IssueKind]

    private var issues: [DetectedIssue] = []
    private(set) var isLoaded = false
    private(set) var loadError: String?
    private(set) var filter: Filter = .all
    private(set) var selectedID: DetectedIssue.ID?

    init(environment: AppEnvironment) {
        drives = environment.drives
        now = environment.now
        kinds = IssueKind.allCases.filter { environment.detection.supportedKinds.contains($0) }
    }

    var filters: [Filter] { [.all] + kinds.map(Filter.kind) }

    /// Issues matching the filter that have a position. Issues recorded without a GPS fix are
    /// kept in the history but cannot be placed on the map.
    var pins: [Pin] {
        issues.compactMap { issue in
            guard matches(issue), let coordinate = issue.coordinate else { return nil }
            return Pin(issue: issue, coordinate: coordinate)
        }
    }

    /// Where the map should look to show every pin; `nil` when there is none.
    var region: MapRegionFit? { MapRegionFit.fitting(pins.map(\.coordinate)) }

    var selected: DetectedIssue? { pins.first { $0.id == selectedID }?.issue }

    var countText: String {
        let count = pins.count
        return count == 1 ? String(localized: "1 issue") : String(localized: "\(count) issues")
    }

    func placeText(for issue: DetectedIssue) -> String {
        issue.place ?? issue.coordinate.map(DriveFormatting.coordinate) ?? String(localized: "Unknown location")
    }

    func whenText(for issue: DetectedIssue) -> String {
        DriveFormatting.day(issue.detectedAt, now: now())
    }

    func load(focus: MapFocus) async {
        do {
            issues = try await drives.issues(focus: focus)
            loadError = nil
        } catch {
            issues = []
            loadError = error.localizedDescription
        }
        isLoaded = true
        selectedID = pins.first?.id
    }

    func setFilter(_ newFilter: Filter) {
        filter = newFilter
        selectedID = pins.first?.id
    }

    func select(_ id: DetectedIssue.ID) {
        selectedID = id
    }

    private func matches(_ issue: DetectedIssue) -> Bool {
        switch filter {
        case .all: true
        case .kind(let kind): issue.kind == kind
        }
    }
}
