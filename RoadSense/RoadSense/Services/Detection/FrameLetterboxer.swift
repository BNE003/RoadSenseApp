//
//  FrameLetterboxer.swift
//  RoadSense
//

import CoreImage
import CoreVideo

/// Crops a region out of a camera frame and letterboxes it into a square pixel buffer the model
/// reads. Owns one reusable output buffer, so it must be used from one place at a time.
nonisolated final class FrameLetterboxer {
    // Ultralytics pads letterboxed images with gray 114; the model was trained that way.
    private static let padding = CIColor(red: 114.0 / 255, green: 114.0 / 255, blue: 114.0 / 255)

    private let context = CIContext()
    private let side: Int
    private let output: CVPixelBuffer

    init?(side: Int) {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
        guard CVPixelBufferCreate(
            nil, side, side, kCVPixelFormatType_32BGRA, attributes, &buffer
        ) == kCVReturnSuccess, let buffer else { return nil }
        self.side = side
        output = buffer
    }

    /// The letterboxed region, and the geometry needed to map boxes back to the frame.
    func render(_ frame: CVPixelBuffer, region: NormalizedRect) -> (buffer: CVPixelBuffer, letterbox: Letterbox) {
        let width = Double(CVPixelBufferGetWidth(frame))
        let height = Double(CVPixelBufferGetHeight(frame))
        // Core Image's origin is bottom-left, ours is top-left.
        let crop = CGRect(
            x: region.x * width, y: (1 - region.y - region.height) * height,
            width: region.width * width, height: region.height * height
        )
        let letterbox = Letterbox(sourceWidth: crop.width, sourceHeight: crop.height, side: Double(side))
        let scale = letterbox.scale
        let content = letterbox.content

        let placed = CIImage(cvPixelBuffer: frame)
            .cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(
                translationX: content.x * Double(side), y: (1 - content.y - content.height) * Double(side)
            ))
        let background = CIImage(color: Self.padding).cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
        context.render(placed.composited(over: background), to: output)
        return (output, letterbox)
    }
}
