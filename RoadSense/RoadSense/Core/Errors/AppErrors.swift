//
//  AppErrors.swift
//  RoadSense
//

import Foundation

nonisolated enum CameraError: LocalizedError, Sendable {
    case accessDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            String(localized: "RoadSense needs camera access to inspect the road.")
        case .unavailable:
            String(localized: "The camera is not available.")
        }
    }
}

nonisolated enum LocationError: LocalizedError, Sendable {
    case accessDenied

    var errorDescription: String? {
        String(localized: "RoadSense needs your location to place issues on the map.")
    }
}

nonisolated enum PersistenceError: LocalizedError, Sendable {
    case saveFailed
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed: String(localized: "The drive could not be saved.")
        case .loadFailed: String(localized: "Your drives could not be loaded.")
        }
    }
}

nonisolated enum DetectionError: LocalizedError, Sendable {
    case modelMissing
    case modelFailed

    var errorDescription: String? {
        switch self {
        case .modelMissing: String(localized: "The detection model is missing from the app.")
        case .modelFailed: String(localized: "The detection model could not be started.")
        }
    }
}
