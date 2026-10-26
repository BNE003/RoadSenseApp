//
//  NormalizedRect.swift
//  RoadSense
//

import Foundation

/// A rectangle in unit space (0...1 on both axes, origin top-left).
nonisolated struct NormalizedRect: Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    /// Intersection over union, 0...1.
    func iou(_ other: NormalizedRect) -> Double {
        let left = max(x, other.x)
        let top = max(y, other.y)
        let right = min(x + width, other.x + other.width)
        let bottom = min(y + height, other.y + other.height)
        let intersection = max(0, right - left) * max(0, bottom - top)
        let union = width * height + other.width * other.height - intersection
        return union > 0 ? intersection / union : 0
    }
}
