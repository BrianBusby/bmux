import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// Bound the scanned session history and returned items. These observations
    /// are historical evidence, not a current plan or proof of source coverage.
    func recentProposedPlanObservations(sessionID: String) throws -> [ProvenanceFactualProposedPlanObservation] {
        let query = try database.prepare("""
            SELECT sequence, id FROM (
                SELECT sequence, id, event_type FROM provenance_events
                WHERE session_id = ? ORDER BY sequence DESC LIMIT 5000
            ) WHERE event_type = ? ORDER BY sequence DESC LIMIT 50
            """)
        defer { query.finalize() }
        try query.bind(sessionID, at: 1)
        try query.bind(ProvenanceEventType.codingAgentProposedPlanObserved.rawValue, at: 2)
        var observations: [ProvenanceFactualProposedPlanObservation] = []
        while try query.step() {
            guard let id = query.string(at: 1), let event = try event(id: id),
                  event.sessionID == sessionID,
                  let proposal = event.payload.codingAgentProposedPlan,
                  proposal.sessionID == sessionID else { continue }
            observations.append(ProvenanceFactualProposedPlanObservation(
                id: id, sequence: query.int(at: 0), timestamp: event.timestamp, proposal: proposal
            ))
        }
        return observations
    }

    /// Reads event-ledger entries scoped to one coding-agent session.
    ///
    /// Turn-outcome projection uses this path so appending evidence for one active
    /// session does not decode the full local PE ledger.
    func eventLedgerEntries(sessionID: String, throughSequence: Int?) throws -> [ProvenanceEventLedgerEntry] {
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
