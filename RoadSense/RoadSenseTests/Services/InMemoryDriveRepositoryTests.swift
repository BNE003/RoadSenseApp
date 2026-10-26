//
//  InMemoryDriveRepositoryTests.swift
//  RoadSenseTests
//

import Foundation
import Testing
@testable import RoadSense

struct InMemoryDriveRepositoryTests {
    @Test func savedDriveAppearsFirstInSummaries() async throws {
        let now = Date()
        let repository = SampleData.repository(now: now)
        var drive = Drive.sample(now: now)
        drive.startedAt = now.addingTimeInterval(30 * 24 * 3600)   // newer than every sample drive
        try await repository.save(drive)
        let summaries = try await repository.driveSummaries(limit: 2)
        #expect(summaries.count == 2)
        #expect(summaries.first?.id == drive.id)
    }

    @Test func savingTwiceReplacesInsteadOfDuplicating() async throws {
        let repository = InMemoryDriveRepository()
        let drive = Drive.sample()
        try await repository.save(drive)
        try await repository.save(drive)
        #expect(try await repository.driveSummaries(limit: nil).count == 1)
        #expect(try await repository.issues(focus: .all).count == 11)
    }

    @Test func focusedIssuesBelongToTheDrive() async throws {
        let repository = SampleData.repository()
        let issues = try await repository.issues(focus: .drive(SampleData.id(2)))
        #expect(issues.count == 2)
        #expect(issues.allSatisfy { $0.driveID == SampleData.id(2) })
    }

    @Test func totalsIncludeArchivedHistory() async throws {
        let repository = SampleData.repository()
        let totals = try await repository.totals()
        #expect(totals.driveCount == 23)
        #expect(Int((totals.distanceMeters / 1000).rounded()) == 412)
    }

    @Test func totalsGrowWithEachSavedDrive() async throws {
        let repository = SampleData.repository()
        try await repository.save(Drive.sample())
        let totals = try await repository.totals()
        #expect(totals.driveCount == 24)
    }

    @Test func failureIsThrown() async {
        let repository = InMemoryDriveRepository(failure: .saveFailed)
        await #expect(throws: PersistenceError.self) { try await repository.save(Drive.sample()) }
    }
}
