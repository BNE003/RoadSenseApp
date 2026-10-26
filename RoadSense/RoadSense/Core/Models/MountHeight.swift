//
//  MountHeight.swift
//  RoadSense
//

import Foundation

/// How high the phone sits on the windshield. Passed to the detector for calibration (Milestone 2).
nonisolated enum MountHeight: String, CaseIterable, Sendable {
    case low
    case standard
    case high

    var title: LocalizedStringResource {
        switch self {
        case .low: "Low"
        case .standard: "Standard"
        case .high: "High"
        }
    }
}
