import Foundation

/// Bounded lineage record for one authoritative projection row derived from a provenance event.
struct ProvenanceProjectionLineageRecord: Equatable, Sendable {
    let projectionLineageID: String
    let pipelineRunID: String
    let stageName: String
    let projectionKind: String
    let sourceEventID: String
    let sourceEventType: String
    let sourceSchemaVersion: Int
    let sourcePayloadHash: String
    let targetTable: String
    let targetEntityKind: String
    let targetEntityID: String
    let operation: String
    let generatorVersion: String
    let confidence: String
    let startedAt: Date
    let endedAt: Date

    var durationMilliseconds: Double {
        max(0, endedAt.timeIntervalSince(startedAt) * 1_000)
    }
}
