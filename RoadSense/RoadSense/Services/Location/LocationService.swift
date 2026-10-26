//
//  LocationService.swift
//  RoadSense
//

import Foundation

nonisolated enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

nonisolated struct LocationSample: Sendable, Equatable {
    var coordinate: Coordinate
    /// Horizontal accuracy in meters; negative means invalid.
    var horizontalAccuracy: Double
    /// Speed in meters per second; negative means unknown.
    var speed: Double
    var timestamp: Date
}

nonisolated protocol LocationService: Sendable {
    func authorizationUpdates() -> AsyncStream<LocationAuthorization>
    func requestAuthorization() async -> LocationAuthorization
    /// Position fixes until the consuming task is cancelled.
    func samples() -> AsyncThrowingStream<LocationSample, any Error>
}
