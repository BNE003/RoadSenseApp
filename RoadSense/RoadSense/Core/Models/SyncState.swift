//
//  SyncState.swift
//  RoadSense
//

import Foundation

/// Where a stored record stands on its way to the server. M2 only ever writes `pending`; the
/// states exist now so Milestone 3 needs no schema change for them.
nonisolated enum SyncState: String, Sendable, Codable {
    case pending, syncing, synced, failed
}
