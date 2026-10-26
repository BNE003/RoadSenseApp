//
//  InMemoryDriveRepository.swift
//  RoadSense
//

import Foundation

/// Keeps everything in memory. Used for previews, tests and `-RS_USE_MOCKS` runs.
actor InMemoryDriveRepository: DriveRepository {
    private var summaries: [DriveSummary]
    private var issues: [DetectedIssue]
    private var inProgress: [Drive.ID: Drive] = [:]
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
        removeFinished(drive.id)
        switch drive.status {
        case .inProgress:
            inProgress[drive.id] = drive
        case .finished:
            inProgress[drive.id] = nil
            summaries.append(drive.summary)
            issues.append(contentsOf: drive.issues)
        }
    }

    func append(_ issue: DetectedIssue) throws {
        if let failure { throw failure }
        guard inProgress[issue.driveID] != nil else { throw PersistenceError.saveFailed }
        inProgress[issue.driveID]?.issues.append(issue)
    }

    func checkpoint(driveID: Drive.ID, endedAt: Date, distanceMeters: Double, route: [Coordinate]) throws {
        if let failure { throw failure }
        guard inProgress[driveID] != nil else { throw PersistenceError.saveFailed }
        inProgress[driveID]?.endedAt = endedAt
        inProgress[driveID]?.distanceMeters = distanceMeters
        inProgress[driveID]?.route = route
    }

    func delete(driveID: Drive.ID) throws {
        if let failure { throw failure }
        removeFinished(driveID)
        inProgress[driveID] = nil
    }

    func recoverUnfinishedDrives() throws -> Int {
        if let failure { throw failure }
        let unfinished = inProgress.values
        for var drive in unfinished {
            drive.status = .finished
            summaries.append(drive.summary)
            issues.append(contentsOf: drive.issues)
        }
        inProgress = [:]
        return unfinished.count
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

    private func removeFinished(_ id: Drive.ID) {
        summaries.removeAll { $0.id == id }
        issues.removeAll { $0.driveID == id }
    }
}
