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
    private let now: @Sendable () -> Date

    private(set) var recent: [DriveSummary] = []
    private(set) var isLoaded = false
    private(set) var loadError: String?
    private(set) var gpsStatus: GPSStatus = .searching

    init(environment: AppEnvironment) {
        drives = environment.drives
        location = environment.location
        settings = environment.settings
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
}
