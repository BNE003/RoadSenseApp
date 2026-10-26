//
//  Drive.swift
//  RoadSense
//

import Foundation

/// One finished inspection session with everything it detected.
nonisolated struct Drive: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var startedAt: Date
    var endedAt: Date
    var distanceMeters: Double
    var issues: [DetectedIssue]
    var status: DriveStatus = .finished
    /// Downsampled GPS breadcrumb, see `RouteBreadcrumb`.
    var route: [Coordinate] = []

    var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }

    var summary: DriveSummary {
        var counts: [IssueKind: Int] = [:]
        for issue in issues { counts[issue.kind, default: 0] += 1 }
        return DriveSummary(
            id: id, name: name, startedAt: startedAt,
            duration: duration, distanceMeters: distanceMeters, counts: counts
        )
    }
}

/// A drive without its located issues: what lists and the summary screen need.
nonisolated struct DriveSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var startedAt: Date
    var duration: TimeInterval
    var distanceMeters: Double
    var counts: [IssueKind: Int]

    var totalIssues: Int { counts.values.reduce(0, +) }

    func count(of kind: IssueKind) -> Int { counts[kind, default: 0] }

    /// Share of all issues that are of `kind`, 0...1.
    func fraction(of kind: IssueKind) -> Double {
        totalIssues == 0 ? 0 : Double(count(of: kind)) / Double(totalIssues)
    }
}

/// Aggregates shown above the history list.
nonisolated struct HistoryTotals: Hashable, Sendable {
    var driveCount: Int
    var distanceMeters: Double
}

nonisolated extension Drive {
    static func defaultName(for date: Date) -> String {
        let formatted = date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        return String(localized: "Drive \(formatted)")
    }
}
