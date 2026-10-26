//
//  AppEnvironment.swift
//  RoadSense
//

import Foundation

/// The app's services, created once at launch and passed down by initializer.
struct AppEnvironment {
    var location: any LocationService
    var camera: any CameraService
    var detection: any DetectionService
    var drives: any DriveRepository
    var settings: any SettingsStore
    var sync: any SyncService
    var clock: any Clock<Duration>
    var now: @Sendable () -> Date

    /// A new inspection session wired to this environment's services.
    func makeInspectionSession() -> InspectionSession {
        InspectionSession(
            camera: camera, detection: detection, location: location,
            settings: settings, clock: clock, now: now
        )
    }

    /// Everything simulated: Milestone 1's configuration, also used for previews.
    static func mock(
        cameraAuthorization: CameraAuthorization = .authorized,
        settings: (any SettingsStore)? = nil,
        clock: any Clock<Duration> = ContinuousClock(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> AppEnvironment {
        AppEnvironment(
            location: MockLocationService(clock: clock, now: now),
            camera: MockCameraService(authorization: cameraAuthorization, clock: clock),
            detection: MockDetectionService(),
            drives: SampleData.repository(now: now()),
            settings: settings ?? UserDefaultsSettingsStore(),
            sync: NoopSyncService(),
            clock: clock,
            now: now
        )
    }
}
