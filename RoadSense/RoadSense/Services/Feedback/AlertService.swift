//
//  AlertService.swift
//  RoadSense
//

import AudioToolbox
import Foundation

/// Tells the driver, without looking at the screen, that something was found.
nonisolated protocol AlertService: Sendable {
    func playDetectionAlert()
}

/// Silent: previews, tests and the simulator.
nonisolated struct NoopAlertService: AlertService {
    func playDetectionAlert() {}
}

/// A short system sound. It follows the ring/silent switch, which is what drivers expect.
nonisolated struct LiveAlertService: AlertService {
    private static let tockSound: SystemSoundID = 1057

    func playDetectionAlert() {
        AudioServicesPlaySystemSound(Self.tockSound)
    }
}
