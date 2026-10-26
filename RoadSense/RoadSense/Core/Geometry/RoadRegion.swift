//
//  RoadRegion.swift
//  RoadSense
//

import Foundation

/// The part of the camera frame the detector looks at. The sky, and the hood and dashboard at the
/// bottom, are cut off so the model's 640 px go to the road.
nonisolated enum RoadRegion {
    // Starting values, not measured: a higher mount sees more road, a lower one more hood.
    // TODO(M2): tune on footage from the real mounted-phone setup.
    static func rect(for mountHeight: MountHeight) -> NormalizedRect {
        switch mountHeight {
        case .low: NormalizedRect(x: 0, y: 0.28, width: 1, height: 0.62)
        case .standard: NormalizedRect(x: 0, y: 0.32, width: 1, height: 0.62)
        case .high: NormalizedRect(x: 0, y: 0.36, width: 1, height: 0.62)
        }
    }
}

nonisolated extension NormalizedRect {
    /// Converts a rect given relative to `region` into the coordinates of the whole frame.
    func mapped(from region: NormalizedRect) -> NormalizedRect {
        NormalizedRect(
            x: region.x + x * region.width, y: region.y + y * region.height,
            width: width * region.width, height: height * region.height
        )
    }

    /// Clamps the rect into the unit square.
    func clamped() -> NormalizedRect {
        let left = min(max(x, 0), 1), top = min(max(y, 0), 1)
        let right = min(max(x + width, 0), 1), bottom = min(max(y + height, 0), 1)
        return NormalizedRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    /// Where this rect, given in a frame of `contentAspect` (width / height) that is shown
    /// aspect-filled in a view of `containerAspect`, lies in the view's unit space.
    /// Rects outside the visible part may leave the unit square.
    func aspectFilled(contentAspect: Double, containerAspect: Double) -> NormalizedRect {
        guard contentAspect > 0, containerAspect > 0 else { return self }
        if contentAspect > containerAspect {
            // Content is wider than the view: the sides are cropped.
            let visibleWidth = containerAspect / contentAspect
            let inset = (1 - visibleWidth) / 2
            return NormalizedRect(x: (x - inset) / visibleWidth, y: y, width: width / visibleWidth, height: height)
        } else {
            let visibleHeight = contentAspect / containerAspect
            let inset = (1 - visibleHeight) / 2
            return NormalizedRect(x: x, y: (y - inset) / visibleHeight, width: width, height: height / visibleHeight)
        }
    }
}

/// An image scaled to fit a square of `side` px without distortion and padded; YOLO models are
/// trained on such letterboxed images.
nonisolated struct Letterbox: Equatable, Sendable {
    var sourceWidth: Double
    var sourceHeight: Double
    var side: Double

    var scale: Double { min(side / sourceWidth, side / sourceHeight) }

    /// The area of the square covered by the image, in the square's unit space.
    var content: NormalizedRect {
        let width = sourceWidth * scale / side, height = sourceHeight * scale / side
        return NormalizedRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
    }

    /// Converts a box in the square's unit space to the source image's unit space.
    func toSource(_ rect: NormalizedRect) -> NormalizedRect {
        let content = content
        return NormalizedRect(
            x: (rect.x - content.x) / content.width, y: (rect.y - content.y) / content.height,
            width: rect.width / content.width, height: rect.height / content.height
        ).clamped()
    }
}
