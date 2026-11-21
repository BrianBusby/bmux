import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// Visits one session's ledger in order without materializing its full contents.
    func forEachEventLedgerEntry(
        sessionID: String, throughSequence: Int?, _ visit: (ProvenanceEventLedgerEntry) throws -> Void
    ) throws {
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
            WHERE session_id = ? AND sequence <= ?
            ORDER BY sequence ASC
            """
        )
        defer { query.finalize() }

        try query.bind(sessionID, at: 1)
        try query.bind(throughSequence ?? Int.max, at: 2)
        while try query.step() {
            guard let id = query.string(at: 1) else {
                throw ProvenanceSQLiteError.sqlite(message: "stored event has invalid id")
            }
            try visit(
                ProvenanceEventLedgerEntry(
                    sequence: query.int(at: 0),
                    event: try event(from: query, id: id, offset: 2)
                )
            )
        }
    }
}
