import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// A bounded read of historical observations. Nil coverage is reserved for
    /// older producers, and no coverage value proves upstream signal availability.
    func recentProposedPlanObservations(sessionID: String) throws
        -> (observations: [ProvenanceFactualProposedPlanObservation], coverage: ProvenanceProposedPlanReadCoverage) {
        let boundary = try database.prepare("""
            SELECT sequence FROM provenance_events WHERE session_id = ?
            ORDER BY sequence DESC LIMIT 1 OFFSET 5000
            """)
        defer { boundary.finalize() }
        try boundary.bind(sessionID, at: 1)
        let scanWindowTruncated = try boundary.step()
        let firstExcluded = scanWindowTruncated ? boundary.int(at: 0) : 0
        let query = try database.prepare("""
            SELECT sequence, substr(id, 1, 257), length(CAST(id AS BLOB)),
                   schema_version, timestamp_seconds,
                   source = 'observed', evidence_origin = 'codex-transcript',
                   typeof(payload_json) = 'text', substr(confidence, 1, 32)
            FROM provenance_events
            WHERE session_id = ? AND sequence > ? AND event_type = ?
            ORDER BY sequence DESC LIMIT 51
            """)
        defer { query.finalize() }
        try query.bind(sessionID, at: 1)
        try query.bind(firstExcluded, at: 2)
        try query.bind(ProvenanceEventType.codingAgentProposedPlanObserved.rawValue, at: 3)
        var observations: [ProvenanceFactualProposedPlanObservation] = []
        var omitted = false
        var candidateCount = 0
        var remainingBytes = 256 * 1024
        while try query.step() {
            candidateCount += 1
            guard candidateCount <= 50 else { omitted = true; break }
            let rowID = query.int(at: 0)
            guard query.int(at: 2) <= 256, let id = query.string(at: 1),
                  query.int(at: 3) == 1, query.int(at: 5) == 1, query.int(at: 6) == 1, query.int(at: 7) == 1,
                  let confidenceText = query.string(at: 8),
                  let confidence = ProvenanceConfidence(rawValue: confidenceText) else {
                omitted = true
                continue
            }
            guard let data = try database.boundedEventPayload(rowID: rowID, maxBytes: min(64 * 1024, remainingBytes)) else {
                omitted = true
                continue
            }
            remainingBytes -= data.count
            let payload: ProvenanceEventPayload
            do { payload = try payloadDecoder.decode(ProvenanceEventPayload.self, from: data) }
            catch is DecodingError { omitted = true; continue }
            guard let proposal = payload.codingAgentProposedPlan,
                  proposal.sessionID == sessionID, proposal.provider == "codex",
                  proposal.providerSessionID != nil, proposal.providerTurnID != nil,
                  proposal.providerItemID != nil else {
                omitted = true
                continue
            }
            observations.append(ProvenanceFactualProposedPlanObservation(
                id: id, sequence: rowID, timestamp: Date(timeIntervalSince1970: query.double(at: 4) ?? 0),
                proposal: proposal, source: .observed, origin: .init(rawValue: "codex-transcript"),
                eventSchemaVersion: 1, confidence: confidence
            ))
        }
        return (observations, .init(scanWindowTruncated: scanWindowTruncated, omittedObservations: omitted))
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
