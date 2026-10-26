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
    private let drives: any DriveRepository
    private let alerts: any AlertService
    private let settings: any SettingsStore
    private let clock: any Clock<Duration>
    private let now: @Sendable () -> Date
    private let thermalState: @Sendable () -> ProcessInfo.ThermalState
    private let logger = Logger(subsystem: "b.held.RoadSense", category: "inspection")

    /// Fixes older than this many seconds are not used to place an issue.
    private let maxLocationAge = 5
    /// The running totals of the stored drive are refreshed this often.
    private let checkpointInterval = 10

    private var snapshot = InspectionSnapshot()
    private var issues: [DetectedIssue] = []
    private var deduplicator = IssueDeduplicator()
    private var lastSample: LocationSample?
    private var lastSampleAt = 0
    private var distanceMeters = 0.0
    private var breadcrumb = RouteBreadcrumb()
    private var lastInference = -TimeInterval.infinity
    private var driveID = UUID()
    private var startedAt = Date()
    private var failure: (any Error)?

    init(
        camera: any CameraService,
        detection: any DetectionService,
        location: any LocationService,
        drives: any DriveRepository,
        alerts: any AlertService,
        settings: any SettingsStore,
        clock: any Clock<Duration>,
        now: @escaping @Sendable () -> Date,
        thermalState: @escaping @Sendable () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState }
    ) {
        self.camera = camera
        self.detection = detection
        self.location = location
        self.drives = drives
        self.alerts = alerts
        self.settings = settings
        self.clock = clock
        self.now = now
        self.thermalState = thermalState
    }

    /// Records until the surrounding task is cancelled, then returns the finished drive.
    /// Throws if the inspection cannot start (permission denied, model failed to load).
    func run(onUpdate: @escaping @MainActor (InspectionSnapshot) -> Void) async throws -> Drive {
        try await detection.prepare()
        guard await camera.requestAuthorization() == .authorized else { throw CameraError.accessDenied }
        // Location is optional: without a fix issues are stored without coordinates.
        _ = await location.requestAuthorization()

        driveID = UUID()
        startedAt = now()
        let mountHeight = settings.mountHeight
        reset()
        // Stored before the first frame, so a crash at any moment leaves a recoverable drive.
        do {
            try await drives.save(currentDrive(status: .inProgress))
        } catch {
            logger.error("Could not store the new drive: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        onUpdate(snapshot)

        let frames = camera.frames()
        let samples = location.samples()

        // The camera pipeline is essential; the clock and location are not. When the pipeline ends
        // (cancellation or camera failure) the other two are cancelled and awaited.
        let clockTask = Task { await self.tick(onUpdate) }
        let locationTask = Task { await self.consume(samples, onUpdate) }
        await withTaskCancellationHandler {
            await process(frames, mountHeight: mountHeight, onUpdate)
        } onCancel: {
            clockTask.cancel()
            locationTask.cancel()
        }
        clockTask.cancel()
        locationTask.cancel()
        await clockTask.value
        await locationTask.value

        if let failure, issues.isEmpty {
            await discardStoredDrive()
            throw failure
        }
        // The full drive, so an issue whose incremental write failed is stored too. It stays
        // in progress until the summary saves it; a quit before that is recovered at next launch.
        await store(currentDrive(status: .inProgress))
        return currentDrive(status: .finished)
    }

    // MARK: - Pipeline

    private func reset() {
        snapshot = InspectionSnapshot()
        issues = []
        deduplicator = IssueDeduplicator()
        lastSample = nil
        lastSampleAt = 0
        distanceMeters = 0
        breadcrumb = RouteBreadcrumb()
        lastInference = -.infinity
        failure = nil
    }

    private func currentDrive(status: DriveStatus) -> Drive {
        Drive(
            id: driveID,
            name: Drive.defaultName(for: startedAt),
            startedAt: startedAt,
            endedAt: now(),
            distanceMeters: distanceMeters,
            issues: issues,
            status: status,
            route: breadcrumb.points
        )
    }

    private func store(_ drive: Drive) async {
        do {
            try await drives.save(drive)
        } catch {
            // The drive is still returned to the summary, whose Save tries again.
            logger.error("Could not store the drive: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func discardStoredDrive() async {
        do {
            try await drives.delete(driveID: driveID)
        } catch {
            logger.error("Could not remove the empty drive: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func tick(_ onUpdate: @MainActor (InspectionSnapshot) -> Void) async {
        while !Task.isCancelled {
            do { try await clock.sleep(for: .seconds(1)) } catch { return }
            snapshot.elapsedSeconds += 1
            onUpdate(snapshot)
            if snapshot.elapsedSeconds.isMultiple(of: checkpointInterval) { await checkpoint() }
        }
    }

    private func checkpoint() async {
        do {
            try await drives.checkpoint(
                driveID: driveID, endedAt: now(), distanceMeters: distanceMeters, route: breadcrumb.points
            )
        } catch {
            logger.error("Checkpoint failed: \(error.localizedDescription, privacy: .public)")
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
                breadcrumb.append(sample.coordinate, at: sample.timestamp)
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
        mountHeight: MountHeight,
        _ onUpdate: @MainActor (InspectionSnapshot) -> Void
    ) async {
        do {
            for try await frame in frames {
                // A hot phone runs the model less often; skipped frames are simply dropped.
                guard frame.timestamp - lastInference >= InferenceThrottle.interval(for: thermalState()) else {
                    continue
                }
                lastInference = frame.timestamp
                let detections = try await detection.detect(in: frame, mountHeight: mountHeight)
                snapshot.boxes = detections.map { LiveBox(kind: $0.kind, rect: $0.rect) }
                for new in deduplicator.ingest(detections, at: frame.timestamp) {
                    let issue = makeIssue(from: new)
                    issues.append(issue)
                    snapshot.counts[issue.kind, default: 0] += 1
                    if settings.alertSounds { alerts.playDetectionAlert() }
                    await save(issue)
                }
                onUpdate(snapshot)
            }
        } catch {
            logger.error("Camera pipeline failed: \(error.localizedDescription, privacy: .public)")
            failure = error
        }
    }

    private func save(_ issue: DetectedIssue) async {
        do {
            try await drives.append(issue)
        } catch {
            // Kept in memory and written with the whole drive at the end.
            logger.error("Could not store an issue: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func makeIssue(from detection: RawDetection) -> DetectedIssue {
        let fix = snapshot.elapsedSeconds - lastSampleAt <= maxLocationAge ? lastSample : nil
        return DetectedIssue(
            id: UUID(),
            driveID: driveID,
            kind: detection.kind,
            confidence: detection.confidence,
            detectedAt: now(),
            coordinate: fix?.coordinate,
            horizontalAccuracy: fix?.horizontalAccuracy,
            speed: fix.flatMap { $0.speed >= 0 ? $0.speed : nil },
            heading: fix.flatMap { $0.course >= 0 ? $0.course : nil },
            place: nil,
            note: nil
        )
    }
}
