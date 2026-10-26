//
//  CameraPreviewUIView.swift
//  RoadSense
//

import AVFoundation
import UIKit

/// A view whose layer is the camera preview. SwiftUI wraps it in the Inspection feature.
final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    func attach(_ source: CameraPreviewSource) {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else { return }
        previewLayer.session = source.session
        previewLayer.videoGravity = .resizeAspectFill
    }
}
