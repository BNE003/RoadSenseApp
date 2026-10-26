//
//  RoadSenseSchema.swift
//  RoadSense
//

import Foundation
import SwiftData

/// The first shipped schema. A change to the stored shape adds `RoadSenseSchemaV2`, a migration
/// stage and a new `typealias` below; it never edits V1.
enum RoadSenseSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [DriveEntity.self, IssueEntity.self] }

    @Model
    nonisolated final class DriveEntity {
        @Attribute(.unique) var id: UUID
        var name: String
        var startedAt: Date
        var endedAt: Date
        var distanceMeters: Double
        var statusRaw: String
        /// JSON-encoded `[Coordinate]`; one value per drive, not one row per GPS fix.
        var routeData: Data
        var syncStateRaw: String
        var updatedAt: Date
        var deletedAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \IssueEntity.drive) var issues: [IssueEntity] = []

        init(
            id: UUID, name: String, startedAt: Date, endedAt: Date, distanceMeters: Double,
            statusRaw: String, routeData: Data, syncStateRaw: String, updatedAt: Date
        ) {
            self.id = id
            self.name = name
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.distanceMeters = distanceMeters
            self.statusRaw = statusRaw
            self.routeData = routeData
            self.syncStateRaw = syncStateRaw
            self.updatedAt = updatedAt
        }
    }

    @Model
    nonisolated final class IssueEntity {
        @Attribute(.unique) var id: UUID
        var driveID: UUID
        var kindRaw: String
        var confidence: Double
        var detectedAt: Date
        var latitude: Double?
        var longitude: Double?
        var horizontalAccuracy: Double?
        var speed: Double?
        var heading: Double?
        var place: String?
        var note: String?
        var syncStateRaw: String
        var updatedAt: Date
        var deletedAt: Date?
        var drive: DriveEntity?

        init(
            id: UUID, driveID: UUID, kindRaw: String, confidence: Double, detectedAt: Date,
            syncStateRaw: String, updatedAt: Date
        ) {
            self.id = id
            self.driveID = driveID
            self.kindRaw = kindRaw
            self.confidence = confidence
            self.detectedAt = detectedAt
            self.syncStateRaw = syncStateRaw
            self.updatedAt = updatedAt
        }
    }
}

typealias DriveEntity = RoadSenseSchemaV1.DriveEntity
typealias IssueEntity = RoadSenseSchemaV1.IssueEntity

enum RoadSenseMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [RoadSenseSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

extension ModelContainer {
    /// The app's store. `inMemory` is for tests.
    static func roadSense(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: RoadSenseSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, migrationPlan: RoadSenseMigrationPlan.self, configurations: [configuration])
    }
}
