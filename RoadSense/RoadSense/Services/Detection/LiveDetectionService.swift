//
//  LiveDetectionService.swift
//  RoadSense
//

import CoreML
import Foundation
import Vision
import os

/// Runs the bundled Core ML model on camera frames.
///
/// An actor, so inference never runs on the main actor and two frames are never processed at once.
actor LiveDetectionService: DetectionService {
    private let logger = Logger(subsystem: "b.held.RoadSense", category: "detection")
    private let manifest: ModelManifest
    private let bundle: Bundle
    private let confidenceThreshold: Double
    private let iouThreshold: Double
    private var model: VNCoreMLModel?
    private var letterboxer: FrameLetterboxer?

    nonisolated let supportedKinds: Set<IssueKind>

    /// Throws if the manifest next to the model is missing or unreadable.
    init(bundle: Bundle = .main, confidenceThreshold: Double = 0.3, iouThreshold: Double = 0.45) throws {
        manifest = try ModelManifest.load(from: bundle)
        self.bundle = bundle
        self.confidenceThreshold = confidenceThreshold
        self.iouThreshold = iouThreshold
        supportedKinds = manifest.supportedKinds
    }

    func prepare() async throws {
        guard model == nil else { return }
        guard let url = bundle.url(forResource: manifest.name, withExtension: "mlmodelc") else {
            throw DetectionError.modelMissing
        }
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: configuration))
            // The exported pipeline applies non-maximum suppression itself; these are its thresholds.
            visionModel.featureProvider = try MLDictionaryFeatureProvider(dictionary: [
                "confidenceThreshold": confidenceThreshold,
                "iouThreshold": iouThreshold,
            ])
            model = visionModel
            letterboxer = FrameLetterboxer(side: manifest.inputSize)
            logger.info("Model \(self.manifest.name, privacy: .public) loaded")
        } catch {
            logger.error("Model failed to load: \(error.localizedDescription, privacy: .public)")
            throw DetectionError.modelFailed
        }
    }

    func detect(in frame: CameraFrame, mountHeight: MountHeight) async throws -> [RawDetection] {
        guard let pixels = frame.pixels else { return [] }
        if model == nil { try await prepare() }
        guard let model, let letterboxer else { throw DetectionError.modelFailed }

        let region = RoadRegion.rect(for: mountHeight)
        let (input, letterbox) = letterboxer.render(pixels.buffer, region: region)

        let request = VNCoreMLRequest(model: model)
        // The input is already square and letterboxed; Vision must not crop or pad it again.
        request.imageCropAndScaleOption = .scaleFill
        try VNImageRequestHandler(cvPixelBuffer: input).perform([request])

        let observations = request.results as? [VNRecognizedObjectObservation] ?? []
        return observations.compactMap { Self.detection(from: $0, manifest: manifest, letterbox: letterbox, region: region) }
    }

    /// Maps one Vision observation (unit square, origin bottom-left) into frame coordinates.
    nonisolated static func detection(
        from observation: VNRecognizedObjectObservation, manifest: ModelManifest,
        letterbox: Letterbox, region: NormalizedRect
    ) -> RawDetection? {
        guard let label = observation.labels.first, let kind = manifest.kind(forLabel: label.identifier) else {
            return nil
        }
        let box = observation.boundingBox
        let inSquare = NormalizedRect(
            x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height
        )
        let inFrame = letterbox.toSource(inSquare).mapped(from: region)
        guard inFrame.width > 0, inFrame.height > 0 else { return nil }
        return RawDetection(kind: kind, confidence: Double(observation.confidence), rect: inFrame)
    }
}
