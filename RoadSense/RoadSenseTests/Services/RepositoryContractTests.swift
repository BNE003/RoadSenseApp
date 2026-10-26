//
//  RepositoryContractTests.swift
//  RoadSenseTests
//

import Foundation
import SwiftData
import Testing
@testable import RoadSense

/// The rules every `DriveRepository` follows, checked against the in-memory and the SwiftData one.
struct RepositoryContractTests {
    enum Kind: CaseIterable, CustomTestStringConvertible {
        case inMemory, swiftData
        var testDescription: String { self == .inMemory ? "in memory" : "SwiftData" }

        func make() throws -> any DriveRepository {
            switch self {
            case .inMemory: InMemoryDriveRepository()
            case .swiftData: SwiftDataDriveRepository(modelContainer: try .roadSense(inMemory: true))
            }
        }
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func drive(
        id: UUID = UUID(), minutesAgo: Double = 0, kinds: [IssueKind] = [], status: DriveStatus = .finished,
        distance: Double = 1_000
    ) -> Drive {
        let startedAt = start.addingTimeInterval(-minutesAgo * 60)
        return Drive(
            id: id, name: "Drive", startedAt: startedAt, endedAt: startedAt.addingTimeInterval(600),
            distanceMeters: distance,
            issues: kinds.map { issue($0, in: id, at: startedAt) },
            status: status,
            route: [Coordinate(latitude: 52, longitude: 13), Coordinate(latitude: 52.01, longitude: 13)]
        )
    }

    private func issue(_ kind: IssueKind, in driveID: UUID, at date: Date) -> DetectedIssue {
        DetectedIssue(
            id: UUID(), driveID: driveID, kind: kind, confidence: 0.8, detectedAt: date,
            coordinate: Coordinate(latitude: 52.5, longitude: 13.4), horizontalAccuracy: 6, speed: 9, heading: 90,
            place: nil, note: nil
        )
    }

    @Test(arguments: Kind.allCases)
    func aSavedDriveIsListedWithItsCounts(kind: Kind) async throws {
        let repository = try kind.make()
        try await repository.save(drive(kinds: [.pothole, .pothole, .crack]))
        let summaries = try await repository.driveSummaries(limit: nil)
        #expect(summaries.count == 1)
        #expect(summaries.first?.count(of: .pothole) == 2)
        #expect(summaries.first?.count(of: .crack) == 1)
        #expect(summaries.first?.duration == 600)
    }

    @Test(arguments: Kind.allCases)
    func savingTwiceReplacesTheDrive(kind: Kind) async throws {
        let repository = try kind.make()
        let id = UUID()
        try await repository.save(drive(id: id, kinds: [.pothole]))
        try await repository.save(drive(id: id, kinds: [.pothole, .pothole, .pothole]))
        let summaries = try await repository.driveSummaries(limit: nil)
        #expect(summaries.count == 1)
        #expect(summaries.first?.count(of: .pothole) == 3)
        #expect(try await repository.issues(focus: .all).count == 3)
    }

    @Test(arguments: Kind.allCases)
    func drivesListNewestFirstAndRespectTheLimit(kind: Kind) async throws {
        let repository = try kind.make()
        let oldest = drive(minutesAgo: 120), middle = drive(minutesAgo: 60), newest = drive(minutesAgo: 5)
        for item in [middle, oldest, newest] { try await repository.save(item) }
        #expect(try await repository.driveSummaries(limit: nil).map(\.id) == [newest.id, middle.id, oldest.id])
        #expect(try await repository.driveSummaries(limit: 2).map(\.id) == [newest.id, middle.id])
    }

    @Test(arguments: Kind.allCases)
    func totalsCountFinishedDrivesOnly(kind: Kind) async throws {
        let repository = try kind.make()
        try await repository.save(drive(distance: 1_000))
        try await repository.save(drive(distance: 2_500))
        try await repository.save(drive(status: .inProgress, distance: 9_000))
        let totals = try await repository.totals()
        #expect(totals.driveCount == 2)
        #expect(totals.distanceMeters == 3_500)
    }

    @Test(arguments: Kind.allCases)
    func issuesFilterByDriveAndKeepEveryDetail(kind: Kind) async throws {
        let repository = try kind.make()
        let first = drive(kinds: [.pothole]), second = drive(kinds: [.sign, .crack])
        try await repository.save(first)
        try await repository.save(second)
        #expect(try await repository.issues(focus: .all).count == 3)
        let ofFirst = try await repository.issues(focus: .drive(first.id))
        #expect(ofFirst.count == 1)
        let stored = try #require(ofFirst.first)
        #expect(stored == first.issues[0])
    }

    @Test(arguments: Kind.allCases)
    func anIssueWithoutAFixKeepsNoCoordinate(kind: Kind) async throws {
        let repository = try kind.make()
        var item = drive(kinds: [.pothole])
        item.issues[0].coordinate = nil
        item.issues[0].horizontalAccuracy = nil
        try await repository.save(item)
        #expect(try await repository.issues(focus: .all).first?.coordinate == nil)
    }

    // MARK: In progress

    @Test(arguments: Kind.allCases)
    func aDriveInProgressGrowsThroughAppendAndCheckpoint(kind: Kind) async throws {
        let repository = try kind.make()
        let id = UUID()
        try await repository.save(drive(id: id, status: .inProgress, distance: 0))
        try await repository.append(issue(.pothole, in: id, at: start))
        try await repository.append(issue(.pothole, in: id, at: start))
        try await repository.checkpoint(
            driveID: id, endedAt: start.addingTimeInterval(900), distanceMeters: 4_200,
            route: [Coordinate(latitude: 1, longitude: 2)]
        )

        #expect(try await repository.driveSummaries(limit: nil).isEmpty)
        #expect(try await repository.totals().driveCount == 0)
        #expect(try await repository.issues(focus: .all).isEmpty)

        #expect(try await repository.recoverUnfinishedDrives() == 1)
        let summary = try #require(try await repository.driveSummaries(limit: nil).first)
        #expect(summary.count(of: .pothole) == 2)
        #expect(summary.distanceMeters == 4_200)
        #expect(summary.duration == 900)
        #expect(try await repository.recoverUnfinishedDrives() == 0)
    }

    @Test(arguments: Kind.allCases)
    func savingAFinishedDriveEndsItsProgressState(kind: Kind) async throws {
        let repository = try kind.make()
        let id = UUID()
        try await repository.save(drive(id: id, kinds: [.pothole], status: .inProgress))
        try await repository.save(drive(id: id, kinds: [.pothole], status: .finished))
        #expect(try await repository.recoverUnfinishedDrives() == 0)
        #expect(try await repository.driveSummaries(limit: nil).count == 1)
    }

    @Test(arguments: Kind.allCases)
    func appendingToAnUnknownDriveFails(kind: Kind) async throws {
        let repository = try kind.make()
        await #expect(throws: PersistenceError.self) {
            try await repository.append(issue(.pothole, in: UUID(), at: start))
        }
    }

    @Test(arguments: Kind.allCases)
    func deletingADriveRemovesItsIssues(kind: Kind) async throws {
        let repository = try kind.make()
        let kept = drive(kinds: [.pothole]), removed = drive(kinds: [.crack, .crack])
        try await repository.save(kept)
        try await repository.save(removed)
        try await repository.delete(driveID: removed.id)
        #expect(try await repository.driveSummaries(limit: nil).map(\.id) == [kept.id])
        #expect(try await repository.issues(focus: .all).count == 1)
    }
}
