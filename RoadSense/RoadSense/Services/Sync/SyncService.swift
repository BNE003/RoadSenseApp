//
//  SyncService.swift
//  RoadSense
//

import Foundation

nonisolated enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case failed
}

/// Uploads local drives to the backend. Implemented with Supabase in Milestone 3.
nonisolated protocol SyncService: Sendable {
    func statusUpdates() -> AsyncStream<SyncStatus>
    func syncNow() async
}

/// Does nothing. Used until the backend exists.
nonisolated struct NoopSyncService: SyncService {
    func statusUpdates() -> AsyncStream<SyncStatus> {
        AsyncStream { continuation in
            continuation.yield(.idle)
            continuation.finish()
        }
    }

    func syncNow() async {}
}
