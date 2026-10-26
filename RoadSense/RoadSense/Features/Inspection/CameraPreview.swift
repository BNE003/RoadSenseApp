//
//  CameraPreview.swift
//  RoadSense
//

import SwiftUI

/// The live camera image, filling its space.
struct CameraPreview: UIViewRepresentable {
    let source: CameraPreviewSource

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.attach(source)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}
