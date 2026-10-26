//
//  LocationAuthorizer.swift
//  RoadSense
//

import CoreLocation

/// Wraps `CLLocationManager`'s authorization callbacks. Lives on the main actor because the
/// manager delivers its delegate calls on the thread it was created on.
@MainActor
final class LocationAuthorizer: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var onChange: ((LocationAuthorization) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    var current: LocationAuthorization { Self.map(manager.authorizationStatus) }

    /// Calls `handler` now and on every later change.
    func observe(_ handler: @escaping (LocationAuthorization) -> Void) {
        onChange = handler
        handler(current)
    }

    func stop() {
        onChange = nil
    }

    /// Asks for When-In-Use access if undecided and returns the outcome.
    static func requestWhenInUse() async -> LocationAuthorization {
        let authorizer = LocationAuthorizer()
        guard authorizer.current == .notDetermined else { return authorizer.current }
        return await withCheckedContinuation { continuation in
            var finished = false
            authorizer.observe { value in
                guard value != .notDetermined, !finished else { return }
                finished = true
                continuation.resume(returning: value)
            }
            authorizer.manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onChange?(Self.map(manager.authorizationStatus))
    }

    private static func map(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .authorized
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }
}
