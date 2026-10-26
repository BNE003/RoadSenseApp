//
//  InferenceThrottle.swift
//  RoadSense
//

import Foundation

/// How often the detector may run. A hot phone gets fewer inferences so it can cool down.
nonisolated enum InferenceThrottle {
    /// Minimum seconds between two inferences.
    static func interval(for thermalState: ProcessInfo.ThermalState) -> TimeInterval {
        switch thermalState {
        case .nominal, .fair: 0.1
        case .serious: 0.4
        case .critical: 1
        @unknown default: 0.4
        }
    }
}
