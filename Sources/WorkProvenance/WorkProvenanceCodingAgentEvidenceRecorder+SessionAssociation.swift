import Foundation
import ProvenanceEngineContracts

extension WorkProvenanceCodingAgentEvidenceRecorder {
    func workspaceCodingAgentSessionAssociation(
        stableWorkspaceID: UUID,
        sessionID: String,
        rawSessionID: String?,
        surfaceID: String?,
        repositoryID: String?,
        worktreeID: String?,
        currentDirectory: String?,
        sourcePath: String,
        observedAt: Date,
        promptObservedAt: Date?,
        stage: String,
        reasonCode: String?,
        confidence: ProvenanceConfidence
    ) -> ProvenanceWorkspaceCodingAgentSessionAssociationRecord {
        _ = confidence
        let normalizedAgentKind = "codex"
        return ProvenanceWorkspaceCodingAgentSessionAssociationRecord(
            id: stableIDFactory.workspaceCodingAgentSessionAssociationID(
                stableWorkspaceID: stableWorkspaceID,
                agentKind: normalizedAgentKind,
                sessionID: sessionID
            ),
            workspaceID: stableWorkspaceID.uuidString,
            sessionID: sessionID,
            agentKind: normalizedAgentKind,
            rawSessionID: trimmedNonEmpty(rawSessionID),
            canonicalSessionID: sessionID,
            surfaceID: trimmedNonEmpty(surfaceID),
            repositoryID: repositoryID,
            worktreeID: worktreeID,
            currentDirectory: trimmedNonEmpty(currentDirectory),
            sourcePath: sourcePath,
            stage: stage,
            reasonCode: reasonCode,
            retryable: true,
            firstObservedAt: observedAt,
            promptObservedAt: promptObservedAt,
            lastObservedAt: observedAt,
            lastTransitionAt: observedAt
        )
    }
}
