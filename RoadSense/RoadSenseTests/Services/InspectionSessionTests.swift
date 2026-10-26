//
//  InspectionSessionTests.swift
//  RoadSenseTests
//

import Foundation
import Testing
@testable import RoadSense

@MainActor
struct InspectionSessionTests {
    private let camera = FakeCamera()
    private let location = FakeLocation()
    private let clock = ManualClock()
    private let settings = InMemorySettings()
    private let drives = InMemoryDriveRepository()
    private let alerts = RecordingAlerts()
    private let fixedNow = Date(timeIntervalSince1970: 1_000_000)

    private func makeSession(
        camera: FakeCamera? = nil,
        detections: @escaping @Sendable (TimeInterval) -> [RawDetection] = { _ in [] },
        thermalState: @escaping @Sendable () -> ProcessInfo.ThermalState = { .nominal }
    ) -> InspectionSession {
        let now = fixedNow
        return InspectionSession(
            camera: camera ?? self.camera,
            detection: FakeDetection(detections: detections),
            location: location,
            drives: drives,
            alerts: alerts,
            settings: settings,
            clock: clock,
            now: { now },
            thermalState: thermalState
        )
    }

    private final class Recorder {
        var latest = InspectionSnapshot()
    }

    private func start(_ session: InspectionSession, recorder: Recorder) -> Task<Drive, any Error> {
        Task { try await session.run { recorder.latest = $0 } }
    }

    @Test func aSightingOverSeveralFramesIsCountedOnce() async throws {
        let session = makeSession { $0 <= 3 ? [.pothole()] : [] }
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        for second in 1...5 { camera.send(CameraFrame(timestamp: Double(second))) }
        #expect(await eventually { recorder.latest.counts[.pothole] == 1 })
        #expect(await eventually { recorder.latest.boxes.isEmpty })

        task.cancel()
        let drive = try await task.value
        #expect(drive.issues.count == 1)
        #expect(drive.summary.count(of: .pothole) == 1)
    }

    @Test func issuesGetTheLatestLocation() async throws {
        let session = makeSession { $0 == 2 ? [.pothole()] : [] }
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        // Two fixes, so the moved distance shows that both were consumed before the frame arrives.
        location.send(.at(latitude: 52.4999))
        location.send(.at(latitude: 52.5))
        #expect(await eventually { recorder.latest.distanceMeters > 5 })
        camera.send(CameraFrame(timestamp: 2))
        #expect(await eventually { recorder.latest.counts[.pothole] == 1 })

        task.cancel()
        let drive = try await task.value
        #expect(drive.issues.first?.coordinate?.latitude == 52.5)
        #expect(drive.issues.first?.driveID == drive.id)
        #expect(drive.issues.first?.detectedAt == fixedNow)
    }

    @Test func issuesWithoutALocationFixHaveNoCoordinate() async throws {
        let session = makeSession { _ in [.pothole()] }
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        camera.send(CameraFrame(timestamp: 1))
        #expect(await eventually { recorder.latest.counts[.pothole] == 1 })
        task.cancel()
        let drive = try await task.value
        #expect(drive.issues.first?.coordinate == nil)
    }

    @Test func distanceAddsUpAcceptedFixes() async throws {
        let session = makeSession()
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        location.send(.at(latitude: 52.000))
        location.send(.at(latitude: 52.001))                    // about 111 m
        location.send(.at(latitude: 52.002, accuracy: 500))     // too inaccurate: ignored
        location.send(.at(latitude: 52.002))                    // 111 m from the last accepted fix
        #expect(await eventually { recorder.latest.distanceMeters > 200 })

        task.cancel()
        let drive = try await task.value
        #expect(abs(drive.distanceMeters - 222) < 3)
    }

    @Test func jitterWhileStandingStillIsIgnored() async throws {
        let session = makeSession()
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        location.send(.at(latitude: 52.0, speed: 0))
        location.send(.at(latitude: 52.00001, speed: 0))        // about 1 m
        location.send(.at(latitude: 52.0, speed: 0))
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        let drive = try await task.value
        #expect(drive.distanceMeters == 0)
    }

    @Test func elapsedTimeFollowsTheClock() async throws {
        let session = makeSession()
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        #expect(await eventually { clock.sleeperCount >= 1 })
        for _ in 1...3 {
            await clock.advance(by: .seconds(1))
            #expect(await eventually { clock.sleeperCount >= 1 })
        }
        #expect(await eventually { recorder.latest.elapsedSeconds == 3 })
        task.cancel()
        _ = try await task.value
    }

