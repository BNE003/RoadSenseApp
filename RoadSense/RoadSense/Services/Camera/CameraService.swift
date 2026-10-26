//
//  CameraService.swift
//  RoadSense
//

import CoreVideo
import Foundation

nonisolated enum CameraAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

/// A camera image, handed from the camera to the detector and never modified afterwards.
nonisolated struct FramePixels: @unchecked Sendable {
    // @unchecked: the buffer is written once by the capture pipeline before it is delivered and
    // only read after that, so sharing it across actors is safe.
    let buffer: CVPixelBuffer

    var width: Int { CVPixelBufferGetWidth(buffer) }
    var height: Int { CVPixelBufferGetHeight(buffer) }
}

/// One camera image handed to detection.
nonisolated struct CameraFrame: Sendable, Equatable {
    /// Seconds since the camera started.
    var timestamp: TimeInterval
    /// `nil` for the mock camera, which has no pixels.
    var pixels: FramePixels?

    init(timestamp: TimeInterval, pixels: FramePixels? = nil) {
        self.timestamp = timestamp
        self.pixels = pixels
    }

    static func == (lhs: CameraFrame, rhs: CameraFrame) -> Bool {
        lhs.timestamp == rhs.timestamp
    }
}

nonisolated protocol CameraService: Sendable {
    func requestAuthorization() async -> CameraAuthorization
    /// Frames until the consuming task is cancelled. Implementations keep only the newest frame
    /// when the consumer is slower than the camera.
    func frames() -> AsyncThrowingStream<CameraFrame, any Error>
    /// What the live preview shows, or `nil` when there is no real camera.
    var previewSource: CameraPreviewSource? { get }
    /// Width over height of the delivered frames, used to place detection boxes over the preview.
    var frameAspectRatio: Double? { get }
}
