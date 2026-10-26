//
//  SummaryViewModel.swift
//  RoadSense
//

import Foundation
import Observation

@MainActor @Observable
final class SummaryViewModel {
    enum SaveState: Equatable {
        case unsaved, saving, saved
        case failed(String)
    }

    struct BreakdownRow: Identifiable {
        let kind: IssueKind
        let count: Int
        let fraction: Double
        var id: IssueKind { kind }
    }

    let drive: Drive
    private let summary: DriveSummary
    private let kinds: [IssueKind]
    private let repository: any DriveRepository
    private let now: @Sendable () -> Date

    private(set) var saveState: SaveState = .unsaved
    var isConfirmingDiscard = false

    init(drive: Drive, environment: AppEnvironment) {
        self.drive = drive
        summary = drive.summary
        kinds = IssueKind.allCases.filter { environment.detection.supportedKinds.contains($0) }
        repository = environment.drives
        now = environment.now
    }

    var totalIssues: Int { summary.totalIssues }
    var distanceText: String { DriveFormatting.kilometers(summary.distanceMeters) }
    var minutesText: String { DriveFormatting.minutes(summary.duration) }
    var dateText: String { DriveFormatting.dayAndTime(summary.startedAt, now: now()) }
    var isSaved: Bool { saveState == .saved }

    var breakdown: [BreakdownRow] {
        kinds.map { BreakdownRow(kind: $0, count: summary.count(of: $0), fraction: summary.fraction(of: $0)) }
    }

    var errorText: String? {
        if case .failed(let message) = saveState { message } else { nil }
    }

    /// Saves the drive once. Returns whether it is stored afterwards.
    func save() async -> Bool {
        switch saveState {
        case .saved: return true
        case .saving: return false
        case .unsaved, .failed: break
        }
        saveState = .saving
        do {
            try await repository.save(drive)
            saveState = .saved
            return true
        } catch {
            saveState = .failed(error.localizedDescription)
            return false
        }
    }
}
