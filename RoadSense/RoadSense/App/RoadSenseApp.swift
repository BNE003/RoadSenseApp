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
    private let startup: Result<AppEnvironment, any Error>

    init() {
        RSFont.registerFonts()
        let launch = LaunchOptions.current
        if launch.useMocks {
            startup = .success(.mock(cameraAuthorization: launch.cameraDenied ? .denied : .authorized))
        } else {
            startup = Result { try AppEnvironment.live() }
        }
    }

    var body: some Scene {
        WindowGroup {
            switch startup {
            case .success(let environment):
                RootView(environment: environment, launch: launch)
            case .failure(let error):
                StartupFailureView(message: error.localizedDescription)
            }
        }
    }
}

/// Shown when the model or the on-device store cannot be opened: recording would not be safe.
private struct StartupFailureView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Can't start").rs(40, .heavy, tracking: -1.8, scales: false)
            Text(message).rs(15).foregroundStyle(Color.rsBody).padding(.top, 14)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RSLayout.screenInset)
        .foregroundStyle(Color.rsInk)
        .background { Color.rsPaper.ignoresSafeArea() }
    }
}
