//
//  MockDetectionService.swift
//  RoadSense
//

import Foundation

/// A box that is visible for a few seconds starting at `at`.
nonisolated struct ScriptedDetection: Sendable {
    var at: TimeInterval
    var visibleFor: TimeInterval = 4
    var kind: IssueKind
    var rect: NormalizedRect
    var confidence = 0.85

    func isVisible(at time: TimeInterval) -> Bool { time >= at && time < at + visibleFor }
}

/// Replays a fixed timeline instead of looking at pixels.
nonisolated struct MockDetectionService: DetectionService {
    var script: [ScriptedDetection] = ScriptedDetection.demo()
    var supportedKinds: Set<IssueKind> = Set(IssueKind.allCases)

    func prepare() async throws {}

    func detect(in frame: CameraFrame, mountHeight: MountHeight) async throws -> [RawDetection] {
        script
            .filter { supportedKinds.contains($0.kind) && $0.isVisible(at: frame.timestamp) }
            .map { RawDetection(kind: $0.kind, confidence: $0.confidence, rect: $0.rect) }
    }
}

nonisolated extension ScriptedDetection {
    /// The prototype's timeline: a pothole every 9 s, a crack every 6 s, a sign every 40 s.
    /// Rectangles are the design's boxes on its 370 × 824 canvas.
    static func demo(duration: TimeInterval = 3600) -> [ScriptedDetection] {
        func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> NormalizedRect {
            NormalizedRect(x: x / 370, y: y / 824, width: w / 370, height: h / 824)
        }
        var script: [ScriptedDetection] = []
        for t in stride(from: 2.0, to: duration, by: 9) {
            script.append(.init(at: t, kind: .pothole, rect: rect(150, 400, 96, 52)))
        }
        for t in stride(from: 5.0, to: duration, by: 40) {
            script.append(.init(at: t, kind: .sign, rect: rect(40, 330, 70, 90)))
        }
        for t in stride(from: 8.0, to: duration, by: 6) {
            script.append(.init(at: t, kind: .crack, rect: rect(240, 470, 110, 40)))
        }
        return script
    }
}
