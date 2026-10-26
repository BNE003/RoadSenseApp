//
//  DriveRepository.swift
//  RoadSense
//

import Foundation

/// Stores drives and the issues found on them.
///
/// A drive being recorded is stored as `.inProgress` and grows through `append` and
/// `checkpoint`, so a crash loses at most the last checkpoint interval. In-progress drives are
/// not part of `driveSummaries`, `totals` or `issues(focus: .all)`.
nonisolated protocol DriveRepository: Sendable {
    /// Inserts or replaces a drive and its issues.
    func save(_ drive: Drive) async throws
    /// Adds one issue to a drive that is already stored.
    func append(_ issue: DetectedIssue) async throws
    /// Updates the running totals of an in-progress drive.
    func checkpoint(driveID: Drive.ID, endedAt: Date, distanceMeters: Double, route: [Coordinate]) async throws
    func delete(driveID: Drive.ID) async throws
    /// Finishes drives left in progress by a crash or kill; returns how many there were.
    func recoverUnfinishedDrives() async throws -> Int
    /// Finished drives, newest first.
    func driveSummaries(limit: Int?) async throws -> [DriveSummary]
    func totals() async throws -> HistoryTotals
    func issues(focus: MapFocus) async throws -> [DetectedIssue]
}
