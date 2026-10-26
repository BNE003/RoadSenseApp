//
//  MapViewport.swift
//  RoadSense
//

import Foundation

/// A rectangle of the world shown by the stylized map. Projects coordinates to 0...1 canvas space,
/// origin top-left.
nonisolated struct MapViewport: Hashable, Sendable {
    var center: Coordinate
    /// East-west extent in meters.
    var widthMeters: Double
    /// Height / width of the canvas.
    var aspectRatio: Double

    private static let metersPerDegreeLatitude = 111_320.0

    private var latitudeSpan: Double { widthMeters * aspectRatio / Self.metersPerDegreeLatitude }
    private var longitudeSpan: Double {
        widthMeters / (Self.metersPerDegreeLatitude * cos(center.latitude * .pi / 180))
    }

    /// Normalized position, or `nil` if the coordinate lies outside the viewport.
    func project(_ coordinate: Coordinate) -> (x: Double, y: Double)? {
        let x = (coordinate.longitude - (center.longitude - longitudeSpan / 2)) / longitudeSpan
        let y = ((center.latitude + latitudeSpan / 2) - coordinate.latitude) / latitudeSpan
        guard (0...1).contains(x), (0...1).contains(y) else { return nil }
        return (x, y)
    }

    /// Inverse of `project`; used to place sample data at design positions.
    func coordinate(x: Double, y: Double) -> Coordinate {
        Coordinate(
            latitude: center.latitude + latitudeSpan / 2 - y * latitudeSpan,
            longitude: center.longitude - longitudeSpan / 2 + x * longitudeSpan
        )
    }

    /// Size of the design's map canvas (370 × 824 pt) at 4 m per point.
    static let demo = MapViewport(
        center: Coordinate(latitude: 52.5200, longitude: 13.4050),
        widthMeters: 1_480,
        aspectRatio: 824.0 / 370.0
    )
}
