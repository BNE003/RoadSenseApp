//
//  DeduplicationSimulationTests.swift
//  RoadSenseTests
//

import Foundation
import Testing
@testable import RoadSense

/// A deterministic random source, so the simulated drives are the same on every run.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

/// One real pothole passed at 10 m/s, seen at 10 inferences per second like the live pipeline.
/// The detector is imperfect like a real one: it misses frames in runs, the box jitters, and now and
/// then it also reports a second, smaller box inside the pothole.
private func simulatedPass(
    seed: UInt64, kind: IssueKind = .pothole, startTime: TimeInterval = 0, lateral: Double = 1.35
) -> [(time: TimeInterval, detections: [RawDetection])] {
    var random = SeededRandom(seed: seed)
    var missesLeft = 0
    var frames: [(TimeInterval, [RawDetection])] = []
    for step in 0...25 {
        let time = Double(step) * 0.1
        let distance = 30 - 10 * time                       // meters ahead; 5 m at the end
        let size = 1.5 / distance
        func jitter() -> Double { 1 + (random.next() - 0.5) * 0.2 }
        let box = NormalizedRect(
            x: 0.5 + lateral / distance - size / 2, y: 0.4 + 3 / distance - size / 2,
            width: size * jitter(), height: size * jitter()
        )
        if missesLeft == 0, random.next() < 0.15 { missesLeft = 1 + Int(random.next() * 3) }   // 1 to 3 frames
        if missesLeft > 0 {
            missesLeft -= 1
            frames.append((time + startTime, []))
            continue
        }
        var found = [RawDetection(kind: kind, confidence: 0.6, rect: box)]
        if random.next() < 0.3 {
            let inner = NormalizedRect(
                x: box.x + box.width * 0.25, y: box.y + box.height * 0.25,
                width: box.width * 0.5, height: box.height * 0.5
            )
            found.append(RawDetection(kind: kind, confidence: 0.4, rect: inner))
        }
        frames.append((time + startTime, found))
    }
    return frames
}

struct DeduplicationSimulationTests {
    private func issues(in frames: [(time: TimeInterval, detections: [RawDetection])]) -> Int {
        var deduplicator = IssueDeduplicator()
        return frames.reduce(0) { $0 + deduplicator.ingest($1.detections, at: $1.time).count }
    }

    @Test func oneRealPotholeIsOneIssueNoMatterHowTheDetectorFlickers() {
        // Before the fix this averaged 7.3 issues per pothole and reached 12.
        for seed in UInt64(1)...200 {
            #expect(issues(in: simulatedPass(seed: seed)) == 1, "seed \(seed)")
        }
    }

    @Test func oneRealCrackIsOneIssueToo() {
        for seed in UInt64(1)...50 {
            #expect(issues(in: simulatedPass(seed: seed, kind: .crack)) == 1, "seed \(seed)")
        }
    }

    @Test func twoPotholesOneAfterTheOtherAreTwoIssues() {
        for seed in UInt64(1)...50 {
            let first = simulatedPass(seed: seed)
            let second = simulatedPass(seed: seed + 1000, startTime: 3, lateral: -1.35)
            #expect(issues(in: first + second) == 2, "seed \(seed)")
        }
    }

    @Test func aPotholeAndACrackAtTheSamePlaceAreTwoIssues() {
        let pothole = simulatedPass(seed: 7)
        let crack = simulatedPass(seed: 7, kind: .crack)
        let merged = zip(pothole, crack).map { (time: $0.time, detections: $0.detections + $1.detections) }
        #expect(issues(in: merged) == 2)
    }
}
