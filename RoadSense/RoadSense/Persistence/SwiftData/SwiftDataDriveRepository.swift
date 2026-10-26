//
//  SwiftDataDriveRepository.swift
//  RoadSense
//

import Foundation
import SwiftData
import os

/// The on-device store. All work runs on this actor's own executor, never on the main actor, and
/// every method saves before it returns, so a recorded issue survives a crash right after it.
@ModelActor
actor SwiftDataDriveRepository: DriveRepository {
    private static let logger = Logger(subsystem: "b.held.RoadSense", category: "persistence")

    func save(_ drive: Drive) throws {
        try perform {
            try removeDrive(drive.id)
            let entity = DriveEntity(
                id: drive.id, name: drive.name, startedAt: drive.startedAt, endedAt: drive.endedAt,
                distanceMeters: drive.distanceMeters, statusRaw: drive.status.rawValue,
                routeData: Self.encode(drive.route), syncStateRaw: SyncState.pending.rawValue,
                updatedAt: .now
            )
            modelContext.insert(entity)
            for issue in drive.issues { entity.issues.append(Self.entity(for: issue)) }
        }
    }

    func append(_ issue: DetectedIssue) throws {
        try perform {
            guard let drive = try fetchDrive(issue.driveID) else { throw PersistenceError.saveFailed }
            drive.issues.append(Self.entity(for: issue))
            drive.updatedAt = .now
        }
    }

    func checkpoint(driveID: Drive.ID, endedAt: Date, distanceMeters: Double, route: [Coordinate]) throws {
        try perform {
            guard let drive = try fetchDrive(driveID) else { throw PersistenceError.saveFailed }
            drive.endedAt = endedAt
            drive.distanceMeters = distanceMeters
            drive.routeData = Self.encode(route)
            drive.updatedAt = .now
        }
    }

    func delete(driveID: Drive.ID) throws {
        try perform { try removeDrive(driveID) }
    }

    func recoverUnfinishedDrives() throws -> Int {
        try perform {
            let unfinished = try modelContext.fetch(FetchDescriptor<DriveEntity>(
                predicate: #Predicate { $0.statusRaw == "inProgress" }
            ))
            for drive in unfinished {
                drive.statusRaw = DriveStatus.finished.rawValue
                drive.updatedAt = .now
            }
            return unfinished.count
        }
    }

    func driveSummaries(limit: Int?) throws -> [DriveSummary] {
        try load {
            var descriptor = FetchDescriptor<DriveEntity>(
                predicate: #Predicate { $0.statusRaw == "finished" && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            return try modelContext.fetch(descriptor).map(Self.summary)
        }
    }

    func totals() throws -> HistoryTotals {
        try load {
            let drives = try modelContext.fetch(FetchDescriptor<DriveEntity>(
                predicate: #Predicate { $0.statusRaw == "finished" && $0.deletedAt == nil }
            ))
            return HistoryTotals(driveCount: drives.count, distanceMeters: drives.reduce(0) { $0 + $1.distanceMeters })
        }
    }

    func issues(focus: MapFocus) throws -> [DetectedIssue] {
        try load {
            let drives = try modelContext.fetch(FetchDescriptor<DriveEntity>(
                predicate: #Predicate { $0.statusRaw == "finished" && $0.deletedAt == nil }
            ))
            let selected = drives.filter {
                switch focus {
                case .all: true
                case .drive(let id): $0.id == id
                }
            }
            return selected.flatMap(\.issues)
                .filter { $0.deletedAt == nil }
                .compactMap(Self.issue)
                .sorted { $0.detectedAt < $1.detectedAt }
        }
    }

    // MARK: - Helpers

    /// Runs a write and saves; rolls back and reports `saveFailed` if anything goes wrong.
    private func perform<T>(_ work: () throws -> T) throws -> T {
        do {
            let result = try work()
            try modelContext.save()
            return result
        } catch {
            Self.logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
            modelContext.rollback()
            throw PersistenceError.saveFailed
        }
    }

    private func load<T>(_ work: () throws -> T) throws -> T {
        do {
            return try work()
        } catch {
            Self.logger.error("Load failed: \(error.localizedDescription, privacy: .public)")
            throw PersistenceError.loadFailed
        }
    }

    private func fetchDrive(_ id: UUID) throws -> DriveEntity? {
        try modelContext.fetch(FetchDescriptor<DriveEntity>(predicate: #Predicate { $0.id == id })).first
    }

    private func removeDrive(_ id: UUID) throws {
        if let existing = try fetchDrive(id) { modelContext.delete(existing) }
    }

    // MARK: - Mapping

    private static func encode(_ route: [Coordinate]) -> Data {
        // A route that cannot be encoded is only a missing breadcrumb, never lost issues.
        (try? JSONEncoder().encode(route)) ?? Data()
    }

    private static func decode(_ data: Data) -> [Coordinate] {
        (try? JSONDecoder().decode([Coordinate].self, from: data)) ?? []
    }

    private static func entity(for issue: DetectedIssue) -> IssueEntity {
        let entity = IssueEntity(
            id: issue.id, driveID: issue.driveID, kindRaw: issue.kind.rawValue,
            confidence: issue.confidence, detectedAt: issue.detectedAt,
            syncStateRaw: SyncState.pending.rawValue, updatedAt: .now
        )
        entity.latitude = issue.coordinate?.latitude
        entity.longitude = issue.coordinate?.longitude
        entity.horizontalAccuracy = issue.horizontalAccuracy
        entity.speed = issue.speed
        entity.heading = issue.heading
        entity.place = issue.place
        entity.note = issue.note
        return entity
    }

    private static func issue(_ entity: IssueEntity) -> DetectedIssue? {
        guard let kind = IssueKind(rawValue: entity.kindRaw) else { return nil }
        var coordinate: Coordinate?
        if let latitude = entity.latitude, let longitude = entity.longitude {
            coordinate = Coordinate(latitude: latitude, longitude: longitude)
        }
        return DetectedIssue(
            id: entity.id, driveID: entity.driveID, kind: kind, confidence: entity.confidence,
            detectedAt: entity.detectedAt, coordinate: coordinate,
            horizontalAccuracy: entity.horizontalAccuracy, speed: entity.speed, heading: entity.heading,
            place: entity.place, note: entity.note
        )
    }

    private static func summary(_ drive: DriveEntity) -> DriveSummary {
        var counts: [IssueKind: Int] = [:]
        for issue in drive.issues where issue.deletedAt == nil {
            if let kind = IssueKind(rawValue: issue.kindRaw) { counts[kind, default: 0] += 1 }
        }
        return DriveSummary(
            id: drive.id, name: drive.name, startedAt: drive.startedAt,
            duration: max(0, drive.endedAt.timeIntervalSince(drive.startedAt)),
            distanceMeters: drive.distanceMeters, counts: counts
        )
    }
}
