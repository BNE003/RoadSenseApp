//
//  SettingsStore.swift
//  RoadSense
//

import Foundation

/// User preferences. Read on the main actor.
@MainActor
protocol SettingsStore: AnyObject {
    var vehicleName: String { get }
    var mountHeight: MountHeight { get set }
    var autoStart: Bool { get set }
    var alertSounds: Bool { get set }
    var wifiOnlyUpload: Bool { get set }
}

@MainActor
final class UserDefaultsSettingsStore: SettingsStore {
    private enum Key {
        static let mountHeight = "settings.mountHeight"
        static let autoStart = "settings.autoStart"
        static let alertSounds = "settings.alertSounds"
        static let wifiOnlyUpload = "settings.wifiOnlyUpload"
    }

    private let defaults: UserDefaults

    // TODO(M3): the vehicle comes from the signed-in organization.
    let vehicleName = "Volvo XC40"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.mountHeight: MountHeight.standard.rawValue,
            Key.autoStart: true,
            Key.alertSounds: true,
            Key.wifiOnlyUpload: false,
        ])
    }

    var mountHeight: MountHeight {
        get { defaults.string(forKey: Key.mountHeight).flatMap(MountHeight.init(rawValue:)) ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Key.mountHeight) }
    }

    var autoStart: Bool {
        get { defaults.bool(forKey: Key.autoStart) }
        set { defaults.set(newValue, forKey: Key.autoStart) }
    }

    var alertSounds: Bool {
        get { defaults.bool(forKey: Key.alertSounds) }
        set { defaults.set(newValue, forKey: Key.alertSounds) }
    }

    var wifiOnlyUpload: Bool {
        get { defaults.bool(forKey: Key.wifiOnlyUpload) }
        set { defaults.set(newValue, forKey: Key.wifiOnlyUpload) }
    }
}
