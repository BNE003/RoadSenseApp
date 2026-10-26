//
//  LiveCameraService.swift
//  RoadSense
//

@preconcurrency import AVFoundation
import Foundation
import os

/// The back camera, delivering 720p portrait frames.
///
/// Everything that touches the capture session runs on `queue`, as AVFoundation requires; callers
/// only ever see the `Sendable` stream and the preview handle.
nonisolated final class LiveCameraService: CameraService, @unchecked Sendable {
    // @unchecked: `session`, `output` and `restarts` are only touched on `queue`.
    private let queue = DispatchQueue(label: "b.held.RoadSense.camera")
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let frameSink = FrameSink()
    private let logger = Logger(subsystem: "b.held.RoadSense", category: "camera")
    private var isConfigured = false
    private var restarts = 0
    private let maxRestarts = 3

    let previewSource: CameraPreviewSource?
    /// Portrait 720 × 1280.
    let frameAspectRatio: Double? = 720.0 / 1280.0

    init() {
        previewSource = CameraPreviewSource(session: session)
    }

    func requestAuthorization() async -> CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    func frames() -> AsyncThrowingStream<CameraFrame, any Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            queue.async { [self] in
                do {
                    try configureIfNeeded()
                } catch {
                    continuation.finish(throwing: error)
                    return
                }
                frameSink.start(continuation)
                restarts = 0
                observeSessionEvents(continuation)
                session.startRunning()
                logger.info("Camera started")
            }
            continuation.onTermination = { [self] _ in
                queue.async { [self] in
                    frameSink.stop()
                    removeObservers()
                    session.stopRunning()
                    logger.info("Camera stopped")
                }
            }
        }
    }

    // MARK: - Configuration (queue only)

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device)
        else { throw CameraError.unavailable }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720
        guard session.canAddInput(input) else { throw CameraError.unavailable }
        session.addInput(input)

        // 32BGRA is what Core Image reads without a conversion step.
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(frameSink, queue: queue)
        guard session.canAddOutput(output) else { throw CameraError.unavailable }
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            // The road is far away; hunting for something close to the windshield is never wanted.
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .far }
            device.videoZoomFactor = 1
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            device.unlockForConfiguration()
        } catch {
            // Defaults still work; only the tuning is lost.
            logger.error("Camera tuning failed: \(error.localizedDescription, privacy: .public)")
        }
        isConfigured = true
    }

    // MARK: - Interruptions and errors (queue only)

    private var observers: [any NSObjectProtocol] = []

    private func observeSessionEvents(_ continuation: AsyncThrowingStream<CameraFrame, any Error>.Continuation) {
        removeObservers()
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { [self] _ in
            queue.async { [self] in
                // Media services can reset; try a bounded number of restarts, then give up loudly.
                restarts += 1
                if restarts <= maxRestarts {
                    logger.error("Camera runtime error, restart \(self.restarts)")
                    session.startRunning()
                } else {
                    continuation.finish(throwing: CameraError.unavailable)
                }
            }
        })
        observers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
        ) { [self] _ in
            queue.async { [self] in
                logger.info("Camera interruption ended")
                if !session.isRunning { session.startRunning() }
            }
        })
    }

    private func removeObservers() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }
}

/// Receives sample buffers on the camera queue and yields them as frames.
private nonisolated final class FrameSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    // @unchecked: `continuation` and `firstTimestamp` are only touched on the camera queue.
    private var continuation: AsyncThrowingStream<CameraFrame, any Error>.Continuation?
    private var firstTimestamp: TimeInterval?

    func start(_ continuation: AsyncThrowingStream<CameraFrame, any Error>.Continuation) {
        self.continuation = continuation
        firstTimestamp = nil
    }

    func stop() {
        continuation = nil
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard let continuation, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let start = firstTimestamp ?? time
        firstTimestamp = start
        continuation.yield(CameraFrame(timestamp: time - start, pixels: FramePixels(buffer: buffer)))
    }
}
