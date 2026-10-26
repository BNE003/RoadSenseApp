//
//  DriveStatus.swift
//  RoadSense
//

import Foundation

nonisolated enum DriveStatus: String, Sendable, Codable {
    /// Still being recorded, or never saved from the summary. Not listed in History until finished.
    case inProgress
    case finished
}
