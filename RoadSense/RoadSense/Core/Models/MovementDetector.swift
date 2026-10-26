//
//  MovementDetector.swift
//  RoadSense
//

import Foundation

/// Decides from GPS speed when the vehicle has started driving, for auto-start.
///
/// It fires once, after `requiredSamples` fast samples in a row, and fires again only after the
/// vehicle has slowed down, so ending an inspection while still moving does not restart it.
nonisolated struct MovementDetector: Sendable {
    /// Meters per second; about 14 km/h, above walking and cycling noise.
    var startSpeed = 4.0
    /// Below this the detector arms again.
    var restSpeed = 1.5
    var requiredSamples = 3

    private var fastSamples = 0
    private var isArmed = true

    init(startSpeed: Double = 4, restSpeed: Double = 1.5, requiredSamples: Int = 3) {
        self.startSpeed = startSpeed
        self.restSpeed = restSpeed
        self.requiredSamples = requiredSamples
    }

    /// Returns `true` when this sample completes a start of movement.
    mutating func ingest(speed: Double) -> Bool {
        guard speed >= 0 else { return false }
        if speed < restSpeed {
            isArmed = true
            fastSamples = 0
            return false
        }
        guard isArmed, speed >= startSpeed else {
            fastSamples = 0
            return false
        }
        fastSamples += 1
        guard fastSamples >= requiredSamples else { return false }
        isArmed = false
        fastSamples = 0
        return true
    }
}
