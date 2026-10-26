//
//  LaunchOptions.swift
//  RoadSense
//

import Foundation

/// Debug-only launch arguments for screenshots and UI tests, e.g. `-RS_SCREEN map`.
struct LaunchOptions {
    enum Screen: String {
        case home, live, summary, map, history, settings
    }

    var screen: Screen?
    var cameraDenied = false
    /// Simulated camera, detector and GPS with an in-memory store. Always on in the simulator,
    /// which has no camera, unless `-RS_USE_LIVE YES` is passed.
    var useMocks = false

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    static var current: LaunchOptions {
        #if DEBUG
        let defaults = UserDefaults.standard
        return LaunchOptions(
            screen: defaults.string(forKey: "RS_SCREEN").flatMap(Screen.init(rawValue:)),
            cameraDenied: defaults.bool(forKey: "RS_CAMERA_DENIED"),
            useMocks: defaults.bool(forKey: "RS_USE_MOCKS") || (isSimulator && !defaults.bool(forKey: "RS_USE_LIVE"))
        )
        #else
        return LaunchOptions()
        #endif
    }
}
