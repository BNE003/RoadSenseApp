//
//  DetectionService.swift
//  RoadSense
//

import Foundation

/// One box reported by the detector for a single frame.
nonisolated struct RawDetection: Hashable, Sendable {
    var kind: IssueKind
    var confidence: Double
    var rect: NormalizedRect
}

nonisolated protocol DetectionService: Sendable {
    /// The kinds this detector can report. The UI shows only these.
    var supportedKinds: Set<IssueKind> { get }
    /// Loads the model. Called once before the first `detect`.
    func prepare() async throws
    func detect(in frame: CameraFrame, mountHeight: MountHeight) async throws -> [RawDetection]
}
