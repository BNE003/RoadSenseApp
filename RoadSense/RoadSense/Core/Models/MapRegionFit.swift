//
//  MapRegionFit.swift
//  RoadSense
//

import Foundation

/// The part of the world that shows a set of coordinates with some room around them.
nonisolated struct MapRegionFit: Equatable, Sendable {
    var center: Coordinate
    /// North-south extent in degrees.
    var latitudeSpan: Double
    /// East-west extent in degrees.
    var longitudeSpan: Double

    private static let metersPerDegreeLatitude = 111_320.0

    /// `margin` scales the bounding box so pins do not sit on the edge or under the screen's header
    /// and card; `minimumMeters` keeps a single pin, or a few close ones, from zooming in absurdly.
    /// `nil` for no coordinates.
    static func fitting(_ coordinates: [Coordinate], minimumMeters: Double = 500, margin: Double = 2.0) -> MapRegionFit? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let center = Coordinate(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let metersPerDegreeLongitude = max(1, metersPerDegreeLatitude * cos(center.latitude * .pi / 180))
        return MapRegionFit(
            center: center,
            latitudeSpan: max((maxLat - minLat) * margin, minimumMeters / metersPerDegreeLatitude),
            longitudeSpan: max((maxLon - minLon) * margin, minimumMeters / metersPerDegreeLongitude)
        )
    }
}
