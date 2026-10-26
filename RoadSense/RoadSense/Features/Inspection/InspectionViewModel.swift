//
//  InspectionViewModel.swift
//  RoadSense
//

import Foundation
import Observation

@MainActor @Observable
final class InspectionViewModel {
    enum Phase: Equatable {
        case recording
        case failed(String)
        case finished(Drive)
    }

    private(set) var phase: Phase
    private(set) var snapshot = InspectionSnapshot()
    /// Kinds shown as counters, in a stable order.
    let counterKinds: [IssueKind]

    private let makeSession: @MainActor () -> InspectionSession
    private var task: Task<Void, Never>?

    init(environment: AppEnvironment, finishedDrive: Drive? = nil) {
        counterKinds = IssueKind.allCases.filter { environment.detection.supportedKinds.contains($0) }
        makeSession = environment.makeInspectionSession
        phase = finishedDrive.map(Phase.finished) ?? .recording
    }

    var clockText: String { DriveFormatting.clock(elapsedSeconds: snapshot.elapsedSeconds) }
    var distanceText: String { DriveFormatting.kilometers(snapshot.distanceMeters) }

    func count(of kind: IssueKind) -> Int { snapshot.counts[kind, default: 0] }

    /// Starts recording once; later calls do nothing.
    func start() {
        guard task == nil, phase == .recording else { return }
        let session = makeSession()
        task = Task { [weak self] in
            do {
                let drive = try await session.run { self?.snapshot = $0 }
                self?.phase = .finished(drive)
            } catch {
                self?.phase = .failed(error.localizedDescription)
            }
        }
    }

    /// Stops recording; the session then returns the finished drive.
    func end() {
        task?.cancel()
    }
}
