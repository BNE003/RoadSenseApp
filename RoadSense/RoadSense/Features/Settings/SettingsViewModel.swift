//
//  SettingsViewModel.swift
//  RoadSense
//

import Foundation
import Observation

@MainActor @Observable
final class SettingsViewModel {
    private let store: any SettingsStore

    var mountHeight: MountHeight { didSet { store.mountHeight = mountHeight } }
    var autoStart: Bool { didSet { store.autoStart = autoStart } }
    var alertSounds: Bool { didSet { store.alertSounds = alertSounds } }
    var wifiOnlyUpload: Bool { didSet { store.wifiOnlyUpload = wifiOnlyUpload } }

    init(environment: AppEnvironment) {
        store = environment.settings
        mountHeight = store.mountHeight
        autoStart = store.autoStart
        alertSounds = store.alertSounds
        wifiOnlyUpload = store.wifiOnlyUpload
    }

    var vehicleName: String { store.vehicleName }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
