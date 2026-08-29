import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func artifactCollisionProjectionCompleteness(
        target: RelatedSessionProfile,
        relatedProjection: ProvenanceRelatedSessionProjection?,
        targetObservation: ArtifactCollisionSessionObservation,
        candidates: [ProvenanceArtifactCollisionCandidate],
        excludedCandidates: [ProvenanceArtifactCollisionCandidateExclusion],
        evaluatedThroughSequence: Int?
    ) -> ProvenanceArtifactCollisionCompleteness {
        let fields = [
            artifactCollisionAvailability(
                field: "target_session_outcome",
                observed: target.outcome != nil,
                reason: "no_target_session_outcome",
                evidence: target.outcome.map { [artifactCollisionEvidence($0)] } ?? []
            ),
            artifactCollisionAvailability(
                field: "related_session_projection",
                observed: relatedProjection != nil,
                reason: "no_related_session_projection",
                evidence: relatedProjection.map { [artifactCollisionEvidence($0)] } ?? []
            ),
            artifactCollisionAvailability(
                field: "target_changed_artifacts",
                observed: !targetObservation.artifactsByPath.isEmpty,
                reason: "no_target_changed_artifacts",
                evidence: targetObservation.evidenceByPath.values.flatMap { $0 }
            ),
            artifactCollisionAvailability(
                field: "collision_candidates",
                observed: !candidates.isEmpty,
                reason: "no_artifact_overlap_candidates",
                evidence: candidates.flatMap(\.evidence)
            ),
            artifactCollisionAvailability(
                field: "candidate_exclusions",
                observed: !excludedCandidates.isEmpty,
                reason: "no_excluded_candidates",
                evidence: excludedCandidates.flatMap(\.evidence)
            ),
            ProvenanceArtifactCollisionAvailability(
                field: "rename_identity",
                status: "not_supported",
                reason: "no_stable_rename_identity_evidence"
            ),
            ProvenanceArtifactCollisionAvailability(
                field: "semantic_conflict",
                status: "not_supported",
                reason: "collision_awareness_does_not_judge_semantic_conflicts"
            ),
        ]
        let requiredFields = fields.filter {
            ["target_session_outcome", "related_session_projection", "target_changed_artifacts", "collision_candidates"]
                .contains($0.field)
        }
        let status = candidates.isEmpty
            ? "empty"
            : (requiredFields.allSatisfy { $0.status == "observed" } ? "complete" : "partial")
        return ProvenanceArtifactCollisionCompleteness(
            status: status,
            evaluatedThroughSequence: evaluatedThroughSequence,
            fields: fields,
            notes: artifactCollisionProjectionNotes()
        )
    }

    func artifactCollisionCandidateCompleteness(
        participants: [ProvenanceArtifactCollisionSessionParticipation],
        sharedRepositoryKeys: [String],
        relatedProjection: ProvenanceRelatedSessionProjection?,
        evaluatedThroughSequence: Int?
    ) -> ProvenanceArtifactCollisionCompleteness {
        let timestampEvidence = participants.flatMap(\.evidence)
        let boundaryEvidence = participants.flatMap { participant in
            participant.repositoryBoundaries.flatMap {
                artifactCollisionEvidence($0, sessionID: participant.sessionID)
            } + participant.worktreeBoundaries.flatMap {
                artifactCollisionEvidence($0, sessionID: participant.sessionID)
            }
        }
        let fields = [
            artifactCollisionAvailability(
                field: "participants",
                observed: participants.count >= 2,
                reason: "not_enough_participants",
                evidence: participants.flatMap(\.evidence)
            ),
            artifactCollisionAvailability(
                field: "matched_artifacts",
                observed: participants.allSatisfy { !$0.matchedArtifacts.isEmpty },
                reason: "missing_matched_artifacts",
                evidence: participants.flatMap(\.evidence)
            ),
            artifactCollisionAvailability(
                field: "shared_repository",
                observed: !sharedRepositoryKeys.isEmpty,
                reason: "missing_shared_repository_identity",
                evidence: boundaryEvidence
            ),
            artifactCollisionAvailability(
                field: "worktree_boundaries",
                observed: participants.allSatisfy {
                    !$0.repositoryBoundaries.isEmpty || !$0.worktreeBoundaries.isEmpty
                },
                reason: "missing_worktree_boundary_evidence",
                evidence: boundaryEvidence
            ),
            artifactCollisionAvailability(
                field: "branch_boundaries",
                observed: participants.allSatisfy {
                    !$0.repositoryBoundaries.compactMap(\.branch).isEmpty
                        || !$0.worktreeBoundaries.compactMap(\.branch).isEmpty
                },
                reason: "missing_branch_evidence",
                evidence: boundaryEvidence
            ),
            artifactCollisionAvailability(
                field: "head_boundaries",
                observed: participants.allSatisfy {
                    !$0.repositoryBoundaries.compactMap(\.head).isEmpty
                        || !$0.worktreeBoundaries.compactMap(\.head).isEmpty
                },
                reason: "missing_head_evidence",
                evidence: boundaryEvidence
            ),
            artifactCollisionAvailability(
                field: "artifact_timestamps",
                observed: participants.allSatisfy { $0.lastObservedChangedAt != nil },
                reason: "missing_artifact_observation_timestamp",
                evidence: timestampEvidence
            ),
            artifactCollisionAvailability(
                field: "related_session_projection",
                observed: relatedProjection != nil,
                reason: "no_related_session_projection",
                evidence: relatedProjection.map { [artifactCollisionEvidence($0)] } ?? []
            ),
            ProvenanceArtifactCollisionAvailability(
                field: "rename_identity",
                status: "not_supported",
                reason: "no_stable_rename_identity_evidence"
            ),
            ProvenanceArtifactCollisionAvailability(
                field: "semantic_conflict",
                status: "not_supported",
                reason: "collision_awareness_does_not_judge_semantic_conflicts"
            ),
        ]
        let requiredFields = fields.filter {
            [
                "participants",
                "matched_artifacts",
                "shared_repository",
                "worktree_boundaries",
                "artifact_timestamps",
                "related_session_projection",
            ].contains($0.field)
        }
        return ProvenanceArtifactCollisionCompleteness(
            status: requiredFields.allSatisfy { $0.status == "observed" } ? "complete" : "partial",
            evaluatedThroughSequence: evaluatedThroughSequence,
            fields: fields,
            notes: artifactCollisionProjectionNotes()
        )
    }

    func artifactCollisionParticipationCompleteness(
        profile: RelatedSessionProfile,
        artifacts: [ProvenanceSessionOutcomeArtifact],
        changedTimes: [Date],
        evidence: [ProvenanceArtifactCollisionEvidenceReference],
        evaluatedThroughSequence: Int?
    ) -> ProvenanceArtifactCollisionCompleteness {
        let boundaryEvidence = profile.repositoryBoundaries.flatMap {
            artifactCollisionEvidence($0, sessionID: profile.session.id)
        } + profile.worktreeBoundaries.flatMap {
            artifactCollisionEvidence($0, sessionID: profile.session.id)
        }
        let fields = [
            artifactCollisionAvailability(
                field: "session_outcome",
                observed: profile.outcome != nil,
                reason: "no_session_outcome",
                evidence: profile.outcome.map { [artifactCollisionEvidence($0)] } ?? []
            ),
            artifactCollisionAvailability(
                field: "matched_artifacts",
                observed: !artifacts.isEmpty,
                reason: "no_matching_artifact",
                evidence: evidence
            ),
            artifactCollisionAvailability(
                field: "repository_or_worktree_boundaries",
                observed: !profile.repositoryBoundaries.isEmpty || !profile.worktreeBoundaries.isEmpty,
                reason: "no_repository_or_worktree_boundary",
                evidence: boundaryEvidence
            ),
            artifactCollisionAvailability(
                field: "artifact_timestamps",
                observed: !changedTimes.isEmpty,
                reason: "missing_artifact_observation_timestamp",
                evidence: evidence
            ),
        ]
        return ProvenanceArtifactCollisionCompleteness(
            status: fields.allSatisfy { $0.status == "observed" } ? "complete" : "partial",
            evaluatedThroughSequence: evaluatedThroughSequence,
            fields: fields,
            notes: artifactCollisionProjectionNotes()
        )
    }

    func artifactCollisionAvailability(
        field: String,
        observed: Bool,
        reason: String,
        evidence: [ProvenanceArtifactCollisionEvidenceReference] = []
    ) -> ProvenanceArtifactCollisionAvailability {
        ProvenanceArtifactCollisionAvailability(
            field: field,
            status: observed ? "observed" : "not_observed",
            reason: observed ? nil : reason,
            evidence: uniqueArtifactCollisionEvidence(evidence)
        )
    }

}
