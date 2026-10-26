//
//  IssueDeduplicator.swift
//  RoadSense
//

import Foundation

/// Turns per-frame detections into distinct issues: a pothole visible for several frames is
/// one issue, not many. A detection continues an existing track when it has the same kind and
/// overlaps the track's last box.
nonisolated struct IssueDeduplicator: Sendable {
    var iouThreshold = 0.3
    /// How many consecutive frames a track may go unseen (detector flicker) before it closes.
    var maxMissedFrames = 1

    private struct Track {
        var kind: IssueKind
        var rect: NormalizedRect
        var missed = 0
    }

    private var tracks: [Track] = []

    init(iouThreshold: Double = 0.3, maxMissedFrames: Int = 1) {
        self.iouThreshold = iouThreshold
        self.maxMissedFrames = maxMissedFrames
    }

    /// Feeds one frame's detections and returns the ones that start a new issue.
    mutating func ingest(_ detections: [RawDetection]) -> [RawDetection] {
        var matched = Set<Int>()
        var fresh: [RawDetection] = []

        for detection in detections {
            let best = tracks.indices
                .filter { !matched.contains($0) && tracks[$0].kind == detection.kind }
                .map { (index: $0, iou: tracks[$0].rect.iou(detection.rect)) }
                .filter { $0.iou >= iouThreshold }
                .max { $0.iou < $1.iou }

            if let best {
                matched.insert(best.index)
                tracks[best.index].rect = detection.rect
                tracks[best.index].missed = 0
            } else {
                tracks.append(Track(kind: detection.kind, rect: detection.rect))
                matched.insert(tracks.count - 1)
                fresh.append(detection)
            }
        }

        for index in tracks.indices where !matched.contains(index) {
            tracks[index].missed += 1
        }
        tracks.removeAll { $0.missed > maxMissedFrames }
        return fresh
    }
}
