import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func artifactCollisionRevisionResponse(
        targetSessionID: String,
        revisionID: String
    ) throws -> ProvenanceArtifactCollisionResponse {
        guard let projection = try artifactCollisionRevision(
            targetSessionID: targetSessionID,
            revisionID: revisionID
        ) else {
            return ProvenanceArtifactCollisionResponse(
                found: false,
                reason: "no_revision",
                targetSessionID: targetSessionID,
                projection: nil
            )
        }
        return ProvenanceArtifactCollisionResponse(
            found: true,
            targetSessionID: targetSessionID,
            projection: projection
        )
    }

    func insertArtifactCollisionRevision(
        _ projection: ProvenanceArtifactCollisionProjection,
        projectionJSON: String
    ) throws {
        let insert = try database.prepare(
            """
            INSERT INTO provenance_artifact_collision_revisions (
                id,
                target_session_id,
                request_fingerprint,
                projection_rule_id,
                projection_rule_version,
                result_limit,
                related_session_limit,
                exclusion_limit,
                artifact_path,
                normalized_artifact_path,
                updated_after_seconds,
                stale_before_seconds,
                source_watermark_sequence,
                content_fingerprint,
                projection_json,
                created_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                source_watermark_sequence = excluded.source_watermark_sequence,
                projection_json = excluded.projection_json,
                created_at_seconds = excluded.created_at_seconds
            """
        )
        defer { insert.finalize() }
        try insert.bind(projection.projection.revisionID, at: 1)
        try insert.bind(projection.targetSessionID, at: 2)
        try insert.bind(projection.projection.requestFingerprint, at: 3)
        try insert.bind(projection.projection.projectionRuleID, at: 4)
        try insert.bind(projection.projection.projectionRuleVersion, at: 5)
        try insert.bind(projection.projection.resultLimit, at: 6)
        try insert.bind(projection.projection.relatedSessionLimit, at: 7)
        try insert.bind(projection.projection.exclusionLimit, at: 8)
        try insert.bind(projection.projection.artifactPath, at: 9)
        try insert.bind(projection.projection.normalizedArtifactPath, at: 10)
        try insert.bind(projection.projection.updatedAfter?.timeIntervalSince1970, at: 11)
        try insert.bind(projection.projection.staleBefore?.timeIntervalSince1970, at: 12)
        try bindArtifactCollisionOptionalInt(projection.projection.sourceEvidenceWatermark, to: insert, at: 13)
        try insert.bind(projection.projection.contentFingerprint, at: 14)
        try insert.bind(projectionJSON, at: 15)
        try insert.bind(projection.projection.generatedAt?.timeIntervalSince1970, at: 16)
        _ = try insert.step()
    }

    func upsertLatestArtifactCollision(
        _ projection: ProvenanceArtifactCollisionProjection
    ) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_artifact_collisions (
                target_session_id,
                request_fingerprint,
                latest_revision_id,
                projection_rule_id,
                projection_rule_version,
                result_limit,
                related_session_limit,
                exclusion_limit,
                artifact_path,
                normalized_artifact_path,
                updated_after_seconds,
                stale_before_seconds,
                latest_evaluated_sequence,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(target_session_id, request_fingerprint) DO UPDATE SET
                latest_revision_id = excluded.latest_revision_id,
                projection_rule_id = excluded.projection_rule_id,
                projection_rule_version = excluded.projection_rule_version,
                result_limit = excluded.result_limit,
                related_session_limit = excluded.related_session_limit,
                exclusion_limit = excluded.exclusion_limit,
                artifact_path = excluded.artifact_path,
                normalized_artifact_path = excluded.normalized_artifact_path,
                updated_after_seconds = excluded.updated_after_seconds,
                stale_before_seconds = excluded.stale_before_seconds,
                latest_evaluated_sequence = excluded.latest_evaluated_sequence,
                updated_at_seconds = excluded.updated_at_seconds
            """
        )
        defer { upsert.finalize() }
        try upsert.bind(projection.targetSessionID, at: 1)
        try upsert.bind(projection.projection.requestFingerprint, at: 2)
        try upsert.bind(projection.projection.revisionID, at: 3)
        try upsert.bind(projection.projection.projectionRuleID, at: 4)
        try upsert.bind(projection.projection.projectionRuleVersion, at: 5)
        try upsert.bind(projection.projection.resultLimit, at: 6)
        try upsert.bind(projection.projection.relatedSessionLimit, at: 7)
        try upsert.bind(projection.projection.exclusionLimit, at: 8)
        try upsert.bind(projection.projection.artifactPath, at: 9)
        try upsert.bind(projection.projection.normalizedArtifactPath, at: 10)
        try upsert.bind(projection.projection.updatedAfter?.timeIntervalSince1970, at: 11)
        try upsert.bind(projection.projection.staleBefore?.timeIntervalSince1970, at: 12)
        try bindArtifactCollisionOptionalInt(projection.projection.sourceEvidenceWatermark, to: upsert, at: 13)
        try upsert.bind(projection.projection.generatedAt?.timeIntervalSince1970, at: 14)
        _ = try upsert.step()
    }

    func artifactCollisionRevision(
        targetSessionID: String,
        revisionID: String
    ) throws -> ProvenanceArtifactCollisionProjection? {
        let query = try database.prepare(
            """
            SELECT projection_json
            FROM provenance_artifact_collision_revisions
            WHERE target_session_id = ?
              AND id = ?
            """
        )
        defer { query.finalize() }
        try query.bind(targetSessionID, at: 1)
        try query.bind(revisionID, at: 2)
        guard try query.step(),
              let json = query.string(at: 0),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try payloadDecoder.decode(ProvenanceArtifactCollisionProjection.self, from: data)
    }

    func bindArtifactCollisionOptionalInt(
        _ value: Int?,
        to statement: ProvenanceSQLiteStatement,
        at index: Int32
    ) throws {
        if let value {
            try statement.bind(value, at: index)
        } else {
            try statement.bind(nil as Double?, at: index)
        }
    }
}
