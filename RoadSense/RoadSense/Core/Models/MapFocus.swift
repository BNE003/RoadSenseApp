//
//  MapFocus.swift
//  RoadSense
//

import Foundation

/// Which issues the map should show.
nonisolated enum MapFocus: Hashable, Sendable {
    case all
    case drive(Drive.ID)
}
