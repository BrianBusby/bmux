import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// Reads semantic message records for one scope.
    ///
    /// - Parameter request: Semantic message query parameters.
    /// - Returns: Matching semantic messages in newest-first order.
    /// - Throws: ``ProvenanceSQLiteError`` when SQLite rejects the read or stored JSON cannot be decoded.
    func semanticMessageRecords(_ request: ProvenanceSemanticMessageQueryRequest) throws
        -> ProvenanceSemanticMessageQueryResponse {
        try database.withReadSnapshot { try readSemanticMessageRecords(request) }
    }

    private func readSemanticMessageRecords(_ request: ProvenanceSemanticMessageQueryRequest) throws
        -> ProvenanceSemanticMessageQueryResponse {
        let rowLimit = request.limit.map { max(0, $0) }
        let filterPhase = request.scope == .session && !request.includeInactive &&
            (request.semanticInferenceKind == nil || request.semanticInferenceKind == ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue)
        let currentPhaseID = try filterPhase
            ? sessionWorkModelSnapshot(.init(sessionID: request.scopeID)).model?.sessionPhase.record?.inferenceID
            : nil
        var sql = """
            SELECT
                id,
                schema_version,
                semantic_inference_id,
                semantic_inference_kind,
                scope,
                scope_id,
                concise_phrase,
                expanded_meaning,
                structured_semantic_payload_json,
                supporting_evidence_refs_json,
                supporting_factual_revision,
                confidence,
                specificity,
                presentation_producer_type,
                presentation_producer_id,
                presentation_producer_version,
                presentation_policy_id,
                presentation_policy_version,
                locale_identifier,
                created_at_seconds,
                supersedes_json,
                superseded_by,
                status
            FROM provenance_semantic_messages
            WHERE scope = ?
              AND scope_id = ?
            """
        if request.semanticInferenceKind != nil {
            sql += "\n  AND semantic_inference_kind = ?"
        }
        if request.semanticInferenceID != nil {
            sql += "\n  AND semantic_inference_id = ?"
        }
        if request.presentationPolicyID != nil {
            sql += "\n  AND presentation_policy_id = ?"
        }
        if !request.includeInactive {
            sql += "\n  AND status = 'active'"
        }
        if filterPhase {
            sql += currentPhaseID == nil
                ? "\n  AND semantic_inference_kind != ?"
                : "\n  AND (semantic_inference_kind != ? OR semantic_inference_id = ?)"
        }
        sql += "\nORDER BY created_at_seconds DESC, rowid DESC"
        if rowLimit != nil {
            sql += "\nLIMIT ?"
        }

        let query = try database.prepare(sql)
        defer { query.finalize() }

        var bindIndex: Int32 = 1
        try query.bind(request.scope.rawValue, at: bindIndex)
        bindIndex += 1
        try query.bind(request.scopeID, at: bindIndex)
        bindIndex += 1
        if let kind = request.semanticInferenceKind {
            try query.bind(kind, at: bindIndex)
            bindIndex += 1
        }
        if let semanticInferenceID = request.semanticInferenceID {
            try query.bind(semanticInferenceID, at: bindIndex)
            bindIndex += 1
        }
        if let presentationPolicyID = request.presentationPolicyID {
            try query.bind(presentationPolicyID, at: bindIndex)
            bindIndex += 1
        }
        if filterPhase {
            try query.bind(ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue, at: bindIndex)
            bindIndex += 1
            if let currentPhaseID {
                try query.bind(currentPhaseID, at: bindIndex)
                bindIndex += 1
            }
        }
        if let rowLimit {
            try query.bind(rowLimit, at: bindIndex)
        }

        var records: [ProvenanceSemanticMessageRecord] = []
        while try query.step() {
            records.append(try semanticMessage(from: query))
        }
        return ProvenanceSemanticMessageQueryResponse(records: records)
    }

}
