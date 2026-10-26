//
//  CameraService.swift
//  RoadSense
//

import Foundation

nonisolated enum CameraAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

/// One camera image handed to detection. Milestone 2 adds the pixel buffer.
nonisolated struct CameraFrame: Sendable, Equatable {
    /// Seconds since the camera started.
    var timestamp: TimeInterval
}

nonisolated protocol CameraService: Sendable {
    func requestAuthorization() async -> CameraAuthorization
    /// Frames until the consuming task is cancelled. Implementations keep only the newest frame
    /// when the consumer is slower than the camera.
    func frames() -> AsyncThrowingStream<CameraFrame, any Error>
}
