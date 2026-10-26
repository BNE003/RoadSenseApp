//
//  ManualClock.swift
//  RoadSenseTests
//

import Foundation
import os

/// A clock that only moves when the test advances it, so tests never wait for real time.
final class ManualClock: Clock, @unchecked Sendable {
    // @unchecked: all mutable state lives in `state`, which is guarded by its lock.
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private struct Sleeper {
        let id: UInt64
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var nextID: UInt64 = 0
        var sleepers: [Sleeper] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var now: Instant { state.withLock { $0.now } }
    var minimumResolution: Duration { .zero }

    /// Number of tasks currently suspended in `sleep`.
    var sleeperCount: Int { state.withLock { $0.sleepers.count } }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = state.withLock { state -> UInt64 in
            state.nextID += 1
            return state.nextID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let action = state.withLock { state -> Result<Void, any Error>? in
                    if Task.isCancelled { return .failure(CancellationError()) }
                    if deadline <= state.now { return .success(()) }
                    state.sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                    return nil
                }
                if let action { continuation.resume(with: action) }
            }
        } onCancel: {
            let sleeper = state.withLock { state -> Sleeper? in
                guard let index = state.sleepers.firstIndex(where: { $0.id == id }) else { return nil }
                return state.sleepers.remove(at: index)
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves time forward, waking sleepers in deadline order.
    func advance(by duration: Duration) async {
        let target = state.withLock { $0.now.offset + duration }
        while true {
            let due = state.withLock { state -> Sleeper? in
                let next = state.sleepers.filter { $0.deadline.offset <= target }
                    .min { $0.deadline < $1.deadline }
                guard let next else {
                    state.now = Instant(offset: target)
                    return nil
                }
                state.now = next.deadline
                state.sleepers.removeAll { $0.id == next.id }
                return next
            }
            guard let due else { return }
            due.continuation.resume()
            await Task.yield()
        }
    }
}
