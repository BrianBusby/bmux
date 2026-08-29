import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func artifactCollisionContentFingerprint(
        requestFingerprint: String,
        target: RelatedSessionProfile,
        relatedProjection: ProvenanceRelatedSessionProjection?,
        candidates: [ProvenanceArtifactCollisionCandidate],
        excludedCandidates: [ProvenanceArtifactCollisionCandidateExclusion]
    ) -> String {
        var parts = [
            "schema=1",
            "request=\(requestFingerprint)",
            "target=\(target.session.id)",
            "target_status=\(target.session.status)",
            "target_outcome=\(target.outcome?.projection.revisionID ?? "")",
            "related_projection=\(relatedProjection?.projection.revisionID ?? "")",
        ]
        for candidate in candidates {
            parts.append("candidate|\(candidate.id)|\(candidate.state.rawValue)")
            parts.append("path|\(candidate.artifactIdentity.normalizedPath)")
            parts.append("repositories|\(candidate.artifactIdentity.repositoryKeys.joined(separator: ","))")
            parts.append([
                "boundary",
                candidate.boundaryComparison.repositoryRelationship,
                candidate.boundaryComparison.worktreeRelationship,
                candidate.boundaryComparison.branchRelationship,
                candidate.boundaryComparison.headRelationship,
                candidate.boundaryComparison.worktreeIDs.joined(separator: ","),
                candidate.boundaryComparison.branches.joined(separator: ","),
                candidate.boundaryComparison.heads.joined(separator: ","),
            ].joined(separator: "|"))
            parts.append([
                "temporal",
                candidate.temporalOverlap.state,
            ].joined(separator: "|"))
            for participant in candidate.participants {
                parts.append([
                    "participant",
                    participant.sessionID,
                    participant.lifecycleState,
                    participant.completionState,
                    participant.sessionOutcomeRevisionID ?? "",
                ].joined(separator: "|"))
                for artifact in participant.matchedArtifacts {
                    parts.append([
                        "artifact",
                        artifact.id,
                        artifact.sourceTurnID,
                        artifact.sourceTurnOutcomeRevisionID,
                        artifact.artifact.path,
                        artifact.artifact.status ?? "",
                        artifact.artifact.fileChangeID ?? "",
                        artifact.artifact.changeSetID ?? "",
                    ].joined(separator: "|"))
                }
                for boundary in participant.repositoryBoundaries {
                    parts.append([
                        "repo-boundary",
                        participant.sessionID,
                        boundary.repositoryID ?? "",
                        boundary.repositoryPath ?? "",
                        boundary.worktreeID ?? "",
                        boundary.worktreePath ?? "",
                        boundary.branch ?? "",
                        boundary.head ?? "",
                    ].joined(separator: "|"))
                }
                for boundary in participant.worktreeBoundaries {
                    parts.append([
                        "worktree-boundary",
                        participant.sessionID,
                        boundary.repositoryID ?? "",
                        boundary.repositoryPath ?? "",
                        boundary.worktreeID ?? "",
                        boundary.worktreePath ?? "",
                        boundary.branch ?? "",
                        boundary.head ?? "",
                    ].joined(separator: "|"))
                }
            }
            for field in candidate.completeness.fields {
                parts.append("availability|\(candidate.id)|\(field.field)|\(field.status)|\(field.reason ?? "")")
            }
        }
        for exclusion in excludedCandidates {
            parts.append([
                "excluded",
                exclusion.sessionID ?? "",
                exclusion.normalizedArtifactPath ?? "",
                exclusion.reason,
            ].joined(separator: "|"))
        }
        return stableIDFactory.id(
            prefix: "artifact-collision-fingerprint",
            value: parts.joined(separator: "\n")
        )
    }

}
