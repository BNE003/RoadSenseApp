//
//  CoreModelTests.swift
//  RoadSenseTests
//

import Foundation
import Testing
@testable import RoadSense

struct CoordinateTests {
    @Test func distanceOfOneDegreeLatitudeIsAbout111Kilometers() {
        let a = Coordinate(latitude: 52, longitude: 13)
        let b = Coordinate(latitude: 53, longitude: 13)
        #expect(abs(a.distance(to: b) - 111_195) < 200)
    }

    @Test func distanceToSelfIsZero() {
        let a = Coordinate(latitude: 52.5, longitude: 13.4)
        #expect(a.distance(to: a) == 0)
    }
}

struct NormalizedRectTests {
    @Test func identicalRectsHaveIouOne() {
        let r = NormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        #expect(abs(r.iou(r) - 1) < 1e-9)
    }

    @Test func disjointRectsHaveIouZero() {
        let a = NormalizedRect(x: 0, y: 0, width: 0.1, height: 0.1)
        let b = NormalizedRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1)
        #expect(a.iou(b) == 0)
    }

    @Test func halfOverlapHasIouOneThird() {
        let a = NormalizedRect(x: 0, y: 0, width: 0.2, height: 0.1)
        let b = NormalizedRect(x: 0.1, y: 0, width: 0.2, height: 0.1)
        #expect(abs(a.iou(b) - 1.0 / 3.0) < 1e-9)
    }
}

struct MapViewportTests {
    @Test func projectionRoundTrips() throws {
        let viewport = MapViewport.demo
        let coordinate = viewport.coordinate(x: 0.3, y: 0.7)
        let point = try #require(viewport.project(coordinate))
        #expect(abs(point.x - 0.3) < 1e-9)
        #expect(abs(point.y - 0.7) < 1e-9)
    }

    @Test func coordinatesOutsideTheViewportAreNotProjected() {
        let far = Coordinate(latitude: 10, longitude: 10)
        #expect(MapViewport.demo.project(far) == nil)
    }

    @Test func viewportCenterProjectsToMiddle() throws {
        let point = try #require(MapViewport.demo.project(MapViewport.demo.center))
        #expect(abs(point.x - 0.5) < 1e-9 && abs(point.y - 0.5) < 1e-9)
    }
}

struct DriveSummaryTests {
    @Test func summaryCountsIssuesPerKind() {
        let drive = Drive.sample()
        let summary = drive.summary
        #expect(summary.totalIssues == 11)
        #expect(summary.count(of: .pothole) == 3)
        #expect(summary.count(of: .crack) == 7)
        #expect(summary.count(of: .sign) == 1)
    }

    @Test func fractionsMatchTheDesignBars() {
        let summary = Drive.sample().summary
        #expect(Int((summary.fraction(of: .pothole) * 100).rounded()) == 27)
        #expect(Int((summary.fraction(of: .crack) * 100).rounded()) == 64)
        #expect(Int((summary.fraction(of: .sign) * 100).rounded()) == 9)
    }

    @Test func emptyDriveHasNoFractions() {
        var drive = Drive.sample()
        drive.issues = []
        #expect(drive.summary.fraction(of: .pothole) == 0)
    }

    @Test func durationIsNeverNegative() {
        var drive = Drive.sample()
        drive.endedAt = drive.startedAt.addingTimeInterval(-10)
        #expect(drive.duration == 0)
    }
}

struct DriveFormattingTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12)) ?? Date()
    }

    @Test func clockPadsMinutesAndSeconds() {
        #expect(DriveFormatting.clock(elapsedSeconds: 65) == "01:05")
        #expect(DriveFormatting.clock(elapsedSeconds: 0) == "00:00")
        #expect(DriveFormatting.clock(elapsedSeconds: -3) == "00:00")
    }

    @Test func dayNamesTodayAndYesterday() {
        let now = date(26)
        #expect(DriveFormatting.day(date(26), now: now, calendar: calendar) == String(localized: "Today"))
        #expect(DriveFormatting.day(date(25), now: now, calendar: calendar) == String(localized: "Yesterday"))
        #expect(DriveFormatting.day(date(22), now: now, calendar: calendar) != String(localized: "Yesterday"))
    }

    @Test func minutesRoundToWholeNumbers() {
        #expect(DriveFormatting.minutes(38 * 60 + 20) == "38")
        #expect(DriveFormatting.minutes(38 * 60 + 40) == "39")
    }
}
