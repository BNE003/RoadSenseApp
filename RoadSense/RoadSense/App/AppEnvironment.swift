//
//  AppEnvironment.swift
//  RoadSense
//

import Foundation
import SwiftData
import os

/// The app's services, created once at launch and passed down by initializer.
struct AppEnvironment {
    var location: any LocationService
    var camera: any CameraService
    var detection: any DetectionService
    var drives: any DriveRepository
    var alerts: any AlertService
    var settings: any SettingsStore
    var sync: any SyncService
    /// Whether GPS speed may start an inspection on its own. Off for mocks, whose route always moves.
    var watchesMovement = false
    var clock: any Clock<Duration>
    var now: @Sendable () -> Date

    /// A new inspection session wired to this environment's services.
    func makeInspectionSession() -> InspectionSession {
        InspectionSession(
            camera: camera, detection: detection, location: location, drives: drives,
            alerts: alerts, settings: settings, clock: clock, now: now
        )
    }

    /// The real camera, model, GPS and on-device store. Throws if the model or the store cannot be
    /// opened; the app then cannot record safely and says so instead of falling back to mocks.
    static func live(
        clock: any Clock<Duration> = ContinuousClock(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) throws -> AppEnvironment {
        AppEnvironment(
            location: LiveLocationService(),
            camera: LiveCameraService(),
            detection: try LiveDetectionService(),
            drives: SwiftDataDriveRepository(modelContainer: try .roadSense()),
            alerts: LiveAlertService(),
            settings: UserDefaultsSettingsStore(),
            sync: NoopSyncService(),
            watchesMovement: true,
            clock: clock,
            now: now
        )
    }

    /// Finishes drives a crash or kill left in progress, so they show up in History.
    func recoverUnfinishedDrives() async {
        do {
            let count = try await drives.recoverUnfinishedDrives()
            if count > 0 {
                Logger(subsystem: "b.held.RoadSense", category: "persistence").info("Recovered \(count) drives")
            }
        } catch {
            Logger(subsystem: "b.held.RoadSense", category: "persistence")
                .error("Recovery failed: \(error.localizedDescription, privacy: .public)")
        }
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
            alerts: NoopAlertService(),
            settings: settings ?? UserDefaultsSettingsStore(),
            sync: NoopSyncService(),
            clock: clock,
            now: now
        )
    }
}
