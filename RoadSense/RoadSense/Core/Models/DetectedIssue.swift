//
//  DetectedIssue.swift
//  RoadSense
//

import Foundation

/// One piece of detected road damage.
nonisolated struct DetectedIssue: Identifiable, Hashable, Sendable {
    let id: UUID
    var driveID: UUID
    var kind: IssueKind
    /// Model confidence, 0...1.
    var confidence: Double
    var detectedAt: Date
    /// `nil` when no acceptable GPS fix was available at detection time.
    var coordinate: Coordinate?
    /// Street or place name, when known.
    var place: String?
    var note: String?
}
