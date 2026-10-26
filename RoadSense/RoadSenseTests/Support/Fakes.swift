//
//  Fakes.swift
//  RoadSenseTests
//

import Foundation
@testable import RoadSense

/// Polls until `condition` holds or two seconds pass. Waits for state, never for a fixed time.
@MainActor
func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<2000 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return condition()
}

struct FakeCamera: CameraService {
    var authorization: CameraAuthorization = .authorized
    private let stream = AsyncThrowingStream<CameraFrame, any Error>.makeStream()

    func requestAuthorization() async -> CameraAuthorization { authorization }
    func frames() -> AsyncThrowingStream<CameraFrame, any Error> { stream.stream }
    func send(_ frame: CameraFrame) { stream.continuation.yield(frame) }
    func fail(_ error: any Error) { stream.continuation.finish(throwing: error) }
}

struct FakeLocation: LocationService {
    private let stream = AsyncThrowingStream<LocationSample, any Error>.makeStream()

    func authorizationUpdates() -> AsyncStream<LocationAuthorization> {
        AsyncStream { $0.yield(.authorized); $0.finish() }
    }
    func requestAuthorization() async -> LocationAuthorization { .authorized }
    func samples() -> AsyncThrowingStream<LocationSample, any Error> { stream.stream }
    func send(_ sample: LocationSample) { stream.continuation.yield(sample) }
}

/// Reports the detections it is given for each frame timestamp.
struct FakeDetection: DetectionService {
    var supportedKinds: Set<IssueKind> = Set(IssueKind.allCases)
    var detections: @Sendable (TimeInterval) -> [RawDetection]

    func prepare() async throws {}
    func detect(in frame: CameraFrame, mountHeight: MountHeight) async throws -> [RawDetection] {
        detections(frame.timestamp)
    }
}

@MainActor
final class InMemorySettings: SettingsStore {
    var vehicleName = "Test vehicle"
    var mountHeight: MountHeight = .standard
    var autoStart = true
    var alertSounds = true
    var wifiOnlyUpload = false
}

extension RawDetection {
    static func pothole(x: Double = 0.4, y: Double = 0.5) -> RawDetection {
        RawDetection(kind: .pothole, confidence: 0.9, rect: NormalizedRect(x: x, y: y, width: 0.2, height: 0.1))
    }
}

extension LocationSample {
    static func at(latitude: Double, longitude: Double = 13.4, accuracy: Double = 5, speed: Double = 10) -> LocationSample {
        LocationSample(
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            horizontalAccuracy: accuracy, speed: speed, timestamp: Date(timeIntervalSince1970: 0)
        )
    }
}
