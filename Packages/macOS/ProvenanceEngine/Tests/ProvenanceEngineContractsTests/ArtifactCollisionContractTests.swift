import Foundation
import ProvenanceEngineContracts
import Testing

@Suite
struct ArtifactCollisionContractTests {
    @Test
    func artifactCollisionResponseRoundTripsThroughJSON() throws {
        let session = ProvenanceSessionRecord(
            id: "session-target",
            agentKind: "codex",
            worktreeID: "worktree-1",
            status: "active",
            startedAt: Self.timestamp,
            updatedAt: Self.timestamp
        )
        let evidence = ProvenanceArtifactCollisionEvidenceReference(
            kind: "event",
            id: "event-file-attribution-1",
            eventSequence: 7,
            eventType: "coding_agent_file_change_attributed",
            source: .observed,
            evidenceOrigin: .codexSession,
            evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "contract-test"),
            sessionID: session.id,
            turnID: "turn-target",
            field: "coding_agent_file_change_attribution:file-attribution-1",
            sourceState: "available"
        )
        let sessionMetadata = ProvenanceSessionOutcomeProjectionMetadata(
            revisionID: "session-outcome-revision-1",
            projectionRuleID: "deterministic_session_outcome",
            projectionRuleVersion: "1",
            contentFingerprint: "session-outcome-fingerprint-1",
            sourceEvidenceWatermark: 7,
            generatedAt: Self.timestamp
        )
        let turnEvidence = ProvenanceTurnOutcomeEvidenceReference(
            eventID: evidence.id,
            eventSequence: evidence.eventSequence ?? 0,
            eventType: evidence.eventType ?? "",
            source: .observed,
            evidenceOrigin: .codexSession,
            evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "contract-test"),
            recordKind: "coding_agent_file_change_attribution",
            recordID: "file-attribution-1",
            interpretedByRuleVersion: "1",
            sourceState: "available"
        )
        let artifact = ProvenanceSessionOutcomeArtifact(
            id: "session-artifact-1",
            sourceTurnID: "turn-target",
            sourceTurnOutcomeRevisionID: "turn-outcome-revision-1",
            artifact: ProvenanceTurnOutcomeArtifact(
                id: "artifact-1",
                path: "Sources/Shared.swift",
                status: nil,
                fileChangeID: nil,
                changeSetID: nil,
                evidence: [turnEvidence]
            )
        )
        let completeness = ProvenanceArtifactCollisionCompleteness(
            status: "complete",
            evaluatedThroughSequence: 7,
            fields: [
                ProvenanceArtifactCollisionAvailability(
                    field: "matched_artifacts",
                    status: "observed",
                    evidence: [evidence]
                ),
            ],
            notes: ["contract round trip"]
        )
        let participant = ProvenanceArtifactCollisionSessionParticipation(
            id: "participation-1",
            sessionID: session.id,
            session: session,
            lifecycleState: "active",
            completionState: "incomplete",
            sessionOutcomeRevisionID: sessionMetadata.revisionID,
            sessionOutcomeProjection: sessionMetadata,
            matchedArtifacts: [artifact],
            repositoryBoundaries: [],
            worktreeBoundaries: [],
            firstObservedChangedAt: Self.timestamp,
            lastObservedChangedAt: Self.timestamp,
            evidence: [evidence],
            completeness: completeness
        )
        let candidate = ProvenanceArtifactCollisionCandidate(
            id: "candidate-1",
            state: .current,
            artifactIdentity: ProvenanceArtifactCollisionArtifactIdentity(
                id: "artifact-identity-1",
                observedPaths: ["Sources/Shared.swift"],
                normalizedPath: "Sources/Shared.swift",
                repositoryKeys: ["repository_id:repository-1"],
                relationshipKind: "exact_path",
                caseSensitivity: "case_sensitive",
                renameSupport: "unsupported_without_accepted_rename_evidence",
                evidence: [evidence]
            ),
            pathBoundary: ProvenanceArtifactCollisionPathBoundary(
                observedPaths: ["Sources/Shared.swift"],
                normalizedPath: "Sources/Shared.swift",
                pathRelationship: "exact_path",
                repositoryKeys: ["repository_id:repository-1"],
                caseSensitivity: "case_sensitive",
                renameRelationship: "unsupported_without_accepted_rename_evidence",
                evidence: [evidence]
            ),
            participants: [participant],
            boundaryComparison: ProvenanceArtifactCollisionBoundaryComparison(
                repositoryRelationship: "shared_repository",
                worktreeRelationship: "same_worktree",
                branchRelationship: "same_branch",
                headRelationship: "same_head",
                sharedRepositoryKeys: ["repository_id:repository-1"],
                worktreeIDs: ["worktree-1"],
                worktreePaths: ["/repos/example"],
                branches: ["main"],
                heads: ["abc123"],
                evidence: [evidence]
            ),
            temporalOverlap: ProvenanceArtifactCollisionTemporalOverlap(
                state: "temporally_overlapping_edits",
                firstObservedChangedAt: Self.timestamp,
                lastObservedChangedAt: Self.timestamp,
                missingTimestampSessionIDs: [],
                evidence: [evidence]
            ),
            reasons: [
                ProvenanceArtifactCollisionReason(
                    kind: .exactPathOverlap,
                    targetValue: "Sources/Shared.swift",
                    relatedValue: "Sources/Shared.swift",
                    observedAt: Self.timestamp,
                    evidence: [evidence]
                ),
            ],
            freshness: ProvenanceArtifactCollisionFreshness(
                state: .current,
                latestArtifactObservedAt: Self.timestamp,
                staleBefore: nil,
                sourceEvidenceWatermark: 7,
                relatedSessionProjectionRevisionID: "related-session-revision-1",
                relatedSessionProjectionWatermark: 7
            ),
            evidence: [evidence],
            completeness: completeness,
            notes: ["possible collision only"]
        )
        let response = ProvenanceArtifactCollisionResponse(
            found: true,
            targetSessionID: session.id,
            projection: ProvenanceArtifactCollisionProjection(
                targetSessionID: session.id,
                targetSession: session,
                targetSessionOutcomeProjection: sessionMetadata,
                relatedSessionProjection: ProvenanceRelatedSessionProjectionMetadata(
                    revisionID: "related-session-revision-1",
                    projectionRuleID: "deterministic_related_sessions",
                    projectionRuleVersion: "1",
                    requestFingerprint: "related-request-1",
                    contentFingerprint: "related-fingerprint-1",
                    resultLimit: 10,
                    exclusionLimit: 10,
                    updatedAfter: nil,
                    sourceEvidenceWatermark: 7,
                    generatedAt: Self.timestamp
                ),
                projection: ProvenanceArtifactCollisionProjectionMetadata(
                    revisionID: "artifact-collision-revision-1",
                    projectionRuleID: "deterministic_artifact_collision_awareness",
                    projectionRuleVersion: "1",
                    requestFingerprint: "artifact-collision-request-1",
                    contentFingerprint: "artifact-collision-fingerprint-1",
                    resultLimit: 10,
                    relatedSessionLimit: 50,
                    exclusionLimit: 10,
                    artifactPath: "Sources/Shared.swift",
                    normalizedArtifactPath: "Sources/Shared.swift",
                    updatedAfter: nil,
                    staleBefore: nil,
                    sourceEvidenceWatermark: 7,
                    generatedAt: Self.timestamp
                ),
                candidates: [candidate],
                excludedCandidates: [],
                completeness: completeness
            )
        )

        let decoded = try Self.roundTrip(response)

        #expect(decoded == response)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.projection?.candidates.first?.reasons.first?.kind == .exactPathOverlap)
        #expect(decoded.projection?.candidates.first?.evidence.first?.source == .observed)
        #expect(decoded.projection?.candidates.first?.pathBoundary.renameRelationship ==
            "unsupported_without_accepted_rename_evidence")
    }

    @Test
    func artifactCollisionRequestDefaultsAreBounded() {
        let request = ProvenanceArtifactCollisionRequest(targetSessionID: "session-target")

        #expect(request.limit == 10)
        #expect(request.relatedSessionLimit == 50)
        #expect(request.exclusionLimit == 10)
        #expect(request.artifactPath == nil)
        #expect(request.updatedAfter == nil)
        #expect(request.staleBefore == nil)
    }

    @Test
    func artifactCollisionReasonKindRawValuesAreStable() {
        #expect(ProvenanceArtifactCollisionReasonKind.exactPathOverlap.rawValue == "exact_path_overlap")
        #expect(ProvenanceArtifactCollisionReasonKind.sharedRepository.rawValue == "shared_repository")
        #expect(ProvenanceArtifactCollisionReasonKind.differentBranches.rawValue == "different_branches")
        #expect(ProvenanceArtifactCollisionReasonKind.divergentHead.rawValue == "divergent_head")
        #expect(ProvenanceArtifactCollisionReasonKind.unsupportedRenameIdentity.rawValue ==
            "unsupported_rename_identity")
    }

    private static let timestamp = Date(timeIntervalSince1970: 1_234)

    private static func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(Value.self, from: data)
    }
}
