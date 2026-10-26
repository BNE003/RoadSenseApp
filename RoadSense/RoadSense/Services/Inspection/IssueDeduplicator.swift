//
//  IssueDeduplicator.swift
//  RoadSense
//

import Foundation

/// Turns per-frame detections into distinct issues: a pothole seen for several seconds is one
/// issue, not one per frame.
///
/// A detection continues an existing track of the same kind when it overlaps where the track's box
/// was, or where it should be by now. Three things make this robust against a real detector:
/// - a track survives `maxGap` seconds without a detection, not a fixed number of frames, so a
///   score that flickers around the threshold does not split one pothole into several;
/// - the box is extrapolated with its recent motion, because an approaching pothole moves down and
///   grows quickly in the image;
/// - a box lying mostly inside another box of the same kind counts as the same object, which also
///   merges the two boxes a detector sometimes draws on one pothole or crack;
/// - a box that reappears close to where a track was, within one box length, still continues it:
///   near the car the image motion accelerates, so after a missed frame the new box may not overlap
///   the old one at all.
nonisolated struct IssueDeduplicator: Sendable {
    /// Overlap (IoU) that is enough to continue a track.
    var iouThreshold = 0.2
    /// Share of the smaller box inside the other that is enough to continue a track.
    var containmentThreshold = 0.7
    /// How far from a track (center to center, in units of the larger box's long side) a box may
    /// appear and still continue it without overlapping.
    var reach = 1.0
    /// Seconds a track waits for its object to reappear before it closes.
    var maxGap: TimeInterval = 2

    private struct Track {
        var kind: IssueKind
        var rect: NormalizedRect
        var lastSeen: TimeInterval
        /// Change of the box per second, smoothed over the track's life.
        var velocity = NormalizedRect(x: 0, y: 0, width: 0, height: 0)

        func predicted(at time: TimeInterval, maxGap: TimeInterval) -> NormalizedRect {
            let elapsed = min(max(0, time - lastSeen), maxGap)
            return NormalizedRect(
                x: rect.x + velocity.x * elapsed, y: rect.y + velocity.y * elapsed,
                width: max(0.005, rect.width + velocity.width * elapsed),
                height: max(0.005, rect.height + velocity.height * elapsed)
            )
        }
    }

    private var tracks: [Track] = []

    init(iouThreshold: Double = 0.2, containmentThreshold: Double = 0.7, reach: Double = 1, maxGap: TimeInterval = 2) {
        self.iouThreshold = iouThreshold
        self.containmentThreshold = containmentThreshold
        self.reach = reach
        self.maxGap = maxGap
    }

    /// Feeds one frame's detections, taken at `time` (seconds, increasing), and returns the ones
    /// that start a new issue.
    mutating func ingest(_ detections: [RawDetection], at time: TimeInterval) -> [RawDetection] {
        tracks.removeAll { time - $0.lastSeen > maxGap }
        var fresh: [RawDetection] = []

        // Most confident first: it defines the track's box, weaker overlapping boxes are absorbed.
        for detection in detections.sorted(by: { $0.confidence > $1.confidence }) {
            if let index = bestTrack(for: detection, at: time) {
                update(index, with: detection.rect, at: time)
            } else {
                tracks.append(Track(kind: detection.kind, rect: detection.rect, lastSeen: time))
                fresh.append(detection)
            }
        }
        return fresh
    }

    private func bestTrack(for detection: RawDetection, at time: TimeInterval) -> Int? {
        var best: (index: Int, affinity: Double)?
        for (index, track) in tracks.enumerated() where track.kind == detection.kind {
            let score = [track.rect, track.predicted(at: time, maxGap: maxGap)]
                .map { affinity(detection.rect, $0) }
                .max() ?? 0
            if score > 0, score > (best?.affinity ?? 0) { best = (index, score) }
        }
        return best?.index
    }

    /// How strongly `rect` continues `other`, or 0 if it does not.
    private func affinity(_ rect: NormalizedRect, _ other: NormalizedRect) -> Double {
        let iou = rect.iou(other)
        let containment = rect.containment(in: other)
        if iou >= iouThreshold || containment >= containmentThreshold {
            return max(iou, containment * 0.5)
        }
        // Not overlapping: continue the track only if the box is within reach. Always scores below
        // an overlapping match.
        let distance = hypot(rect.midX - other.midX, rect.midY - other.midY)
        let limit = reach * max(rect.longSide, other.longSide)
        return distance <= limit ? 0.05 * (1 - distance / limit) + 0.001 : 0
    }

    private mutating func update(_ index: Int, with rect: NormalizedRect, at time: TimeInterval) {
        let elapsed = time - tracks[index].lastSeen
        // A second box in the same frame adds no motion information.
        if elapsed > 0.001 {
            let old = tracks[index].rect, velocity = tracks[index].velocity
            func blend(_ new: Double, _ previous: Double, _ oldVelocity: Double) -> Double {
                0.5 * oldVelocity + 0.5 * (new - previous) / elapsed
            }
            tracks[index].velocity = NormalizedRect(
                x: blend(rect.x, old.x, velocity.x), y: blend(rect.y, old.y, velocity.y),
                width: blend(rect.width, old.width, velocity.width),
                height: blend(rect.height, old.height, velocity.height)
            )
            tracks[index].rect = rect
            tracks[index].lastSeen = time
        }
    }
}
