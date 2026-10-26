//
//  SampleData.swift
//  RoadSense
//

import Foundation

/// Deterministic demo data for the Milestone 1 mock environment, previews and tests.
/// Numbers and names are the ones from the design.
nonisolated enum SampleData {
    /// A stable UUID built from a small number, so sample data is identical on every launch.
    static func id(_ n: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, n))
    }

    private static func counts(_ pothole: Int, _ crack: Int, _ sign: Int) -> [IssueKind: Int] {
        [.pothole: pothole, .crack: crack, .sign: sign].filter { $0.value > 0 }
    }

    static func summaries(now: Date, calendar: Calendar = .current) -> [DriveSummary] {
        func day(_ offset: Int, hour: Int, minute: Int) -> Date {
            let base = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }
        return [
            DriveSummary(id: id(1), name: "Commute, Nord–Süd", startedAt: day(0, hour: 9, minute: 3),
                         duration: 38 * 60, distanceMeters: 24_600, counts: counts(3, 7, 1)),
            DriveSummary(id: id(2), name: "Airport run", startedAt: day(1, hour: 14, minute: 20),
                         duration: 52 * 60, distanceMeters: 41_200, counts: counts(2, 3, 1)),
            DriveSummary(id: id(3), name: "Old town loop", startedAt: day(4, hour: 10, minute: 5),
                         duration: 21 * 60, distanceMeters: 8_900, counts: counts(5, 8, 1)),
            DriveSummary(id: id(4), name: "Ring road", startedAt: day(8, hour: 7, minute: 45),
                         duration: 40 * 60, distanceMeters: 33_000, counts: counts(1, 2, 0)),
            DriveSummary(id: id(5), name: "Harbour district", startedAt: day(11, hour: 16, minute: 10),
                         duration: 29 * 60, distanceMeters: 12_400, counts: counts(3, 5, 1)),
        ]
    }

    /// The seven issues shown on the design's map, at the design's positions.
    static func issues(now: Date, calendar: Calendar = .current) -> [DetectedIssue] {
        func issue(_ n: UInt8, drive: UInt8, _ kind: IssueKind, x: Double, y: Double, daysAgo: Int,
                   _ place: String, _ note: String) -> DetectedIssue {
            DetectedIssue(
                id: id(100 + n), driveID: id(drive), kind: kind, confidence: 0.85,
                detectedAt: calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now,
                coordinate: MapViewport.demo.coordinate(x: x / 370, y: y / 824),
                place: place, note: note
            )
        }
        return [
            issue(0, drive: 1, .pothole, x: 110, y: 250, daysAgo: 0, "Rosenstrasse 14", "Deep, 40 cm wide. Lane 1."),
            issue(1, drive: 1, .crack, x: 230, y: 330, daysAgo: 0, "Mühlenweg", "Longitudinal crack, 12 m."),
            issue(2, drive: 2, .sign, x: 160, y: 440, daysAgo: 1, "Hauptstrasse 3", "Speed limit sign bent."),
            issue(3, drive: 2, .pothole, x: 290, y: 520, daysAgo: 1, "Bahnhofplatz", "Two potholes, cluster."),
            issue(4, drive: 3, .crack, x: 80, y: 560, daysAgo: 4, "Am Kanal", "Edge cracking."),
            issue(5, drive: 3, .crack, x: 200, y: 200, daysAgo: 4, "Lindenallee", "Network of fine cracks."),
            issue(6, drive: 4, .pothole, x: 300, y: 640, daysAgo: 6, "Gartenstrasse 40", "Shallow, 25 cm."),
        ]
    }

    /// History beyond the five listed drives: 23 drives and 412 km in total.
    static let archivedTotals = HistoryTotals(driveCount: 18, distanceMeters: 412_000 - 120_100)

    static func repository(now: Date = Date()) -> InMemoryDriveRepository {
        InMemoryDriveRepository(
            summaries: summaries(now: now),
            issues: issues(now: now),
            archivedTotals: archivedTotals
        )
    }
}

nonisolated extension Drive {
    /// A finished drive with 11 issues (3 potholes, 7 cracks, 1 sign), 24.6 km, 38 min.
    static func sample(now: Date = Date(), calendar: Calendar = .current) -> Drive {
        let start = calendar.date(bySettingHour: 9, minute: 41, second: 0, of: now) ?? now
        let kinds: [IssueKind] = Array(repeating: .pothole, count: 3)
            + Array(repeating: .crack, count: 7) + [.sign]
        let driveID = SampleData.id(50)
        let issues = kinds.enumerated().map { index, kind in
            DetectedIssue(
                id: SampleData.id(UInt8(60 + index)), driveID: driveID, kind: kind, confidence: 0.85,
                detectedAt: start.addingTimeInterval(Double(index) * 150),
                coordinate: MapViewport.demo.coordinate(x: 0.5, y: 0.9 - Double(index) * 0.06),
                place: nil, note: nil
            )
        }
        return Drive(
            id: driveID, name: "Commute, Nord–Süd", startedAt: start,
            endedAt: start.addingTimeInterval(38 * 60), distanceMeters: 24_600, issues: issues
        )
    }
}
