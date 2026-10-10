import Foundation
import ProvenanceEngineContracts

/// Reads current materialized outcomes; event append owns their incremental refresh.
extension ProvenanceSQLiteRepository {
    func turnOutcomeRecord(_ request: ProvenanceTurnOutcomeRequest) throws
        -> ProvenanceTurnOutcomeResponse {
        guard try codingAgentTurn(id: request.turnID) != nil else {
            return ProvenanceTurnOutcomeResponse(
                found: false,
                reason: "no_turn",
                turnID: request.turnID,
                outcome: nil
            )
        }

        if let revisionID = request.revisionID {
            return try turnOutcomeRevisionResponse(turnID: request.turnID, revisionID: revisionID)
        }

        if let revisionID = try latestTurnOutcomeRevisionID(turnID: request.turnID) {
            let cached = try turnOutcomeRevisionResponse(turnID: request.turnID, revisionID: revisionID)
            if cached.found { return cached }
        }

        // Older databases and new projection rules can require a one-time rebuild.
        try projectTurnOutcomeIfNeeded(
            turnID: request.turnID,
            latestEventSequence: turnOutcomeLatestLedgerSequence()
        )

        guard let revisionID = try latestTurnOutcomeRevisionID(turnID: request.turnID) else {
            return ProvenanceTurnOutcomeResponse(
                found: false,
                reason: "no_outcome",
                turnID: request.turnID,
                outcome: nil
            )
        }
        return try turnOutcomeRevisionResponse(turnID: request.turnID, revisionID: revisionID)
    }

    private func turnOutcomeRevisionResponse(
        turnID: String,
        revisionID: String
    ) throws -> ProvenanceTurnOutcomeResponse {
        guard let outcome = try turnOutcomeRevision(turnID: turnID, revisionID: revisionID) else {
            return ProvenanceTurnOutcomeResponse(
                found: false,
                reason: "no_revision",
                turnID: turnID,
                outcome: nil
            )
        }
        return ProvenanceTurnOutcomeResponse(
            found: true,
            reason: nil,
            turnID: turnID,
            outcome: outcome
        )
    }

    private func turnOutcomeRevision(turnID: String, revisionID: String) throws -> ProvenanceTurnOutcome? {
        let query = try database.prepare(
            """
            SELECT outcome_json
            FROM provenance_coding_agent_turn_outcome_revisions
            WHERE turn_id = ?
              AND id = ?
            """
        )
        defer { query.finalize() }
        try query.bind(turnID, at: 1)
        try query.bind(revisionID, at: 2)
        guard try query.step(),
              let json = query.string(at: 0),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try payloadDecoder.decode(ProvenanceTurnOutcome.self, from: data)
    }

    private func latestTurnOutcomeRevisionID(turnID: String) throws -> String? {
        let query = try database.prepare(
            """
            SELECT latest_revision_id
            FROM provenance_coding_agent_turn_outcomes
            WHERE turn_id = ?
              AND projection_rule_id = ? AND projection_rule_version = ?
            """
        )
        defer { query.finalize() }
        try query.bind(turnID, at: 1)
        try query.bind(Self.turnOutcomeRuleID, at: 2)
        try query.bind(Self.turnOutcomeRuleVersion, at: 3)
        guard try query.step() else { return nil }
        return query.string(at: 0)
    }

