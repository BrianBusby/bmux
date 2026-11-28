import Foundation

extension ProvenanceSQLiteRepository {
    private static let turnClaimPaths: [(turn: String, session: String)] = [
        ("codingAgentTurn.id", "codingAgentTurn.sessionID"),
        ("codingAgentPrompt.turnID", "codingAgentPrompt.sessionID"),
        ("codingAgentPlanUpdate.turnID", "codingAgentPlanUpdate.sessionID"),
        ("codingAgentCommand.turnID", "codingAgentCommand.sessionID"),
        ("codingAgentReasoningSummary.turnID", "codingAgentReasoningSummary.sessionID"),
        ("codingAgentAssistantMessage.turnID", "codingAgentAssistantMessage.sessionID"),
        ("codingAgentFileChangeAttribution.turnID", "codingAgentFileChangeAttribution.sessionID"),
    ]

    /// Finds disputed IDs from ledger claims rather than the overwriteable turn projection.
    func unresolvedTurnClaims(sessionID: String) throws -> (ids: Set<String>, watermark: Int?) {
        var candidates = Set(try codingAgentTurnIDs(sessionID: sessionID, limit: nil))
        let turnExpressions = Self.turnClaimPaths.map { "json_extract(payload_json, '$.\($0.turn)')" }
        let envelopeQuery = try database.prepare("""
            SELECT \(turnExpressions.joined(separator: ", "))
            FROM provenance_events
            WHERE session_id = ? AND json_valid(payload_json)
            """)
        defer { envelopeQuery.finalize() }
        try envelopeQuery.bind(sessionID, at: 1)
        while try envelopeQuery.step() {
            for column in turnExpressions.indices {
                if let turnID = envelopeQuery.string(at: Int32(column)), !turnID.isEmpty {
                    candidates.insert(turnID)
                }
            }
        }

        for paths in Self.turnClaimPaths {
            let turnExpression = "json_extract(payload_json, '$.\(paths.turn)')"
            let sessionExpression = "json_extract(payload_json, '$.\(paths.session)')"
            let query = try database.prepare("""
                SELECT \(turnExpression) FROM provenance_events
                WHERE json_valid(payload_json) AND \(turnExpression) IS NOT NULL
                  AND \(sessionExpression) IS NOT NULL AND \(sessionExpression) = ?
                """)
            defer { query.finalize() }
            try query.bind(sessionID, at: 1)
            while try query.step() {
                if let turnID = query.string(at: 0), !turnID.isEmpty { candidates.insert(turnID) }
            }
        }
        var unresolved: Set<String> = []
        var watermark: Int?
        for turnID in candidates {
            let claim = try conflictingTurnClaim(turnID)
            guard claim.unresolved else { continue }
            unresolved.insert(turnID)
            if let sequence = claim.watermark { watermark = max(watermark ?? sequence, sequence) }
        }
        return (unresolved, watermark)
    }

    /// Returns the latest known sort time for disputed turns no longer in this session's projection.
    func displacedTurnSortTime(sessionID: String, turnIDs: Set<String>) throws -> Double? {
        var latest: Double?
        for turnID in turnIDs {
            let query = try database.prepare("""
                SELECT COALESCE(json_extract(payload_json, '$.codingAgentTurn.startedAt'),
                                json_extract(payload_json, '$.codingAgentTurn.updatedAt'))
                FROM provenance_events
                WHERE json_valid(payload_json)
                  AND json_extract(payload_json, '$.codingAgentTurn.id') IS NOT NULL
                  AND json_extract(payload_json, '$.codingAgentTurn.id') = ?
                  AND (session_id = ? OR json_extract(payload_json, '$.codingAgentTurn.sessionID') = ?)
                ORDER BY sequence DESC LIMIT 1
                """)
            defer { query.finalize() }
            try query.bind(turnID, at: 1)
            try query.bind(sessionID, at: 2)
            try query.bind(sessionID, at: 3)
            guard try query.step(), let time = query.double(at: 0) else { return nil }
            latest = max(latest ?? time, time)
        }
        return latest
    }

    struct ProviderTurnClaim: Hashable {
        let provider: String
        let providerTurnID: String
    }

    /// Returns nil when a disputed turn lacks a usable provider identity.
    func disputedProviderTurnClaims(_ turnIDs: Set<String>) throws -> Set<ProviderTurnClaim>? {
        var result: Set<ProviderTurnClaim> = []
        for turnID in turnIDs {
            let query = try database.prepare("""
                SELECT json_extract(payload_json, '$.codingAgentTurn.provider'),
                       json_extract(payload_json, '$.codingAgentTurn.providerTurnID')
                FROM provenance_events
                WHERE json_valid(payload_json)
                  AND json_extract(payload_json, '$.codingAgentTurn.id') IS NOT NULL
                  AND json_extract(payload_json, '$.codingAgentTurn.id') = ?
                """)
            defer { query.finalize() }
            try query.bind(turnID, at: 1)
            var found = false
            while try query.step() {
                guard let provider = query.string(at: 0), !provider.isEmpty,
                      let providerTurnID = query.string(at: 1), !providerTurnID.isEmpty else { return nil }
                found = true
                result.insert(ProviderTurnClaim(provider: provider, providerTurnID: providerTurnID))
            }
            if !found { return nil }
        }
        return result
    }

    func hasConflictingTurnClaims(_ turnID: String) throws -> Bool {
        try conflictingTurnClaim(turnID).unresolved
    }

    private func conflictingTurnClaim(_ turnID: String) throws -> (unresolved: Bool, watermark: Int?) {
        var owners: Set<String> = []
        var missingOwner = false
        var watermark: Int?
        for paths in Self.turnClaimPaths {
            let turnExpression = "json_extract(payload_json, '$.\(paths.turn)')"
            let sessionExpression = "json_extract(payload_json, '$.\(paths.session)')"
            let query = try database.prepare("""
                SELECT \(sessionExpression), session_id, sequence FROM provenance_events
                WHERE json_valid(payload_json) AND \(turnExpression) IS NOT NULL AND \(turnExpression) = ?
                """)
            defer { query.finalize() }
            try query.bind(turnID, at: 1)
            while try query.step() {
                if let claimed = query.string(at: 0), !claimed.isEmpty {
                    owners.insert(claimed)
                } else {
                    missingOwner = true
                }
                if let envelope = query.string(at: 1), !envelope.isEmpty { owners.insert(envelope) }
                let sequence = query.int(at: 2)
                watermark = max(watermark ?? sequence, sequence)
            }
        }
        return (missingOwner || owners.count > 1, watermark)
    }
}
