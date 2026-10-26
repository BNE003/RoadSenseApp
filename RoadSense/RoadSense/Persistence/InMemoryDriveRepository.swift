//
//  InMemoryDriveRepository.swift
//  RoadSense
//

import Foundation

/// Keeps everything in memory. Milestone 1's repository; afterwards used for previews and tests.
actor InMemoryDriveRepository: DriveRepository {
    private var summaries: [DriveSummary]
    private var issues: [DetectedIssue]
    /// Drives that exist but are not listed individually (older history).
    private let archivedTotals: HistoryTotals
    private let failure: PersistenceError?

    init(
        summaries: [DriveSummary] = [],
        issues: [DetectedIssue] = [],
        archivedTotals: HistoryTotals = HistoryTotals(driveCount: 0, distanceMeters: 0),
        failure: PersistenceError? = nil
    ) {
        self.summaries = summaries
        self.issues = issues
        self.archivedTotals = archivedTotals
        self.failure = failure
    }

    func save(_ drive: Drive) throws {
        if let failure { throw failure }
        summaries.removeAll { $0.id == drive.id }
        summaries.append(drive.summary)
        issues.removeAll { $0.driveID == drive.id }
        issues.append(contentsOf: drive.issues)
    }

    func driveSummaries(limit: Int?) throws -> [DriveSummary] {
        if let failure { throw failure }
        let sorted = summaries.sorted { $0.startedAt > $1.startedAt }
        return limit.map { Array(sorted.prefix($0)) } ?? sorted
    }

    func totals() throws -> HistoryTotals {
        if let failure { throw failure }
        return HistoryTotals(
            driveCount: archivedTotals.driveCount + summaries.count,
            distanceMeters: archivedTotals.distanceMeters + summaries.reduce(0) { $0 + $1.distanceMeters }
        )
    }

    func issues(focus: MapFocus) throws -> [DetectedIssue] {
        if let failure { throw failure }
        switch focus {
        case .all: return issues
        case .drive(let id): return issues.filter { $0.driveID == id }
        }
    }
}
