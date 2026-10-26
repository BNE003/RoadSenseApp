//
//  ViewModelTests.swift
//  RoadSenseTests
//

import Foundation
import Testing
@testable import RoadSense

@MainActor
struct HomeViewModelTests {
    @Test func loadsTheTwoMostRecentDrives() async {
        let viewModel = HomeViewModel(environment: .mock())
        await viewModel.load()
        #expect(viewModel.recent.map(\.name) == ["Commute, Nord–Süd", "Airport run"])
        #expect(viewModel.isLoaded)
    }

    @Test func emptyRepositoryLoadsEmpty() async {
        var environment = AppEnvironment.mock()
        environment.drives = InMemoryDriveRepository()
        let viewModel = HomeViewModel(environment: environment)
        await viewModel.load()
        #expect(viewModel.recent.isEmpty && viewModel.isLoaded && viewModel.loadError == nil)
    }

    @Test func repositoryFailureIsExposed() async {
        var environment = AppEnvironment.mock()
        environment.drives = InMemoryDriveRepository(failure: .loadFailed)
        let viewModel = HomeViewModel(environment: environment)
        await viewModel.load()
        #expect(viewModel.loadError != nil)
    }

    @Test func gpsStatusFollowsAuthorization() async {
        let viewModel = HomeViewModel(environment: .mock())
        await viewModel.observeGPS()
        #expect(viewModel.gpsStatus == .locked)
    }
}

@MainActor
struct HistoryViewModelTests {
    @Test func groupsDrivesByAge() async {
        let viewModel = HistoryViewModel(environment: .mock())
        await viewModel.load()
        let sections = viewModel.sections
        #expect(sections.map(\.drives.count) == [3, 2])
        #expect(sections.first?.drives.first?.name == "Commute, Nord–Süd")
    }

    @Test func subtitleUsesTotals() async {
        let viewModel = HistoryViewModel(environment: .mock())
        await viewModel.load()
        #expect(viewModel.subtitle.contains("23"))
        #expect(viewModel.subtitle.contains("412"))
    }

    @Test func emptyHistoryIsReported() async {
        var environment = AppEnvironment.mock()
        environment.drives = InMemoryDriveRepository()
        let viewModel = HistoryViewModel(environment: environment)
        await viewModel.load()
        #expect(viewModel.isEmpty && viewModel.sections.isEmpty)
    }
}

@MainActor
struct MapViewModelTests {
    @Test func showsAllSevenPinsAndSelectsTheFirst() async {
        let viewModel = MapViewModel(environment: .mock())
        await viewModel.load(focus: .all)
        #expect(viewModel.pins.count == 7)
        #expect(viewModel.selected?.place == "Rosenstrasse 14")
    }

    @Test func filterKeepsMatchingKindsAndSelectsTheFirstOfThem() async {
        let viewModel = MapViewModel(environment: .mock())
        await viewModel.load(focus: .all)
        viewModel.setFilter(.kind(.crack))
        #expect(viewModel.pins.count == 3)
        #expect(viewModel.pins.allSatisfy { $0.issue.kind == .crack })
        #expect(viewModel.selected?.kind == .crack)
    }

    @Test func driveFocusShowsOnlyThatDrive() async {
        let viewModel = MapViewModel(environment: .mock())
        await viewModel.load(focus: .drive(SampleData.id(2)))
        #expect(viewModel.pins.count == 2)
    }

    @Test func driveWithoutIssuesHasNoSelection() async {
        let viewModel = MapViewModel(environment: .mock())
        await viewModel.load(focus: .drive(SampleData.id(5)))
        #expect(viewModel.pins.isEmpty && viewModel.selected == nil && viewModel.isLoaded)
    }

    @Test func filtersFollowTheDetectorsSupportedKinds() {
        var environment = AppEnvironment.mock()
        environment.detection = MockDetectionService(supportedKinds: [.pothole])
        let viewModel = MapViewModel(environment: environment)
        #expect(viewModel.filters == [.all, .kind(.pothole)])
    }

