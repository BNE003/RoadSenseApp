//
//  LiveDetectionServiceTests.swift
//  RoadSenseTests
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Testing
@testable import RoadSense

private final class TestBundleToken {}

/// Runs the real bundled Core ML model, so these tests also prove the exported model still
/// matches the original PyTorch weights (acceptance criterion 5, parity part).
struct LiveDetectionServiceTests {
    private let appBundle = Bundle(for: LiveDetectionService.self)

    private func fixtureBuffer(_ name: String) throws -> CVPixelBuffer {
        let url = try #require(Bundle(for: TestBundleToken.self).url(forResource: name, withExtension: "jpg"))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, image.width, image.height, kCVPixelFormatType_32BGRA, nil, &buffer)
        let pixels = try #require(buffer)
        CVPixelBufferLockBaseAddress(pixels, [])
        defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
        let context = try #require(CGContext(
            data: CVPixelBufferGetBaseAddress(pixels), width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixels),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }

    @Test func theManifestMapsEveryCrackClassToCrack() throws {
        let manifest = try ModelManifest.load(from: appBundle)
        #expect(manifest.inputSize == 640)
        #expect(manifest.supportedKinds == [.pothole, .crack])
        #expect(manifest.kind(forLabel: "Pothole") == .pothole)
        for label in ["Longitudinal Crack", "Transverse Crack", "Alligator Crack"] {
            #expect(manifest.kind(forLabel: label) == .crack)
        }
        // "Other" has no counterpart in the app, so such boxes are dropped.
        #expect(manifest.kind(forLabel: "Other") == nil)
    }

    @Test func theServiceReportsOnlyWhatTheModelKnows() throws {
        let service = try LiveDetectionService(bundle: appBundle)
        #expect(service.supportedKinds == [.pothole, .crack])
    }

    /// A 720 × 1280 portrait frame with a cracked-road photo in the road region. The reference box
    /// was produced by the original `best-3.pt` on the same image (Ultralytics 8.4, conf 0.3,
    /// IoU 0.45). This model finds no pothole in any photo tried, so a crack is the fixture.
    @Test func findsTheCrackWhereThePyTorchModelFindsIt() async throws {
        let service = try LiveDetectionService(bundle: appBundle)
        try await service.prepare()
        let frame = CameraFrame(
            timestamp: 0, pixels: FramePixels(buffer: try fixtureBuffer("portrait-frame-with-crack"))
        )

        let found = try await service.detect(in: frame, mountHeight: .standard)

        let expected = NormalizedRect(x: 0.0485, y: 0.3394, width: 0.9341, height: 0.5752)
        let best = try #require(found.max { $0.rect.iou(expected) < $1.rect.iou(expected) })
        #expect(best.kind == .crack)
        #expect(best.rect.iou(expected) > 0.85, "found: \(found)")
        // Scores on a borderline image move by ±0.15 with the resampling method (PyTorch alone
        // gives 0.40 to 0.58), so only "above the detection threshold" is asserted.
        #expect(best.confidence > 0.3, "found: \(found)")
        // Outside the road region nothing was drawn, so nothing may be reported there.
        let region = RoadRegion.rect(for: .standard)
        #expect(found.allSatisfy { $0.rect.y >= region.y - 0.001 && $0.rect.y + $0.rect.height <= region.y + region.height + 0.001 })
    }

    @Test func aFrameWithoutPixelsFindsNothing() async throws {
        let service = try LiveDetectionService(bundle: appBundle)
        #expect(try await service.detect(in: CameraFrame(timestamp: 0), mountHeight: .standard).isEmpty)
    }

    @Test func aBundleWithoutTheModelFailsClearly() {
        #expect(throws: DetectionError.self) { try LiveDetectionService(bundle: Bundle(for: TestBundleToken.self)) }
    }
}
