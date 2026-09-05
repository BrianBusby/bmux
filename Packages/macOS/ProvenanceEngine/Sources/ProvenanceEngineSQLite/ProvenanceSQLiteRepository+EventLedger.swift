import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// Reads event-ledger entries scoped to one coding-agent session.
    ///
    /// Turn-outcome projection uses this path so appending evidence for one active
    /// session does not decode the full local PE ledger.
    func eventLedgerEntries(sessionID: String) throws -> [ProvenanceEventLedgerEntry] {
        let query = try database.prepare(
            """
            SELECT
                sequence,
                id,
                schema_version,
                event_type,
                timestamp_seconds,
                repository_id,
                worktree_id,
                session_id,
                contribution_id,
                source,
                confidence,
                payload_json,
                evidence_origin,
                evidence_scope_json
            FROM provenance_events
            WHERE session_id = ?
            ORDER BY sequence ASC
            """
        )
        defer { query.finalize() }

        try query.bind(sessionID, at: 1)
        var entries: [ProvenanceEventLedgerEntry] = []
        while try query.step() {
            guard let id = query.string(at: 1) else {
                throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid id")
            }
            entries.append(
                ProvenanceEventLedgerEntry(
                    sequence: query.int(at: 0),
                    event: try event(from: query, id: id, offset: 2)
                )
            )
        }
        return entries
    }
}
