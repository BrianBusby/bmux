import Foundation
import ProvenanceEngineContracts
import Testing

@Suite
struct RelatedSessionContractTests {
    @Test
    func relatedSessionResponseRoundTripsThroughJSON() throws {
        let session = ProvenanceSessionRecord(
            id: "session-related",
            agentKind: "codex",
            worktreeID: "worktree-1",
            status: "completed",
            startedAt: Self.timestamp,
            updatedAt: Self.timestamp
        )
        let evidence = ProvenanceRelatedSessionEvidenceReference(
            kind: "worktree",
            id: "worktree-1",
            projectionRevisionID: "worktree-revision-1",
            projectionWatermark: 7,
            field: "worktree"
        )
        let brief = ProvenanceRelatedSessionBrief(
            sessionID: session.id,
            session: session,
            externalIdentities: [],
            providerThreadIdentities: [],
            repositoryBoundaries: [],
            worktreeBoundaries: [
                ProvenanceRelatedSessionWorktreeBoundary(
                    id: "boundary-1",
                    repositoryID: "repository-1",
                    repositoryPath: "/repos/example",
                    worktreeID: "worktree-1",
                    worktreePath: "/repos/example",
                    branch: "main",
                    head: "abc123",
                    cwd: "/repos/example",
                    evidence: [evidence]
                ),
            ],
            lifecycleState: "completed",
            completionState: "completed",
            sessionOutcomeRevisionID: "session-outcome-revision-1",
            sessionOutcomeProjection: nil,
            outcomeBrief: nil,
            relationshipReasons: [
                ProvenanceRelatedSessionRelationshipReason(
                    kind: .sameWorktree,
                    targetValue: "worktree_id:worktree-1",
                    relatedValue: "worktree_id:worktree-1",
                    evidence: [evidence],
                    observedAt: Self.timestamp
                ),
            ],
            freshness: ProvenanceRelatedSessionFreshness(
                relationshipEvidenceWatermark: 7,
                relationshipObservedAt: Self.timestamp,
                sessionOutcomeGeneratedAt: Self.timestamp,
                sessionWorkModelLatestSemanticInferenceCreatedAt: nil,
                projectionGeneratedAt: Self.timestamp,
                state: "available"
            ),
            semanticFields: [],
            sessionWorkModelRevision: nil,
            evidence: [evidence],
            completeness: ProvenanceRelatedSessionCompleteness(
                status: "partial",
                evaluatedThroughSequence: 7,
                fields: [
                    ProvenanceRelatedSessionAvailability(
                        field: "relationship_reasons",
                        status: "observed",
                        evidence: [evidence]
                    ),
                ],
                notes: ["contract round trip"]
            )
        )
        let response = ProvenanceRelatedSessionResponse(
            found: true,
            targetSessionID: "session-target",
            projection: ProvenanceRelatedSessionProjection(
                targetSessionID: "session-target",
                targetSession: session,
                targetSessionOutcomeProjection: nil,
                targetSessionWorkModelRevision: nil,
                projection: ProvenanceRelatedSessionProjectionMetadata(
                    revisionID: "related-session-revision-1",
                    projectionRuleID: "deterministic_related_sessions",
                    projectionRuleVersion: "1",
                    requestFingerprint: "related-session-request-1",
                    contentFingerprint: "related-session-fingerprint-1",
                    resultLimit: 10,
                    exclusionLimit: 10,
                    updatedAfter: nil,
                    sourceEvidenceWatermark: 7,
                    generatedAt: Self.timestamp
                ),
                relatedSessions: [brief],
                excludedCandidates: [],
                completeness: ProvenanceRelatedSessionCompleteness(
                    status: "partial",
                    evaluatedThroughSequence: 7,
                    fields: [],
                    notes: []
                )
            )
        )

        let decoded = try Self.roundTrip(response)

        #expect(decoded == response)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.projection?.relatedSessions.first?.relationshipReasons.first?.kind == .sameWorktree)
    }

    private static let timestamp = Date(timeIntervalSince1970: 1_234)

    private static func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(Value.self, from: data)
    }
}
