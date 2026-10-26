//
//  ModelManifest.swift
//  RoadSense
//

import Foundation

/// `model.json`, written next to the Core ML model by `tools/model/convert.py`. It tells the app
/// what the model is, so replacing the model needs no code change.
nonisolated struct ModelManifest: Decodable, Sendable, Equatable {
    struct Class: Decodable, Sendable, Equatable {
        var index: Int
        /// The label the model reports for this class.
        var name: String
        var kind: IssueKind
    }

    var name: String
    var source: String
    /// Side of the square image the model expects, in pixels.
    var inputSize: Int
    var classes: [Class]

    var supportedKinds: Set<IssueKind> { Set(classes.map(\.kind)) }

    func kind(forLabel label: String) -> IssueKind? {
        classes.first { $0.name == label }?.kind
    }

    static func load(from bundle: Bundle) throws -> ModelManifest {
        guard let url = bundle.url(forResource: "model", withExtension: "json") else {
            throw DetectionError.modelMissing
        }
        return try JSONDecoder().decode(ModelManifest.self, from: Data(contentsOf: url))
    }
}
