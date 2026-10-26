//
//  DriveFormatting.swift
//  RoadSense
//

import Foundation

/// Display formatting for drive data. Pure functions so they are unit-testable.
nonisolated enum DriveFormatting {
    /// "24.6"
    static func kilometers(_ meters: Double) -> String {
        (meters / 1000).formatted(.number.precision(.fractionLength(1)))
    }

    /// "412": whole kilometers for aggregate totals.
    static func wholeKilometers(_ meters: Double) -> String {
        (meters / 1000).formatted(.number.precision(.fractionLength(0)))
    }

    /// "38": whole minutes, rounded.
    static func minutes(_ seconds: TimeInterval) -> String {
        Int((seconds / 60).rounded()).formatted()
    }

    /// "01:05"
    static func clock(elapsedSeconds: Int) -> String {
        let clamped = max(0, elapsedSeconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    /// "Today", "Yesterday" or "22 Oct".
    static func day(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Today") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// "Today, 09:41"
    static func dayAndTime(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = date.formatted(.dateTime.hour().minute())
        return "\(day(date, now: now, calendar: calendar)), \(time)"
    }

    /// "Today · 24.6 km"
    static func shortMeta(_ drive: DriveSummary, now: Date, calendar: Calendar = .current) -> String {
        "\(day(drive.startedAt, now: now, calendar: calendar)) · \(kilometers(drive.distanceMeters)) km"
    }

    /// "Today · 24.6 km · 38 min"
    static func longMeta(_ drive: DriveSummary, now: Date, calendar: Calendar = .current) -> String {
        "\(shortMeta(drive, now: now, calendar: calendar)) · \(minutes(drive.duration)) min"
    }

    /// "52.5201, 13.4052": fallback when an issue has no place name.
    static func coordinate(_ coordinate: Coordinate) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(4))
        return "\(coordinate.latitude.formatted(style)), \(coordinate.longitude.formatted(style))"
    }
}