    @Test func deniedCameraPermissionThrows() async {
        var denied = FakeCamera()
        denied.authorization = .denied
        let session = makeSession(camera: denied)
        await #expect(throws: CameraError.self) { try await session.run { _ in } }
    }

    @Test func aCameraFailureEndsTheSession() async throws {
        let session = makeSession { _ in [.pothole()] }
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        camera.send(CameraFrame(timestamp: 1))
        #expect(await eventually { recorder.latest.counts[.pothole] == 1 })
        camera.fail(CameraError.unavailable)
        let drive = try await task.value      // returns without cancelling: the data so far is kept
        #expect(drive.issues.count == 1)
    }

    // MARK: - Persistence while recording

    @Test func theDriveIsStoredWhileRecordingAndRecoveredAfterACrash() async throws {
        let session = makeSession { _ in [.pothole()] }
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        camera.send(CameraFrame(timestamp: 1))
        #expect(await eventually { recorder.latest.counts[.pothole] == 1 })
        #expect(try await drives.driveSummaries(limit: nil).isEmpty)    // in progress: not listed yet

        // The app is killed here: nobody ever calls `save` for a finished drive.
        #expect(try await drives.recoverUnfinishedDrives() == 1)
        let summaries = try await drives.driveSummaries(limit: nil)
        #expect(summaries.count == 1)
        #expect(summaries.first?.count(of: .pothole) == 1)
        task.cancel()
        _ = try await task.value
    }

    @Test func aFailedStartLeavesNothingBehind() async throws {
        let session = makeSession()
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        camera.fail(CameraError.unavailable)
        await #expect(throws: CameraError.self) { try await task.value }
        #expect(try await drives.recoverUnfinishedDrives() == 0)
    }

    @Test func theReturnedDriveIsFinishedAndKeepsTheRoute() async throws {
        let session = makeSession()
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        location.send(.at(latitude: 52.000))
        location.send(.at(latitude: 52.001))
        #expect(await eventually { recorder.latest.distanceMeters > 100 })
        task.cancel()
        let drive = try await task.value
        #expect(drive.status == .finished)
        #expect(drive.route.count == 2)
    }

    // MARK: - Alerts and throttling

    @Test func eachNewIssueSoundsOneAlert() async throws {
        let session = makeSession { $0 <= 3 ? [.pothole()] : [] }
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        for second in 1...4 { camera.send(CameraFrame(timestamp: Double(second))) }
        #expect(await eventually { recorder.latest.boxes.isEmpty && recorder.latest.counts[.pothole] == 1 })
        task.cancel()
        _ = try await task.value
        #expect(alerts.count == 1)
    }

    @Test func alertsStaySilentWhenSwitchedOff() async throws {
        settings.alertSounds = false
        let session = makeSession { _ in [.pothole()] }
        let recorder = Recorder()
        let task = start(session, recorder: recorder)

        camera.send(CameraFrame(timestamp: 1))
        #expect(await eventually { recorder.latest.counts[.pothole] == 1 })
        task.cancel()
        _ = try await task.value
        #expect(alerts.count == 0)
    }

    /// Frames at 1.0, 1.05, 1.2 and 1.7 s; the detector reports a pothole at a different place on
    /// the third and fourth frame.
    private func issuesFound(thermalState: ProcessInfo.ThermalState) async throws -> Int {
        let session = makeSession(detections: { time in
            switch time {
            case 1.2: [.pothole(x: 0.5)]
            case 1.7: [.pothole(x: 0.8)]
            default: [.pothole(x: 0.0)]
            }
        }, thermalState: { thermalState })
        let recorder = Recorder()
        let task = start(session, recorder: recorder)
        for time in [1.0, 1.05, 1.2, 1.7] { camera.send(CameraFrame(timestamp: time)) }
        // The last frame is processed at either temperature, so it marks the end.
        #expect(await eventually { recorder.latest.boxes.first?.rect.x == 0.8 })
        task.cancel()
        return try await task.value.issues.count
    }

    @Test func aNormalPhoneRunsTheModelOnEveryFrameInTime() async throws {
        #expect(try await issuesFound(thermalState: .nominal) == 3)
    }

    @Test func aHotPhoneSkipsFramesToCoolDown() async throws {
        #expect(try await issuesFound(thermalState: .serious) == 2)
    }
}
