//
//  IssueDeduplicatorTests.swift
//  RoadSenseTests
//

import Testing
@testable import RoadSense

struct IssueDeduplicatorTests {
    @Test func aPotholeSeenForSeveralFramesIsOneIssue() {
        var deduplicator = IssueDeduplicator()
        let counts = (0..<4).map { _ in deduplicator.ingest([.pothole()]).count }
        #expect(counts == [1, 0, 0, 0])
    }

    @Test func aPotholeReappearingLaterIsANewIssue() {
        var deduplicator = IssueDeduplicator()
        _ = deduplicator.ingest([.pothole()])
        _ = deduplicator.ingest([])
        _ = deduplicator.ingest([])   // second missed frame closes the track
        #expect(deduplicator.ingest([.pothole()]).count == 1)
    }

    @Test func oneMissedFrameDoesNotSplitAnIssue() {
        var deduplicator = IssueDeduplicator()
        _ = deduplicator.ingest([.pothole()])
        _ = deduplicator.ingest([])
        #expect(deduplicator.ingest([.pothole()]).isEmpty)
    }

    @Test func differentKindsAtTheSamePlaceAreSeparateIssues() {
        var deduplicator = IssueDeduplicator()
        let rect = NormalizedRect(x: 0.4, y: 0.5, width: 0.2, height: 0.1)
        let fresh = deduplicator.ingest([
            RawDetection(kind: .pothole, confidence: 0.9, rect: rect),
            RawDetection(kind: .crack, confidence: 0.9, rect: rect),
        ])
        #expect(fresh.count == 2)
    }

    @Test func separateBoxesOfTheSameKindAreSeparateIssues() {
        var deduplicator = IssueDeduplicator()
        let fresh = deduplicator.ingest([.pothole(x: 0.1), .pothole(x: 0.7)])
        #expect(fresh.count == 2)
    }

    @Test func aMovingBoxKeepsItsIdentity() {
        var deduplicator = IssueDeduplicator()
        _ = deduplicator.ingest([.pothole(x: 0.40)])
        #expect(deduplicator.ingest([.pothole(x: 0.42)]).isEmpty)
        #expect(deduplicator.ingest([.pothole(x: 0.44)]).isEmpty)
    }
}

struct MockDetectionServiceTests {
    @Test func scriptShowsABoxOnlyWhileVisible() async throws {
        let service = MockDetectionService(script: [
            ScriptedDetection(at: 2, visibleFor: 4, kind: .pothole, rect: NormalizedRect(x: 0, y: 0, width: 0.1, height: 0.1)),
        ])
        func count(at time: Double) async throws -> Int {
            try await service.detect(in: CameraFrame(timestamp: time), mountHeight: .standard).count
        }
        #expect(try await count(at: 1) == 0)
        #expect(try await count(at: 2) == 1)
        #expect(try await count(at: 5) == 1)
        #expect(try await count(at: 6) == 0)
    }

    @Test func onlySupportedKindsAreReported() async throws {
        var service = MockDetectionService()
        service.supportedKinds = [.pothole]
        for time in stride(from: 0.0, to: 60, by: 1) {
            let found = try await service.detect(in: CameraFrame(timestamp: time), mountHeight: .standard)
            #expect(found.allSatisfy { $0.kind == .pothole })
        }
    }

    @Test func demoScriptProducesPotholesCracksAndSigns() async throws {
        let service = MockDetectionService()
        var kinds = Set<IssueKind>()
        for time in stride(from: 0.0, to: 60, by: 1) {
            kinds.formUnion(try await service.detect(in: CameraFrame(timestamp: time), mountHeight: .standard).map(\.kind))
        }
        #expect(kinds == Set(IssueKind.allCases))
    }
}
