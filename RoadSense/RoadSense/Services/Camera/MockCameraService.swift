//
//  MockCameraService.swift
//  RoadSense
//

import Foundation

/// Produces one empty frame per second. Used wherever there is no real camera.
nonisolated struct MockCameraService: CameraService {
    var authorization: CameraAuthorization = .authorized
    var clock: any Clock<Duration> = ContinuousClock()

    func requestAuthorization() async -> CameraAuthorization { authorization }

    func frames() -> AsyncThrowingStream<CameraFrame, any Error> {
        let clock = clock
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                var seconds = 0.0
                do {
                    while true {
                        try await clock.sleep(for: .seconds(1))
                        seconds += 1
                        continuation.yield(CameraFrame(timestamp: seconds))
                    }
                } catch {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
