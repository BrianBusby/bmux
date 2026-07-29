import Foundation
import ProvenanceEngineContracts

struct CLIProvenanceContext: Equatable {
    let found: Bool
    let reason: String?
    let repositoryPath: String
    let worktree: [String: AnyHashable]
    let repository: [String: AnyHashable]
    let activeSessions: [[String: AnyHashable]]
    let dirtyFiles: [[String: AnyHashable]]
    let unattributedChanges: [[String: AnyHashable]]
    let recentCheckpoints: [[String: AnyHashable]]
    let validationRuns: [[String: AnyHashable]]
    let conflicts: [[String: AnyHashable]]

    init(
        found: Bool,
        reason: String?,
        repositoryPath: String,
        worktree: [String: AnyHashable],
        repository: [String: AnyHashable],
        activeSessions: [[String: AnyHashable]],
        dirtyFiles: [[String: AnyHashable]],
        unattributedChanges: [[String: AnyHashable]],
        recentCheckpoints: [[String: AnyHashable]],
        validationRuns: [[String: AnyHashable]],
        conflicts: [[String: AnyHashable]]
    ) {
        self.found = found
        self.reason = reason
        self.repositoryPath = repositoryPath
        self.worktree = worktree
        self.repository = repository
        self.activeSessions = activeSessions
        self.dirtyFiles = dirtyFiles
        self.unattributedChanges = unattributedChanges
        self.recentCheckpoints = recentCheckpoints
        self.validationRuns = validationRuns
        self.conflicts = conflicts
    }

    init(
        response: ProvenanceEngineContracts.ProvenanceCurrentContextResponse,
        fallbackRepositoryPath: String,
        noWorktreeReason: String
    ) {
        let worktree = response.worktree
        let repository = response.repository
        self.init(
            found: response.found,
            reason: response.found ? nil : noWorktreeReason,
            repositoryPath: response.repositoryPath,
            worktree: worktree.map(Self.worktreePayload) ?? ["path": fallbackRepositoryPath],
            repository: Self.repositoryPayload(
                repository,
                fallbackRepositoryID: worktree?.repositoryID,
                fallbackPath: fallbackRepositoryPath
            ),
            activeSessions: response.activeSessions.map(Self.activeSessionPayload),
            dirtyFiles: response.dirtyFiles.map(Self.fileChangePayload),
            unattributedChanges: response.unattributedChanges.map(Self.fileChangePayload),
            recentCheckpoints: response.recentCheckpoints.map(Self.checkpointPayload),
            validationRuns: response.validationRuns.map(Self.validationRunPayload),
            conflicts: response.conflicts.map(Self.conflictPayload)
        )
    }

    var payload: [String: Any] {
        [
            "found": found,
            "reason": reason ?? NSNull(),
            "repository_path": repositoryPath,
            "worktree": dictionaryPayload(worktree),
            "repository": dictionaryPayload(repository),
            "summary": [
                "active_session_count": activeSessions.count,
                "dirty_file_count": dirtyFiles.count,
                "unattributed_change_count": unattributedChanges.count,
                "recent_checkpoint_count": recentCheckpoints.count,
                "validation_run_count": validationRuns.count,
                "conflict_count": conflicts.count
            ],
            "active_sessions": arrayPayload(activeSessions),
            "dirty_files": arrayPayload(dirtyFiles),
            "unattributed_changes": arrayPayload(unattributedChanges),
            "recent_checkpoints": arrayPayload(recentCheckpoints),
            "validation_runs": arrayPayload(validationRuns),
            "conflicts": arrayPayload(conflicts)
        ]
    }

    private func arrayPayload(_ values: [[String: AnyHashable]]) -> [[String: Any]] {
        values.map(dictionaryPayload)
    }

    private func dictionaryPayload(_ value: [String: AnyHashable]) -> [String: Any] {
        value.reduce(into: [String: Any]()) { partial, item in
            partial[item.key] = item.value
        }
    }

    private static func activeSessionPayload(
        _ row: ProvenanceEngineContracts.ProvenanceCurrentContextSession
    ) -> [String: AnyHashable] {
        compactPayload([
            "id": row.session.id,
            "agent_kind": row.session.agentKind,
            "workspace_id": row.session.workspaceID,
            "surface_id": row.session.surfaceID,
            "status": row.session.status,
            "cwd": row.session.cwd,
            "started_at": row.session.startedAt?.timeIntervalSince1970,
            "updated_at": row.session.updatedAt.timeIntervalSince1970,
            "contribution_id": row.contribution?.id,
            "declared_intent": row.contribution?.declaredIntent,
            "contribution_status": row.contribution?.status,
            "work_item_id": row.workItem?.id,
            "work_item_title": row.workItem?.title,
            "work_item_status": row.workItem?.status
        ])
    }

