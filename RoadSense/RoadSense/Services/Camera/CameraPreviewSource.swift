//
//  CameraPreviewSource.swift
//  RoadSense
//

@preconcurrency import AVFoundation

/// An opaque handle on the running capture session, so the Inspection screen can show the live
/// preview without importing AVFoundation.
nonisolated final class CameraPreviewSource: @unchecked Sendable {
    // @unchecked: the session is only ever handed to `AVCaptureVideoPreviewLayer.session`, which is
    // how AVFoundation intends it to be shared; all other access stays on the camera's queue.
    let session: AVCaptureSession

    init(session: AVCaptureSession) {
        self.session = session
    }
}
