//
//  GeometryTests.swift
//  RoadSenseTests
//

import Foundation
import Testing
@testable import RoadSense

struct GeometryTests {
    private func close(_ a: NormalizedRect, _ b: NormalizedRect, tolerance: Double = 1e-9) -> Bool {
        abs(a.x - b.x) < tolerance && abs(a.y - b.y) < tolerance
            && abs(a.width - b.width) < tolerance && abs(a.height - b.height) < tolerance
    }

    // MARK: Letterbox

    @Test func aWideImageIsPaddedAboveAndBelow() {
        let letterbox = Letterbox(sourceWidth: 1280, sourceHeight: 640, side: 640)
        #expect(letterbox.scale == 0.5)
        #expect(close(letterbox.content, NormalizedRect(x: 0, y: 0.25, width: 1, height: 0.5)))
    }

    @Test func aTallImageIsPaddedLeftAndRight() {
        let letterbox = Letterbox(sourceWidth: 360, sourceHeight: 720, side: 640)
        #expect(close(letterbox.content, NormalizedRect(x: 0.25, y: 0, width: 0.5, height: 1)))
    }

    @Test func aBoxInTheSquareMapsBackToTheSourceImage() {
        let letterbox = Letterbox(sourceWidth: 360, sourceHeight: 720, side: 640)
        // The left quarter of the content is the left quarter of the source.
        let box = NormalizedRect(x: 0.25, y: 0.5, width: 0.125, height: 0.25)
        #expect(close(letterbox.toSource(box), NormalizedRect(x: 0, y: 0.5, width: 0.25, height: 0.25)))
    }

    @Test func aBoxOverThePaddingIsClampedToTheImage() {
        let letterbox = Letterbox(sourceWidth: 360, sourceHeight: 720, side: 640)
        let mapped = letterbox.toSource(NormalizedRect(x: 0.1, y: 0, width: 0.3, height: 0.2))
        // The box starts 0.15 left of the image (0.3 of its width) and ends 0.3 into it.
        #expect(close(mapped, NormalizedRect(x: 0, y: 0, width: 0.3, height: 0.2)))
    }

    // MARK: Road region

    @Test func aBoxInTheRegionMapsIntoTheFrame() {
        let region = NormalizedRect(x: 0, y: 0.5, width: 1, height: 0.5)
        let box = NormalizedRect(x: 0.2, y: 0.5, width: 0.4, height: 0.25)
        #expect(close(box.mapped(from: region), NormalizedRect(x: 0.2, y: 0.75, width: 0.4, height: 0.125)))
    }

    @Test func everyMountHeightLooksAtTheLowerPartOfTheFrame() {
        for height in MountHeight.allCases {
            let region = RoadRegion.rect(for: height)
            #expect(region.y > 0.2 && region.y + region.height <= 1)
        }
        #expect(RoadRegion.rect(for: .low).y < RoadRegion.rect(for: .high).y)
    }

    // MARK: Aspect fill

    @Test func aPortraitFrameOnATallerScreenIsCroppedAtTheSides() {
        // 9:16 frame on a 9:19.5 screen: the frame is scaled to the screen height.
        let rect = NormalizedRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1)
        let shown = rect.aspectFilled(contentAspect: 9.0 / 16, containerAspect: 9.0 / 19.5)
        let visibleWidth = (9.0 / 19.5) / (9.0 / 16)
        #expect(abs(shown.width - 0.1 / visibleWidth) < 1e-9)
        #expect(shown.y == 0.5 && shown.height == 0.1)
        // The center of the frame stays the center of the screen.
        let centered = NormalizedRect(x: 0.45, y: 0, width: 0.1, height: 1)
            .aspectFilled(contentAspect: 9.0 / 16, containerAspect: 9.0 / 19.5)
        #expect(abs((centered.x + centered.width / 2) - 0.5) < 1e-9)
    }

    @Test func aFrameAsWideAsTheScreenIsNotChanged() {
        let rect = NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        #expect(close(rect.aspectFilled(contentAspect: 0.5, containerAspect: 0.5), rect))
    }

    // MARK: Route

    @Test func theRouteKeepsOnePointPerTwentyMeters() {
        var route = RouteBreadcrumb()
        let start = Date(timeIntervalSince1970: 0)
        for step in 0..<10 {
            // About 11 m per second.
            route.append(Coordinate(latitude: 52 + Double(step) * 0.0001, longitude: 13), at: start + Double(step))
        }
        #expect(route.points.count == 5)
    }

    @Test func standingStillAddsNoPoints() {
        var route = RouteBreadcrumb()
        let start = Date(timeIntervalSince1970: 0)
        route.append(Coordinate(latitude: 52, longitude: 13), at: start)
        for second in 1...120 {
            route.append(Coordinate(latitude: 52.00001, longitude: 13), at: start + Double(second))
        }
        #expect(route.points.count == 1)
    }

    // MARK: Auto-start

    /// Which of the samples made the detector fire.
    private func firings(_ speeds: [Double]) -> [Int] {
        var detector = MovementDetector()
        return speeds.indices.filter { detector.ingest(speed: speeds[$0]) }
    }

    @Test func movementStartsAfterThreeFastSamples() {
        #expect(firings([8, 8, 8]) == [2])
    }

    @Test func aSingleFastSampleOrUnknownSpeedDoesNotStart() {
        // Unknown speed (-1) neither counts nor resets; a slow one (2 m/s) resets the count.
        #expect(firings([8, -1, 2, 8, 8]) == [])
        #expect(firings([8, -1, 8, 8]) == [3])
    }

    @Test func itFiresAgainOnlyAfterTheVehicleSlowedDown() {
        let driving = [Double](repeating: 10, count: 12)
        // Still driving after the first start: silent. Stopped at a light, then away again: fires.
        #expect(firings(driving + [0.5] + driving) == [2, 15])
    }

    // MARK: Throttle

    @Test func aHotterPhoneRunsTheModelLessOften() {
        let nominal = InferenceThrottle.interval(for: .nominal)
        let serious = InferenceThrottle.interval(for: .serious)
        let critical = InferenceThrottle.interval(for: .critical)
        #expect(nominal <= 0.1 && nominal < serious && serious < critical)
        #expect(InferenceThrottle.interval(for: .fair) == nominal)
    }
}
