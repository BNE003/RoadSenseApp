//
//  HomeViewModel.swift
//  RoadSense
//

import Foundation
import Observation

@MainActor @Observable
final class HomeViewModel {
    enum GPSStatus: Equatable {
        case locked, searching, denied
    }

    private let drives: any DriveRepository
    private let location: any LocationService
    private let settings: any SettingsStore
    private let watchesMovement: Bool
    private let now: @Sendable () -> Date

    private(set) var recent: [DriveSummary] = []
    private(set) var isLoaded = false
    private(set) var loadError: String?
    private(set) var gpsStatus: GPSStatus = .searching

    init(environment: AppEnvironment) {
        drives = environment.drives
        location = environment.location
        settings = environment.settings
        watchesMovement = environment.watchesMovement
        now = environment.now
    }

    var vehicleName: String { settings.vehicleName }

    /// "Mon 26. Oct"
    var dateText: String {
        now().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    func meta(for drive: DriveSummary) -> String {
        DriveFormatting.shortMeta(drive, now: now())
    }

    func load() async {
        do {
            recent = try await drives.driveSummaries(limit: 2)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        isLoaded = true
    }

    func observeGPS() async {
        for await authorization in location.authorizationUpdates() {
            switch authorization {
            case .authorized: gpsStatus = .locked
            case .denied: gpsStatus = .denied
            case .notDetermined: gpsStatus = .searching
            }
        }
    }

    /// Calls `onMovement` when the vehicle starts driving, if auto-start is on and location is
    /// already allowed. Never asks for permission itself; that happens when an inspection starts.
    func watchForMovement(onMovement: () -> Void) async {
        guard watchesMovement, settings.autoStart else { return }
        var current: LocationAuthorization = .notDetermined
        for await authorization in location.authorizationUpdates() {
            current = authorization
            break
        }
        guard current == .authorized else { return }
        var detector = MovementDetector()
        do {
            for try await sample in location.samples() where detector.ingest(speed: sample.speed) {
                onMovement()
            }
        } catch {
            // Auto-start is a convenience; without GPS the driver starts by hand.
        }
    }
}
