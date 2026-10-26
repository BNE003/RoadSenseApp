//
//  RouteBreadcrumb.swift
//  RoadSense
//

import Foundation

/// Keeps one point per `minimumMeters` or `minimumSeconds` instead of every GPS fix, so a drive's
/// route stays small enough to store on the drive itself.
nonisolated struct RouteBreadcrumb: Sendable {
    let minimumMeters: Double
    let minimumSeconds: Double

    private(set) var points: [Coordinate] = []
    private var lastTime: Date?

    init(minimumMeters: Double = 20, minimumSeconds: Double = 5) {
        self.minimumMeters = minimumMeters
        self.minimumSeconds = minimumSeconds
    }

    mutating func append(_ coordinate: Coordinate, at time: Date) {
        if let last = points.last, let lastTime {
            let moved = last.distance(to: coordinate)
            let elapsed = time.timeIntervalSince(lastTime)
            // Standing still adds nothing, however long it takes.
            guard moved >= minimumMeters || (elapsed >= minimumSeconds && moved >= 3) else { return }
        }
        points.append(coordinate)
        lastTime = time
    }
}
