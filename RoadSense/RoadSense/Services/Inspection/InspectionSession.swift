//
//  InspectionSession.swift
//  RoadSense
//

import Foundation
import os

/// A box currently shown over the camera feed.
nonisolated struct LiveBox: Hashable, Sendable {
    var kind: IssueKind
    var rect: NormalizedRect
}

/// What the live screen shows.
nonisolated struct InspectionSnapshot: Equatable, Sendable {
    var elapsedSeconds = 0
    var distanceMeters = 0.0
    var counts: [IssueKind: Int] = [:]
    var boxes: [LiveBox] = []
}

/// Runs one inspection: joins camera frames, detections and GPS into a `Drive`.
///
/// `run` returns when its task is cancelled. Everything here runs on the main actor; the services
/// do their heavy work elsewhere and hand back small values.
@MainActor
final class InspectionSession {
    private let camera: any CameraService
    private let detection: any DetectionService
    private let location: any LocationService
    private let settings: any SettingsStore
    private let clock: any Clock<Duration>
    private let now: @Sendable () -> Date
    private let logger = Logger(subsystem: "b.held.RoadSense", category: "inspection")

    /// Fixes older than this many seconds are not used to place an issue.
    private let maxLocationAge = 5

    private var snapshot = InspectionSnapshot()
    private var issues: [DetectedIssue] = []
    private var deduplicator = IssueDeduplicator()
    private var lastSample: LocationSample?
    private var lastSampleAt = 0
    private var distanceMeters = 0.0
    private var failure: (any Error)?

    init(
        camera: any CameraService,
        detection: any DetectionService,
        location: any LocationService,
        settings: any SettingsStore,
        clock: any Clock<Duration>,
        now: @escaping @Sendable () -> Date
    ) {
        self.camera = camera
        self.detection = detection
        self.location = location
        self.settings = settings
        self.clock = clock
        self.now = now
    }

    /// Records until the surrounding task is cancelled, then returns the finished drive.
    /// Throws if the inspection cannot start (permission denied, model failed to load).
    func run(onUpdate: @escaping @MainActor (InspectionSnapshot) -> Void) async throws -> Drive {
        try await detection.prepare()
        guard await camera.requestAuthorization() == .authorized else { throw CameraError.accessDenied }
        // Location is optional: without a fix issues are stored without coordinates.
        _ = await location.requestAuthorization()

        let driveID = UUID()
        let startedAt = now()
        let mountHeight = settings.mountHeight
        reset()
        onUpdate(snapshot)

        let frames = camera.frames()
        let samples = location.samples()

        // The camera pipeline is essential; the clock and location are not. When the pipeline ends
        // (cancellation or camera failure) the other two are cancelled and awaited.
        let clockTask = Task { await self.tick(onUpdate) }
        let locationTask = Task { await self.consume(samples, onUpdate) }
        await withTaskCancellationHandler {
            await process(frames, driveID: driveID, mountHeight: mountHeight, onUpdate)
        } onCancel: {
            clockTask.cancel()
            locationTask.cancel()
        }
        clockTask.cancel()
        locationTask.cancel()
        await clockTask.value
        await locationTask.value

        if let failure, issues.isEmpty { throw failure }
        let endedAt = now()
        return Drive(
            id: driveID,
            name: Drive.defaultName(for: startedAt),
            startedAt: startedAt,
            endedAt: endedAt,
            distanceMeters: distanceMeters,
            issues: issues
        )
    }

    // MARK: - Pipeline

    private func reset() {
        snapshot = InspectionSnapshot()
        issues = []
        deduplicator = IssueDeduplicator()
        lastSample = nil
        lastSampleAt = 0
        distanceMeters = 0
        failure = nil
    }

    private func tick(_ onUpdate: @MainActor (InspectionSnapshot) -> Void) async {
        while !Task.isCancelled {
            do { try await clock.sleep(for: .seconds(1)) } catch { return }
            snapshot.elapsedSeconds += 1
            onUpdate(snapshot)
        }
    }

    private func consume(
        _ samples: AsyncThrowingStream<LocationSample, any Error>,
        _ onUpdate: @MainActor (InspectionSnapshot) -> Void
    ) async {
        do {
            for try await sample in samples {
                guard sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= 50 else { continue }
                if let previous = lastSample {
                    let step = previous.coordinate.distance(to: sample.coordinate)
                    // Ignore GPS jitter while standing still.
                    if step >= 3 || sample.speed >= 1 { distanceMeters += step }
                }
                lastSample = sample
                lastSampleAt = snapshot.elapsedSeconds
                snapshot.distanceMeters = distanceMeters
                onUpdate(snapshot)
            }
        } catch {
            // Degraded, not fatal: keep recording without positions.
            logger.error("Location stream failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func process(
        _ frames: AsyncThrowingStream<CameraFrame, any Error>,
        driveID: UUID,
        mountHeight: MountHeight,
        _ onUpdate: @MainActor (InspectionSnapshot) -> Void
    ) async {
        do {
            for try await frame in frames {
                let detections = try await detection.detect(in: frame, mountHeight: mountHeight)
                snapshot.boxes = detections.map { LiveBox(kind: $0.kind, rect: $0.rect) }
                for new in deduplicator.ingest(detections) {
                    let issue = makeIssue(from: new, driveID: driveID)
                    issues.append(issue)
                    snapshot.counts[issue.kind, default: 0] += 1
                }
                onUpdate(snapshot)
            }
        } catch {
            logger.error("Camera pipeline failed: \(error.localizedDescription, privacy: .public)")
            failure = error
        }
    }

    private func makeIssue(from detection: RawDetection, driveID: UUID) -> DetectedIssue {
        let hasFix = lastSample != nil && snapshot.elapsedSeconds - lastSampleAt <= maxLocationAge
        return DetectedIssue(
            id: UUID(),
            driveID: driveID,
            kind: detection.kind,
            confidence: detection.confidence,
            detectedAt: now(),
            coordinate: hasFix ? lastSample?.coordinate : nil,
            place: nil,
            note: nil
        )
    }
}
