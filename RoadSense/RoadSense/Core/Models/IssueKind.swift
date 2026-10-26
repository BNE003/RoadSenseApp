//
//  IssueKind.swift
//  RoadSense
//

import Foundation

/// The kinds of road damage RoadSense can report.
nonisolated enum IssueKind: String, CaseIterable, Hashable, Sendable, Codable {
    case pothole
    case crack
    case sign
}

nonisolated extension IssueKind {
    /// "Pothole": detail card.
    var singularTitle: LocalizedStringResource {
        switch self {
        case .pothole: "Pothole"
        case .crack: "Crack"
        case .sign: "Sign"
        }
    }

    /// "Potholes": live counters and map filter.
    var pluralTitle: LocalizedStringResource {
        switch self {
        case .pothole: "Potholes"
        case .crack: "Cracks"
        case .sign: "Signs"
        }
    }

    /// "Road cracks": drive summary breakdown.
    var breakdownTitle: LocalizedStringResource {
        switch self {
        case .pothole: "Potholes"
        case .crack: "Road cracks"
        case .sign: "Damaged signs"
        }
    }
}
