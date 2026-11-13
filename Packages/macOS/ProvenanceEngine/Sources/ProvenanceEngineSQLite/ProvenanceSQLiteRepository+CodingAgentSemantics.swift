import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// Computes and commits the canonical deterministic inference pass atomically.
    func publishCodingAgentSessionSemanticInferences(
        _ request: ProvenanceCodingAgentSessionSemanticInferenceRequest
    ) async throws -> ProvenanceCodingAgentSessionSemanticInferenceResponse {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let factual = try factualSessionProjection(
                ProvenanceFactualSessionProjectionRequest(sessionID: request.sessionID, turnLimit: request.turnLimit)
            )
            guard let snapshot = factual.snapshot else {
                try database.execute("COMMIT")
                return ProvenanceCodingAgentSessionSemanticInferenceResponse(
                    found: false, reason: factual.reason ?? "no_session", sessionID: request.sessionID
                )
            }
            let producer = ProvenanceCodingAgentSessionSemanticInferenceProducer(
                producerID: request.producerID, producerVersion: request.producerVersion
            )
            var records: [ProvenanceSemanticInferenceRecord] = []
            var published: [String] = []
            var unchanged: [String] = []
            for candidate in producer.records(for: snapshot, createdAt: request.createdAt) {
                let previous = try semanticInferenceRecords(ProvenanceSemanticInferenceQueryRequest(
                    scope: candidate.scope, scopeID: candidate.scopeID, kind: candidate.kind, limit: 1
                )).records.first
                let resolution = producer.resolve(candidate: candidate, existing: previous)
                let record = resolution.record
                if resolution.unchanged {
                    unchanged.append(record.id)
                } else {
                    try insertSemanticInference(record)
                    for id in record.supersedes { try supersedeSemanticInference(id: id, replacement: record) }
                    published.append(record.id)
                }
                records.append(record)
            }
            try database.execute("COMMIT")
            return ProvenanceCodingAgentSessionSemanticInferenceResponse(
                found: true, sessionID: request.sessionID, factualRevision: snapshot.revision,
                records: records, publishedInferenceIDs: published, unchangedInferenceIDs: unchanged
            )
        } catch {
            let original = error
            try database.execute("ROLLBACK")
            throw original
        }
    }
}