    private static func fileChangePayload(
        _ row: ProvenanceEngineContracts.ProvenanceCurrentContextFileChange
    ) -> [String: AnyHashable] {
        compactPayload([
            "path": row.fileChange.path,
            "status": row.fileChange.status,
            "attribution_source": row.fileChange.attributionSource.rawValue,
            "attribution_confidence": row.fileChange.attributionConfidence.rawValue,
            "updated_at": row.fileChange.updatedAt.timeIntervalSince1970,
            "change_set_id": row.fileChange.changeSetID,
            "change_set_summary": row.changeSet?.summary,
            "diff_fingerprint": row.changeSet?.diffFingerprint,
            "contribution_id": row.contribution?.id,
            "contribution_status": row.contribution?.status,
            "session_id": row.session?.id,
            "agent_kind": row.session?.agentKind
        ])
    }

    private static func checkpointPayload(
        _ row: ProvenanceEngineContracts.ProvenanceCurrentContextCheckpoint
    ) -> [String: AnyHashable] {
        compactPayload([
            "id": row.checkpoint.id,
            "contribution_id": row.checkpoint.contributionID,
            "sequence": row.checkpoint.sequence,
            "git_head": row.checkpoint.gitHEAD,
            "diff_fingerprint": row.checkpoint.diffFingerprint,
            "summary": row.checkpoint.summary,
            "status": row.checkpoint.status,
            "validation_state": row.checkpoint.validationState,
            "semantic_confidence": row.checkpoint.semanticConfidence.rawValue,
            "freshness": row.checkpoint.freshness,
            "created_at": row.checkpoint.createdAt.timeIntervalSince1970,
            "declared_intent": row.contribution.declaredIntent,
            "contribution_status": row.contribution.status,
            "session_id": row.session?.id,
            "agent_kind": row.session?.agentKind,
            "work_item_id": row.workItem?.id,
            "work_item_title": row.workItem?.title
        ])
    }

    private static func validationRunPayload(
        _ row: ProvenanceEngineContracts.ProvenanceCurrentContextValidationRun
    ) -> [String: AnyHashable] {
        compactPayload([
            "id": row.validationRun.id,
            "checkpoint_id": row.validationRun.checkpointID,
            "contribution_id": row.validationRun.contributionID,
            "command": row.validationRun.command,
            "status": row.validationRun.status,
            "summary": row.validationRun.summary,
            "started_at": row.validationRun.startedAt?.timeIntervalSince1970,
            "ended_at": row.validationRun.endedAt?.timeIntervalSince1970,
            "checkpoint_summary": row.checkpoint?.summary,
            "declared_intent": row.contribution?.declaredIntent,
            "contribution_status": row.contribution?.status
        ])
    }

    private static func conflictPayload(
        _ row: ProvenanceEngineContracts.ProvenanceCurrentContextConflict
    ) -> [String: AnyHashable] {
        compactPayload([
            "path": row.path,
            "active_contribution_count": row.activeContributionCount,
            "contribution_ids": row.contributionIDs,
            "updated_at": row.updatedAt.timeIntervalSince1970
        ])
    }

    private static func worktreePayload(
        _ worktree: ProvenanceEngineContracts.ProvenanceWorktreeRecord
    ) -> [String: AnyHashable] {
        compactPayload([
            "id": worktree.id,
            "repository_id": worktree.repositoryID,
            "path": worktree.path,
            "branch": worktree.branch,
            "current_head": worktree.currentHEAD,
            "is_dirty": worktree.isDirty,
            "status": worktree.status,
            "last_reconciled_at": worktree.lastReconciledAt?.timeIntervalSince1970,
            "updated_at": worktree.updatedAt.timeIntervalSince1970
        ])
    }

    private static func repositoryPayload(
        _ repository: ProvenanceEngineContracts.ProvenanceRepositoryRecord?,
        fallbackRepositoryID: String?,
        fallbackPath: String
    ) -> [String: AnyHashable] {
        compactPayload([
            "id": repository?.id ?? fallbackRepositoryID,
            "path": repository?.path ?? fallbackPath,
            "remote_slug": repository?.remoteSlug
        ])
    }

    private static func compactPayload(_ values: [String: AnyHashable?]) -> [String: AnyHashable] {
        values.reduce(into: [String: AnyHashable]()) { partial, item in
            if let value = item.value {
                partial[item.key] = value
            }
        }
    }
}