    func sessionOutcomeRecord(_ request: ProvenanceSessionOutcomeRequest) throws
        -> ProvenanceSessionOutcomeResponse {
        guard try session(id: request.sessionID) != nil else {
            return ProvenanceSessionOutcomeResponse(
                found: false,
                reason: "no_session",
                sessionID: request.sessionID,
                outcome: nil
            )
        }

        if let revisionID = request.revisionID {
            return try sessionOutcomeRevisionResponse(
                sessionID: request.sessionID,
                revisionID: revisionID
            )
        }

        if let revisionID = try latestSessionOutcomeRevisionID(sessionID: request.sessionID) {
            let cached = try sessionOutcomeRevisionResponse(sessionID: request.sessionID, revisionID: revisionID)
            if let outcome = cached.outcome, try sessionOutcomeDependenciesAreCurrent(outcome) { return cached }
        }

        // Older databases and new projection rules can require a one-time rebuild.
        try projectSessionOutcomeIfNeeded(
            sessionID: request.sessionID,
            latestEventSequence: sessionOutcomeLatestLedgerSequence()
        )

        guard let revisionID = try latestSessionOutcomeRevisionID(sessionID: request.sessionID) else {
            return ProvenanceSessionOutcomeResponse(
                found: false,
                reason: "no_outcome",
                sessionID: request.sessionID,
                outcome: nil
            )
        }
        return try sessionOutcomeRevisionResponse(
            sessionID: request.sessionID,
            revisionID: revisionID
        )
    }

    /// Checks dependencies without decoding or rewriting historical turn outcomes.
    private func sessionOutcomeDependenciesAreCurrent(_ outcome: ProvenanceSessionOutcome) throws -> Bool {
        let query = try database.prepare("""
            SELECT t.id, o.latest_revision_id
            FROM provenance_coding_agent_turns t
            LEFT JOIN provenance_coding_agent_turn_outcomes o ON o.turn_id = t.id
                AND o.projection_rule_id = ? AND o.projection_rule_version = ?
            WHERE t.session_id = ?
            """)
        defer { query.finalize() }
        try query.bind(Self.turnOutcomeRuleID, at: 1)
        try query.bind(Self.turnOutcomeRuleVersion, at: 2)
        try query.bind(outcome.sessionID, at: 3)
        let revisions = Dictionary(uniqueKeysWithValues: outcome.constituentTurns.map {
            ($0.turnID, $0.turnOutcomeRevisionID)
        })
        var count = 0
        while try query.step() {
            guard let turnID = query.string(at: 0), let revisionID = query.string(at: 1),
                  revisions[turnID] == revisionID else { return false }
            count += 1
        }
        return count == revisions.count
    }

    private func sessionOutcomeRevisionResponse(
        sessionID: String,
        revisionID: String
    ) throws -> ProvenanceSessionOutcomeResponse {
        guard let outcome = try sessionOutcomeRevision(
            sessionID: sessionID,
            revisionID: revisionID
        ) else {
            return ProvenanceSessionOutcomeResponse(
                found: false,
                reason: "no_revision",
                sessionID: sessionID,
                outcome: nil
            )
        }
        return ProvenanceSessionOutcomeResponse(
            found: true,
            reason: nil,
            sessionID: sessionID,
            outcome: outcome
        )
    }

    private func sessionOutcomeRevision(
        sessionID: String,
        revisionID: String
    ) throws -> ProvenanceSessionOutcome? {
        let query = try database.prepare(
            """
            SELECT outcome_json
            FROM provenance_coding_agent_session_outcome_revisions
            WHERE session_id = ?
              AND id = ?
            """
        )
        defer { query.finalize() }
        try query.bind(sessionID, at: 1)
        try query.bind(revisionID, at: 2)
        guard try query.step(),
              let json = query.string(at: 0),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try payloadDecoder.decode(ProvenanceSessionOutcome.self, from: data)
    }

    private func latestSessionOutcomeRevisionID(sessionID: String) throws -> String? {
        let query = try database.prepare(
            """
            SELECT latest_revision_id
            FROM provenance_coding_agent_session_outcomes
            WHERE session_id = ?
              AND projection_rule_id = ? AND projection_rule_version = ?
            """
        )
        defer { query.finalize() }
        try query.bind(sessionID, at: 1)
        try query.bind(Self.sessionOutcomeRuleID, at: 2)
        try query.bind(Self.sessionOutcomeRuleVersion, at: 3)
        guard try query.step() else { return nil }
        return query.string(at: 0)
    }
}
