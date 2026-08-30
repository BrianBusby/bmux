import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func artifactCollisionRepositoryIdentity(
        artifact: ProvenanceSessionOutcomeArtifact,
        outcome: ProvenanceSessionOutcome,
        sessionID: String
    ) throws -> (keys: Set<String>, evidence: [ProvenanceArtifactCollisionEvidenceReference]) {
        var keys = Set<String>()
        var evidence: [ProvenanceArtifactCollisionEvidenceReference] = []

        if let fileChangeID = artifact.artifact.fileChangeID,
           let fileChange = try artifactCollisionFileChange(id: fileChangeID) {
            keys.formUnion(try artifactCollisionRepositoryKeys(
                repositoryID: fileChange.repositoryID,
                repositoryPath: nil
            ))
            if let worktree = try worktree(id: fileChange.worktreeID) {
                keys.formUnion(try artifactCollisionRepositoryKeys(
                    repositoryID: worktree.repositoryID,
                    repositoryPath: nil
                ))
            }
            return (keys, [])
        }

        if let boundary = artifactCollisionSourceTurnBoundary(artifact: artifact, outcome: outcome) {
            keys.formUnion(try artifactCollisionRepositoryKeys(
                repositoryID: boundary.repositoryID,
                repositoryPath: boundary.repositoryPath
            ))
            evidence += artifactCollisionEvidence(
                boundary.evidence,
                sessionID: sessionID,
                turnID: artifact.sourceTurnID
            )
        }

        return (keys, uniqueArtifactCollisionEvidence(evidence))
    }

    func artifactCollisionSourceTurnBoundary(
        artifact: ProvenanceSessionOutcomeArtifact,
        outcome: ProvenanceSessionOutcome
    ) -> ProvenanceTurnOutcomeRepositoryBoundary? {
        outcome.turnOutcomes.first { turnOutcome in
            turnOutcome.turnID == artifact.sourceTurnID
                && turnOutcome.projection.revisionID == artifact.sourceTurnOutcomeRevisionID
        }?.repositoryBoundary
    }

    func artifactCollisionFileChange(id: String) throws -> ProvenanceFileChangeRecord? {
        let query = try database.prepare(
            """
            SELECT
                id,
                change_set_id,
                repository_id,
                worktree_id,
                path,
                status,
                before_hash,
                after_hash,
                attribution_source,
                attribution_confidence,
                updated_at_seconds
            FROM provenance_file_changes
            WHERE id = ?
            """
        )
        defer { query.finalize() }

        try query.bind(id, at: 1)
        guard try query.step(),
              let id = query.string(at: 0),
              let changeSetID = query.string(at: 1),
              let repositoryID = query.string(at: 2),
              let worktreeID = query.string(at: 3),
              let path = query.string(at: 4),
              let status = query.string(at: 5),
              let sourceRawValue = query.string(at: 8),
              let source = ProvenanceSource(rawValue: sourceRawValue),
              let confidenceRawValue = query.string(at: 9),
              let confidence = ProvenanceConfidence(rawValue: confidenceRawValue) else {
            return nil
        }

        return ProvenanceFileChangeRecord(
            id: id,
            changeSetID: changeSetID,
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            path: path,
            status: status,
            beforeHash: query.string(at: 6),
            afterHash: query.string(at: 7),
            attributionSource: source,
            attributionConfidence: confidence,
            updatedAt: Date(timeIntervalSince1970: query.double(at: 10) ?? 0)
        )
    }

    func artifactCollisionRepositoryKeys(
        repositoryID: String?,
        repositoryPath: String?
    ) throws -> Set<String> {
        var keys = Set<String>()
        if let repositoryID {
            keys.insert("repository_id:\(repositoryID)")
            if let repository = try repository(id: repositoryID) {
                keys.formUnion(relatedSessionRepositoryKeys(repository))
            }
        }
        if let repositoryPath {
            keys.insert("repository_path:\(repositoryPath)")
        }
        return keys
    }
}
