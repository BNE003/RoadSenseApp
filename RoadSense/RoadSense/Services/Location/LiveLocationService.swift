//
//  LiveLocationService.swift
//  RoadSense
//

import CoreLocation
import Foundation
import os

/// GPS through `CLLocationUpdate.liveUpdates`, with When-In-Use access only: the screen stays on
/// while the phone is mounted, so background location is not needed.
nonisolated struct LiveLocationService: LocationService {
    private static let logger = Logger(subsystem: "b.held.RoadSense", category: "location")

    /// Fixes that are already this old when delivered are dropped.
    var maxFixAge: TimeInterval = 10

    func authorizationUpdates() -> AsyncStream<LocationAuthorization> {
        AsyncStream { continuation in
            Task { @MainActor in
                let authorizer = LocationAuthorizer()
                authorizer.observe { continuation.yield($0) }
                continuation.onTermination = { _ in
                    Task { @MainActor in authorizer.stop() }
                }
            }
        }
    }

    func requestAuthorization() async -> LocationAuthorization {
        await LocationAuthorizer.requestWhenInUse()
    }

    func samples() -> AsyncThrowingStream<LocationSample, any Error> {
        let maxFixAge = maxFixAge
        return AsyncThrowingStream { continuation in
            let task = Task {
                // The session tells the system this code needs When-In-Use access while it lives.
                let session = CLServiceSession(authorization: .whenInUse)
                defer { session.invalidate() }
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                        if update.authorizationDenied || update.authorizationDeniedGlobally {
                            throw LocationError.accessDenied
                        }
                        guard let location = update.location,
                              location.horizontalAccuracy >= 0,
                              -location.timestamp.timeIntervalSinceNow <= maxFixAge
                        else { continue }
                        continuation.yield(LocationSample(
                            coordinate: Coordinate(
                                latitude: location.coordinate.latitude, longitude: location.coordinate.longitude
                            ),
                            horizontalAccuracy: location.horizontalAccuracy,
                            speed: location.speed, course: location.course, timestamp: location.timestamp
                        ))
                    }
                    continuation.finish()
                } catch {
                    Self.logger.error("Location updates ended: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
