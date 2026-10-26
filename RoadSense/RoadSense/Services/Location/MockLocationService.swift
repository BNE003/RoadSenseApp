//
//  MockLocationService.swift
//  RoadSense
//

import Foundation

/// Drives straight north at a constant speed, one fix per second.
nonisolated struct MockLocationService: LocationService {
    var authorization: LocationAuthorization = .authorized
    var start = MapViewport.demo.coordinate(x: 0.5, y: 0.95)
    /// 40 km/h, the speed the design's live counters assume.
    var speed = 40.0 / 3.6
    var clock: any Clock<Duration> = ContinuousClock()
    var now: @Sendable () -> Date = { Date() }

    func authorizationUpdates() -> AsyncStream<LocationAuthorization> {
        let value = authorization
        return AsyncStream { continuation in
            continuation.yield(value)
            continuation.finish()
        }
    }

    func requestAuthorization() async -> LocationAuthorization { authorization }

    func samples() -> AsyncThrowingStream<LocationSample, any Error> {
        let start = start, speed = speed, clock = clock, now = now
        return AsyncThrowingStream { continuation in
            let task = Task {
                var seconds = 0.0
                do {
                    while true {
                        try await clock.sleep(for: .seconds(1))
                        seconds += 1
                        let north = seconds * speed / 111_320
                        continuation.yield(LocationSample(
                            coordinate: Coordinate(latitude: start.latitude + north, longitude: start.longitude),
                            horizontalAccuracy: 5, speed: speed, timestamp: now()
                        ))
                    }
                } catch {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
