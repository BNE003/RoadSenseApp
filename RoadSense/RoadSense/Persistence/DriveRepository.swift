//
//  DriveRepository.swift
//  RoadSense
//

import Foundation

/// Stores finished drives and the issues found on them.
nonisolated protocol DriveRepository: Sendable {
    /// Inserts or replaces a drive and its issues.
    func save(_ drive: Drive) async throws
    /// Newest first.
    func driveSummaries(limit: Int?) async throws -> [DriveSummary]
    func totals() async throws -> HistoryTotals
    func issues(focus: MapFocus) async throws -> [DetectedIssue]
}