    @Test func pinsOutsideTheViewportAreNotShown() async {
        let repository = InMemoryDriveRepository(issues: [
            DetectedIssue(id: UUID(), driveID: UUID(), kind: .pothole, confidence: 1, detectedAt: Date(),
                          coordinate: Coordinate(latitude: 0, longitude: 0), place: nil, note: nil),
        ])
        var environment = AppEnvironment.mock()
        environment.drives = repository
        let viewModel = MapViewModel(environment: environment)
        await viewModel.load(focus: .all)
        #expect(viewModel.pins.isEmpty)
    }
}

@MainActor
struct SummaryViewModelTests {
    @Test func breakdownListsSupportedKindsOnly() {
        var environment = AppEnvironment.mock()
        environment.detection = MockDetectionService(supportedKinds: [.pothole])
        let viewModel = SummaryViewModel(drive: .sample(), environment: environment)
        #expect(viewModel.breakdown.map(\.kind) == [.pothole])
    }

    @Test func totalsComeFromTheDrive() {
        let viewModel = SummaryViewModel(drive: .sample(), environment: .mock())
        #expect(viewModel.totalIssues == 11)
        #expect(viewModel.minutesText == "38")
        #expect(viewModel.breakdown.map(\.count) == [3, 7, 1])
    }

    @Test func savingStoresTheDriveOnce() async throws {
        let repository = InMemoryDriveRepository()
        var environment = AppEnvironment.mock()
        environment.drives = repository
        let viewModel = SummaryViewModel(drive: .sample(), environment: environment)
        #expect(!viewModel.isSaved)
        #expect(await viewModel.save())
        #expect(await viewModel.save())
        #expect(viewModel.isSaved)
        #expect(try await repository.driveSummaries(limit: nil).count == 1)
    }

    @Test func failedSaveReportsAnErrorAndCanBeRetried() async {
        var environment = AppEnvironment.mock()
        environment.drives = InMemoryDriveRepository(failure: .saveFailed)
        let viewModel = SummaryViewModel(drive: .sample(), environment: environment)
        #expect(await viewModel.save() == false)
        #expect(viewModel.errorText != nil && !viewModel.isSaved)
    }
}

@MainActor
struct SettingsViewModelTests {
    @Test func changesAreWrittenToTheStore() {
        let settings = InMemorySettings()
        var environment = AppEnvironment.mock()
        environment.settings = settings
        let viewModel = SettingsViewModel(environment: environment)
        viewModel.mountHeight = .high
        viewModel.wifiOnlyUpload = true
        #expect(settings.mountHeight == .high)
        #expect(settings.wifiOnlyUpload)
    }

    @Test func userDefaultsStorePersistsAcrossInstances() throws {
        let suite = "RoadSenseTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = UserDefaultsSettingsStore(defaults: defaults)
        #expect(first.mountHeight == .standard && first.autoStart && !first.wifiOnlyUpload)
        first.mountHeight = .low
        first.autoStart = false
        let second = UserDefaultsSettingsStore(defaults: defaults)
        #expect(second.mountHeight == .low && !second.autoStart)
    }
}

@MainActor
struct InspectionViewModelTests {
    @Test func countersFollowSupportedKinds() {
        var environment = AppEnvironment.mock()
        environment.detection = MockDetectionService(supportedKinds: [.pothole, .sign])
        let viewModel = InspectionViewModel(environment: environment)
        #expect(viewModel.counterKinds == [.pothole, .sign])
    }

    @Test func deniedCameraFailsWithAMessage() async {
        let viewModel = InspectionViewModel(environment: .mock(cameraAuthorization: .denied))
        viewModel.start()
        #expect(await eventually {
            if case .failed = viewModel.phase { true } else { false }
        })
    }

    @Test func endingAFreshInspectionFinishesWithADrive() async {
        let clock = ManualClock()
        let viewModel = InspectionViewModel(environment: .mock(clock: clock))
        viewModel.start()
        #expect(await eventually { clock.sleeperCount >= 1 })
        viewModel.end()
        #expect(await eventually {
            if case .finished = viewModel.phase { true } else { false }
        })
    }

    @Test func previewDriveStartsFinished() {
        let drive = Drive.sample()
        let viewModel = InspectionViewModel(environment: .mock(), finishedDrive: drive)
        #expect(viewModel.phase == .finished(drive))
    }
}
