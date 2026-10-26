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

    static var current: LaunchOptions {
        #if DEBUG
        let defaults = UserDefaults.standard
        return LaunchOptions(
            screen: defaults.string(forKey: "RS_SCREEN").flatMap(Screen.init(rawValue:)),
            cameraDenied: defaults.bool(forKey: "RS_CAMERA_DENIED")
        )
        #else
        return LaunchOptions()
        #endif
    }
}
