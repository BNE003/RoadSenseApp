//
//  HistoryViewModel.swift
//  RoadSense
//

import Foundation
import Observation

@MainActor @Observable
final class HistoryViewModel {
    struct Section: Identifiable {
        let title: LocalizedStringResource
        let drives: [DriveSummary]
        var id: String { String(localized: title) }
    }

    private let repository: any DriveRepository
    private let now: @Sendable () -> Date

    private var drives: [DriveSummary] = []
    private var totals = HistoryTotals(driveCount: 0, distanceMeters: 0)
    private(set) var isLoaded = false
    private(set) var loadError: String?

    init(environment: AppEnvironment) {
        repository = environment.drives
        now = environment.now
    }

    var isEmpty: Bool { isLoaded && drives.isEmpty }

    /// "23 drives · 412 km inspected"
    var subtitle: String {
        let count = totals.driveCount, kilometers = DriveFormatting.wholeKilometers(totals.distanceMeters)
        return count == 1
            ? String(localized: "1 drive · \(kilometers) km inspected")
            : String(localized: "\(count) drives · \(kilometers) km inspected")
    }

    /// Drives of the last seven days, then everything older.
    var sections: [Section] {
        let cutoff = now().addingTimeInterval(-7 * 24 * 3600)
        let recent = drives.filter { $0.startedAt >= cutoff }
        let earlier = drives.filter { $0.startedAt < cutoff }
        return [
            recent.isEmpty ? nil : Section(title: "This week", drives: recent),
            earlier.isEmpty ? nil : Section(title: "Earlier", drives: earlier),
        ].compactMap { $0 }
    }

    func meta(for drive: DriveSummary) -> String {
        DriveFormatting.longMeta(drive, now: now())
    }

    func load() async {
        do {
            drives = try await repository.driveSummaries(limit: nil)
            totals = try await repository.totals()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        isLoaded = true
    }
}
