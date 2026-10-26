import Foundation

/// Version 1 keeps the current and eight uncited historical payloads per owner, plus exact citations and pins.
extension ProvenanceSQLiteRepository {
    func recordOutcomeCitations(sourceRevisionID: String, json: String) throws {
        guard try schemaVersion() >= 29 else { return }
        let value = try JSONSerialization.jsonObject(with: Data(json.utf8))
        var revisionIDs = Set<String>()
        Self.collectRevisionIDs(in: value, into: &revisionIDs)
        revisionIDs.remove(sourceRevisionID)
        let insert = try database.prepare(
            "INSERT OR IGNORE INTO provenance_outcome_revision_citations (source_revision_id, target_revision_id) VALUES (?, ?)"
        )
        defer { insert.finalize() }
        for revisionID in revisionIDs.sorted() {
            try insert.bind(sourceRevisionID, at: 1)
            try insert.bind(revisionID, at: 2)
            _ = try insert.step()
            insert.reset()
        }
    }

    private static func collectRevisionIDs(in value: Any, into result: inout Set<String>) {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if key.hasSuffix("RevisionID"), let id = child as? String, !id.isEmpty {
                    result.insert(id)
                } else if key.hasSuffix("RevisionIDs"), let ids = child as? [String] {
                    result.formUnion(ids.filter { !$0.isEmpty })
                } else {
                    collectRevisionIDs(in: child, into: &result)
                }
            }
        } else if let array = value as? [Any] {
            for child in array { collectRevisionIDs(in: child, into: &result) }
        }
    }

    func retireSupersededOutcomePayloads(sessionIDs: Set<String>, turnIDs: Set<String>) throws {
        guard try schemaVersion() >= 29 else { return }
        for sessionID in sessionIDs.sorted() {
            try retireOldestUncitedPayload(
                ownerID: sessionID,
                revisionTable: "provenance_coding_agent_session_outcome_revisions",
                ownerColumn: "session_id",
                currentTable: "provenance_coding_agent_session_outcomes"
            )
        }
        for turnID in turnIDs.sorted() {
            try retireOldestUncitedPayload(
                ownerID: turnID,
                revisionTable: "provenance_coding_agent_turn_outcome_revisions",
                ownerColumn: "turn_id",
                currentTable: "provenance_coding_agent_turn_outcomes"
            )
        }
    }

    private func retireOldestUncitedPayload(
        ownerID: String,
        revisionTable: String,
        ownerColumn: String,
        currentTable: String
    ) throws {
        let candidate = try database.prepare(
            """
            SELECT r.id FROM \(revisionTable) r
            WHERE r.\(ownerColumn) = ? AND r.outcome_json <> ''
              AND source_watermark_sequence >
                  (SELECT legacy_event_watermark FROM provenance_outcome_retention_state WHERE policy_version = 1)
              AND NOT EXISTS (SELECT 1 FROM provenance_legacy_outcome_revision_ids legacy WHERE legacy.revision_id = r.id)
              AND NOT EXISTS (SELECT 1 FROM provenance_outcome_revision_pins p WHERE p.revision_id = r.id)
              AND NOT EXISTS (SELECT 1 FROM provenance_outcome_revision_citations c WHERE c.target_revision_id = r.id)
              AND NOT EXISTS (SELECT 1 FROM \(currentTable) latest WHERE latest.latest_revision_id = r.id)
            ORDER BY r.source_watermark_sequence DESC, r.id DESC
            LIMIT 1 OFFSET 8
            """
        )
        defer { candidate.finalize() }
        try candidate.bind(ownerID, at: 1)
        guard try candidate.step(), let revisionID = candidate.string(at: 0) else { return }

        let protected = try database.prepare(
            """
            SELECT EXISTS(SELECT 1 FROM \(currentTable) WHERE latest_revision_id = ?)
                OR EXISTS(SELECT 1 FROM provenance_outcome_revision_pins WHERE revision_id = ?)
                OR EXISTS(SELECT 1 FROM provenance_outcome_revision_citations WHERE target_revision_id = ?)
            """
        )
        defer { protected.finalize() }
        for index in 1...3 { try protected.bind(revisionID, at: Int32(index)) }
        guard try protected.step(), protected.int(at: 0) == 0 else { return }

        let retire = try database.prepare("UPDATE \(revisionTable) SET outcome_json = '' WHERE id = ? AND outcome_json <> ''")
        defer { retire.finalize() }
        try retire.bind(revisionID, at: 1)
        _ = try retire.step()
        let removeCitations = try database.prepare(
            "DELETE FROM provenance_outcome_revision_citations WHERE source_revision_id = ?"
        )
        defer { removeCitations.finalize() }
        try removeCitations.bind(revisionID, at: 1)
        _ = try removeCitations.step()
    }

    /// Protects an exact revision that another durable citation must continue to resolve.
    func pinOutcomeRevision(_ revisionID: String, reason: String, now: Date = Date()) throws {
        let insert = try database.prepare(
            "INSERT OR IGNORE INTO provenance_outcome_revision_pins (revision_id, reason, pinned_at_seconds) VALUES (?, ?, ?)"
        )
        defer { insert.finalize() }
        try insert.bind(revisionID, at: 1)
        try insert.bind(reason, at: 2)
        try insert.bind(now.timeIntervalSince1970, at: 3)
        _ = try insert.step()
    }
}
