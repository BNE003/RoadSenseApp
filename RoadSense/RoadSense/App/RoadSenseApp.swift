//
//  RoadSenseApp.swift
//  RoadSense
//
//  Created by Benedikt Held on 26.10.26.
//

import SwiftUI

@main
struct RoadSenseApp: App {
    private let launch = LaunchOptions.current
    private let environment: AppEnvironment

    init() {
        RSFont.registerFonts()
        environment = .mock(cameraAuthorization: launch.cameraDenied ? .denied : .authorized)
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment, launch: launch)
        }
    }
}
