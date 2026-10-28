import Foundation
import SQLite3

extension ProvenanceSQLiteRepository {
    /// Indexes exact stored revision citations before legacy payloads can be retired.
    /// An interrupted transaction leaves the legacy gate closed.
    func indexLegacyOutcomeCitations() throws {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            for (table, column) in [
                ("provenance_coding_agent_session_outcome_revisions", "outcome_json"),
                ("provenance_related_session_revisions", "projection_json"),
                ("provenance_artifact_collision_revisions", "projection_json"),
            ] {
                let rows = try database.prepare("SELECT id, \(column) FROM \(table) WHERE \(column) <> ''")
                defer { rows.finalize() }
                while try rows.step() {
                    guard let id = rows.string(at: 0), let json = rows.string(at: 1) else { continue }
                    try autoreleasepool {
                        try recordOutcomeCitations(sourceRevisionID: id, json: json)
                    }
                }
            }
            try database.execute(
                "UPDATE provenance_outcome_retention_state SET legacy_citations_indexed = 1 WHERE policy_version = 1"
            )
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    /// Estimates or retires at most `batchSize` redundant payloads while retaining their metadata rows.
    /// The event ledger and current projections are never candidates.
    func pruneOutcomePayloads(dryRun: Bool, batchSize: Int = 100) throws -> ProvenanceOutcomePruneReport {
        if dryRun {
            return try pruneOutcomePayloadsInTransaction(dryRun: true, batchSize: batchSize)
        }
        // Lock before selecting candidates so a concurrent citation or current-revision update
        // cannot invalidate the set between the safety check and payload retirement.
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let report = try pruneOutcomePayloadsInTransaction(dryRun: false, batchSize: batchSize)
            try database.execute("COMMIT")
            return report
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    private func legacyPayloadByteCount(table: String, id: String) throws -> Int64 {
        let query = try database.prepare("SELECT outcome_json FROM \(table) WHERE id = ?")
        defer { query.finalize() }
        try query.bind(id, at: 1)
        guard try query.step(), let payload = query.string(at: 0) else {
            throw ProvenanceSQLiteError.sqlite(message: "candidate outcome payload missing")
        }
        return Int64(payload.utf8.count)
    }

    private func pruneOutcomePayloadsInTransaction(
        dryRun: Bool, batchSize: Int
    ) throws -> ProvenanceOutcomePruneReport {
        let state = try database.prepare(
            "SELECT legacy_citations_indexed, legacy_event_watermark FROM provenance_outcome_retention_state WHERE policy_version = 1"
        )
        defer { state.finalize() }
        guard try state.step(), state.int(at: 0) == 1 || state.int(at: 1) == 0 else {
            throw ProvenanceSQLiteError.sqlite(message: "legacy outcome citations must be indexed before pruning")
        }

        // SQLite 3.43+ reads a column's UTF-8 byte length from record metadata.
        let supportsOctetLength = sqlite3_libversion_number() >= 3_043_000
        var candidates: [(table: String, id: String, bytes: Int64)] = []
        for (table, owner, current) in [
            ("provenance_coding_agent_session_outcome_revisions", "session_id", "provenance_coding_agent_session_outcomes"),
            ("provenance_coding_agent_turn_outcome_revisions", "turn_id", "provenance_coding_agent_turn_outcomes"),
        ] {
            let hasPayload = supportsOctetLength
                ? "octet_length(r.outcome_json) > 0"
                : "r.outcome_json <> ''"
            let byteCount = supportsOctetLength ? "octet_length(r.outcome_json)" : "0"
            let query = try database.prepare(
                """
                WITH eligible AS (
                    SELECT r.id,
                           row_number() OVER (PARTITION BY r.\(owner)
                                              ORDER BY r.source_watermark_sequence DESC, r.id DESC) AS ordinal
                    FROM \(table) r
                    WHERE \(hasPayload)
                      AND NOT EXISTS (SELECT 1 FROM \(current) c WHERE c.latest_revision_id = r.id)
                      AND NOT EXISTS (SELECT 1 FROM provenance_outcome_revision_pins p WHERE p.revision_id = r.id)
                      AND NOT EXISTS (SELECT 1 FROM provenance_outcome_revision_citations c WHERE c.target_revision_id = r.id)
                )
                SELECT eligible.id, \(byteCount)
                FROM eligible JOIN \(table) r ON r.id = eligible.id
                WHERE eligible.ordinal > 8 LIMIT ?
                """
            )
            defer { query.finalize() }
            try query.bind(max(1, batchSize) - candidates.count, at: 1)
            while try query.step() {
                guard let id = query.string(at: 0) else { continue }
                let bytes: Int64
                if supportsOctetLength {
                    bytes = Int64(query.int(at: 1))
                } else {
                    bytes = try legacyPayloadByteCount(table: table, id: id)
                }
                candidates.append((table, id, bytes))
            }
            if candidates.count >= batchSize { break }
        }
        let bytes = candidates.reduce(Int64.zero) { $0 + $1.bytes }
        guard !dryRun, !candidates.isEmpty else {
            return ProvenanceOutcomePruneReport(
                policyVersion: 1, candidateRows: candidates.count, candidateBytes: bytes, prunedRows: 0
            )
        }

        for candidate in candidates {
            let retire = try database.prepare(
                "UPDATE \(candidate.table) SET outcome_json = '' WHERE id = ? AND outcome_json <> ''"
            )
            defer { retire.finalize() }
            try retire.bind(candidate.id, at: 1)
            _ = try retire.step()
            let citations = try database.prepare(
                "DELETE FROM provenance_outcome_revision_citations WHERE source_revision_id = ?"
            )
            defer { citations.finalize() }
            try citations.bind(candidate.id, at: 1)
            _ = try citations.step()
        }
        return ProvenanceOutcomePruneReport(
            policyVersion: 1, candidateRows: candidates.count, candidateBytes: bytes, prunedRows: candidates.count
        )
    }
}
