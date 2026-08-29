import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func relatedSessionRevisionResponse(
        targetSessionID: String,
        revisionID: String
    ) throws -> ProvenanceRelatedSessionResponse {
        guard let projection = try relatedSessionRevision(
            targetSessionID: targetSessionID,
            revisionID: revisionID
        ) else {
            return ProvenanceRelatedSessionResponse(
                found: false,
                reason: "no_revision",
                targetSessionID: targetSessionID,
                projection: nil
            )
        }
        return ProvenanceRelatedSessionResponse(
            found: true,
            targetSessionID: targetSessionID,
            projection: projection
        )
    }

    func insertRelatedSessionRevision(
        _ projection: ProvenanceRelatedSessionProjection,
        projectionJSON: String
    ) throws {
        let insert = try database.prepare(
            """
            INSERT INTO provenance_related_session_revisions (
                id,
                target_session_id,
                request_fingerprint,
                projection_rule_id,
                projection_rule_version,
                result_limit,
                exclusion_limit,
                updated_after_seconds,
                source_watermark_sequence,
                content_fingerprint,
                projection_json,
                created_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        try insert.bind(projection.projection.exclusionLimit, at: 7)
        try insert.bind(projection.projection.updatedAfter?.timeIntervalSince1970, at: 8)
        try bindRelatedSessionOptionalInt(projection.projection.sourceEvidenceWatermark, to: insert, at: 9)
        try insert.bind(projection.projection.contentFingerprint, at: 10)
        try insert.bind(projectionJSON, at: 11)
        try insert.bind(projection.projection.generatedAt?.timeIntervalSince1970, at: 12)
        _ = try insert.step()
    }

    func upsertLatestRelatedSession(
        _ projection: ProvenanceRelatedSessionProjection
    ) throws {
        let upsert = try database.prepare(
            """
            INSERT INTO provenance_related_sessions (
                target_session_id,
                request_fingerprint,
                latest_revision_id,
                projection_rule_id,
                projection_rule_version,
                result_limit,
                exclusion_limit,
                updated_after_seconds,
                latest_evaluated_sequence,
                updated_at_seconds
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(target_session_id, request_fingerprint) DO UPDATE SET
                latest_revision_id = excluded.latest_revision_id,
                projection_rule_id = excluded.projection_rule_id,
                projection_rule_version = excluded.projection_rule_version,
                result_limit = excluded.result_limit,
                exclusion_limit = excluded.exclusion_limit,
                updated_after_seconds = excluded.updated_after_seconds,
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
        try upsert.bind(projection.projection.exclusionLimit, at: 7)
        try upsert.bind(projection.projection.updatedAfter?.timeIntervalSince1970, at: 8)
        try bindRelatedSessionOptionalInt(projection.projection.sourceEvidenceWatermark, to: upsert, at: 9)
        try upsert.bind(projection.projection.generatedAt?.timeIntervalSince1970, at: 10)
        _ = try upsert.step()
    }

    func relatedSessionRevision(
        targetSessionID: String,
        revisionID: String
    ) throws -> ProvenanceRelatedSessionProjection? {
        let query = try database.prepare(
            """
            SELECT projection_json
            FROM provenance_related_session_revisions
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
        return try payloadDecoder.decode(ProvenanceRelatedSessionProjection.self, from: data)
    }

    func relatedSessionLatestLedgerSequence() throws -> Int? {
        let query = try database.prepare("SELECT MAX(sequence) FROM provenance_events")
        defer { query.finalize() }
        guard try query.step() else { return nil }
        return query.double(at: 0).map(Int.init)
    }

    func relatedSessionEventTimestamp(sequence: Int?) throws -> Date? {
        guard let sequence else { return nil }
        let query = try database.prepare("SELECT timestamp_seconds FROM provenance_events WHERE sequence = ?")
        defer { query.finalize() }
        try query.bind(sequence, at: 1)
        guard try query.step() else { return nil }
        return query.double(at: 0).map { Date(timeIntervalSince1970: $0) }
    }

    func bindRelatedSessionOptionalInt(
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
