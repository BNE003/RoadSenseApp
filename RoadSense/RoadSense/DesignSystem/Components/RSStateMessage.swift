//
//  RSStateMessage.swift
//  RoadSense
//

import SwiftUI

/// A quiet line shown where a list is empty or could not be loaded. Uses existing type styles only.
struct RSStateMessage: View {
    let text: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RSRule()
            Text(text).rs(14).foregroundStyle(Color.rsMuted).padding(.top, 12)
            if let retry {
                Button("Try again", action: retry).rs(14, .semibold).foregroundStyle(Color.rsInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
