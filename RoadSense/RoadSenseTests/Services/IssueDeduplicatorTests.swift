//
//  IssueDeduplicatorTests.swift
//  RoadSenseTests
//

import Foundation
import Testing
@testable import RoadSense

struct IssueDeduplicatorTests {
    /// Feeds one frame per entry, 0.1 s apart, and returns how many new issues each produced.
    private func counts(_ frames: [[RawDetection]], step: TimeInterval = 0.1) -> [Int] {
        var deduplicator = IssueDeduplicator()
        return frames.enumerated().map { deduplicator.ingest($1, at: Double($0) * step).count }
    }

    @Test func aPotholeSeenForSeveralFramesIsOneIssue() {
        #expect(counts(Array(repeating: [.pothole()], count: 4)) == [1, 0, 0, 0])
    }

    @Test func aPotholeReappearingAfterTheGapIsANewIssue() {
        // Gone for 3 s, longer than a track waits.
        #expect(counts([[.pothole()], [], [], [.pothole()]], step: 1) == [1, 0, 0, 1])
    }

    @Test func aDetectorThatFlickersDoesNotSplitAnIssue() {
        // Three missed frames in a row (0.3 s) used to close the track.
        #expect(counts([[.pothole()], [], [], [], [.pothole()]]) == [1, 0, 0, 0, 0])
    }

    @Test func differentKindsAtTheSamePlaceAreSeparateIssues() {
        var deduplicator = IssueDeduplicator()
        let rect = NormalizedRect(x: 0.4, y: 0.5, width: 0.2, height: 0.1)
        let fresh = deduplicator.ingest([
            RawDetection(kind: .pothole, confidence: 0.9, rect: rect),
            RawDetection(kind: .crack, confidence: 0.9, rect: rect),
        ], at: 0)
        #expect(fresh.count == 2)
    }

    @Test func separateBoxesOfTheSameKindAreSeparateIssues() {
        #expect(counts([[.pothole(x: 0.1), .pothole(x: 0.7)]]) == [2])
    }

    @Test func aMovingBoxKeepsItsIdentity() {
        #expect(counts([[.pothole(x: 0.40)], [.pothole(x: 0.42)], [.pothole(x: 0.44)]]) == [1, 0, 0])
    }

    @Test func aFastMovingBoxIsFollowedByItsMotion() {
        // Moves 0.15 per frame (box width 0.2): each step alone overlaps little, the motion is steady.
        let frames = (0..<6).map { [RawDetection.pothole(x: 0.05 + 0.15 * Double($0))] }
        #expect(counts(frames) == [1, 0, 0, 0, 0, 0])
    }

    @Test func aSmallBoxInsideALargeBoxIsTheSameObject() {
        let large = RawDetection(kind: .pothole, confidence: 0.8, rect: NormalizedRect(x: 0.3, y: 0.5, width: 0.4, height: 0.3))
        let inner = RawDetection(kind: .pothole, confidence: 0.5, rect: NormalizedRect(x: 0.4, y: 0.58, width: 0.15, height: 0.1))
        #expect(counts([[large, inner], [inner], [large]]) == [1, 0, 0])
    }

    @Test func theMostConfidentBoxOfAFrameIsTheOneReported() {
        var deduplicator = IssueDeduplicator()
        let weak = RawDetection(kind: .pothole, confidence: 0.4, rect: NormalizedRect(x: 0.4, y: 0.58, width: 0.15, height: 0.1))
        let strong = RawDetection(kind: .pothole, confidence: 0.9, rect: NormalizedRect(x: 0.3, y: 0.5, width: 0.4, height: 0.3))
        #expect(deduplicator.ingest([weak, strong], at: 0).map(\.confidence) == [0.9])
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
