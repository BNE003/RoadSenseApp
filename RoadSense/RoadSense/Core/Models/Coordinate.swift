//
//  Coordinate.swift
//  RoadSense
//

import Foundation

/// A WGS84 position. Kept independent of CoreLocation so Core has no framework dependencies.
nonisolated struct Coordinate: Hashable, Sendable, Codable {
    var latitude: Double
    var longitude: Double

    /// Great-circle distance in meters (haversine).
    func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(a)))
    }
}
