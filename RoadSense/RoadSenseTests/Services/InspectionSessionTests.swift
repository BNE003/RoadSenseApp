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
    private let fixedNow = Date(timeIntervalSince1970: 1_000_000)

    private func makeSession(
        camera: FakeCamera? = nil,
        detections: @escaping @Sendable (TimeInterval) -> [RawDetection] = { _ in [] }
    ) -> InspectionSession {
        let now = fixedNow
        return InspectionSession(
            camera: camera ?? self.camera,
            detection: FakeDetection(detections: detections),
            location: location,
            settings: settings,
            clock: clock,
            now: { now }
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

        location.send(.at(latitude: 52.5))
        camera.send(CameraFrame(timestamp: 1))
        #expect(await eventually { recorder.latest.distanceMeters == 0 && recorder.latest.elapsedSeconds == 0 })
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
}
