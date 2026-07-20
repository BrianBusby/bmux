import Foundation

struct CLIProvenanceExplanation: Equatable {
    let requestedPath: String
    let repositoryPath: String
    let relativePath: String
    let found: Bool
    let reason: String?
    let fileStatus: String?
    let attributionSource: String?
    let attributionConfidence: String?
    let updatedAt: TimeInterval?
    let worktree: [String: AnyHashable]
    let repository: [String: AnyHashable]
    let changeSet: [String: AnyHashable]?
    let checkpoint: [String: AnyHashable]?
    let contribution: [String: AnyHashable]?
    let session: [String: AnyHashable]?
    let workItem: [String: AnyHashable]?

    init(
        requestedPath: String,
        repositoryPath: String,
        relativePath: String,
        found: Bool,
        reason: String?,
        fileStatus: String?,
        attributionSource: String?,
        attributionConfidence: String?,
        updatedAt: TimeInterval?,
        worktree: [String: AnyHashable],
        repository: [String: AnyHashable],
        changeSet: [String: AnyHashable]?,
        checkpoint: [String: AnyHashable]?,
        contribution: [String: AnyHashable]?,
        session: [String: AnyHashable]?,
        workItem: [String: AnyHashable]?
    ) {
        self.requestedPath = requestedPath
        self.repositoryPath = repositoryPath
        self.relativePath = relativePath
        self.found = found
        self.reason = reason
        self.fileStatus = fileStatus
        self.attributionSource = attributionSource
        self.attributionConfidence = attributionConfidence
        self.updatedAt = updatedAt
        self.worktree = worktree
        self.repository = repository
        self.changeSet = changeSet
        self.checkpoint = checkpoint
        self.contribution = contribution
        self.session = session
        self.workItem = workItem
    }

    init(
        target: CLIProvenanceResolvedTarget,
        response: ProvenanceFileExplanationResponse,
        worktree: WorkProvenanceWorktreeRecord,
        repository: WorkProvenanceRepositoryRecord?,
        noFileReason: String
    ) {
        let explanation = response.explanation
        self.init(
            requestedPath: target.requestedPath,
            repositoryPath: target.repositoryRoot,
            relativePath: target.relativePath,
            found: response.found,
            reason: response.found ? nil : noFileReason,
            fileStatus: explanation?.fileChange.status,
            attributionSource: explanation?.fileChange.attributionSource.rawValue,
            attributionConfidence: explanation?.fileChange.attributionConfidence.rawValue,
            updatedAt: explanation?.fileChange.updatedAt.timeIntervalSince1970,
            worktree: Self.worktreePayload(explanation?.worktree ?? worktree),
            repository: Self.repositoryPayload(
                explanation?.repository ?? repository,
                fallbackRepositoryID: worktree.repositoryID,
                fallbackPath: worktree.path
            ),
            changeSet: Self.changeSetPayload(explanation?.changeSet),
            checkpoint: Self.checkpointPayload(explanation?.checkpoint),
            contribution: Self.contributionPayload(explanation?.contribution),
            session: Self.sessionPayload(explanation?.session),
            workItem: Self.workItemPayload(explanation?.workItem)
        )
    }

    var payload: [String: Any] {
        var result: [String: Any] = [
            "found": found,
            "requested_path": requestedPath,
            "repository_path": repositoryPath,
            "relative_path": relativePath,
            "worktree": dictionaryPayload(worktree),
            "repository": dictionaryPayload(repository)
        ]
        result["reason"] = reason ?? NSNull()
        result["file_status"] = fileStatus ?? NSNull()
        result["attribution_source"] = attributionSource ?? NSNull()
        result["attribution_confidence"] = attributionConfidence ?? NSNull()
        result["updated_at"] = updatedAt ?? NSNull()
        result["change_set"] = optionalDictionaryPayload(changeSet)
        result["checkpoint"] = optionalDictionaryPayload(checkpoint)
        result["contribution"] = optionalDictionaryPayload(contribution)
        result["session"] = optionalDictionaryPayload(session)
        result["work_item"] = optionalDictionaryPayload(workItem)
        return result
    }

    private func optionalDictionaryPayload(_ value: [String: AnyHashable]?) -> Any {
        guard let value else { return NSNull() }
        return dictionaryPayload(value)
    }

    private func dictionaryPayload(_ value: [String: AnyHashable]) -> [String: Any] {
        value.reduce(into: [String: Any]()) { partial, item in
            partial[item.key] = item.value
        }
    }

    private static func worktreePayload(_ worktree: WorkProvenanceWorktreeRecord) -> [String: AnyHashable] {
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
        _ repository: WorkProvenanceRepositoryRecord?,
        fallbackRepositoryID: String,
        fallbackPath: String
    ) -> [String: AnyHashable] {
        compactPayload([
            "id": repository?.id ?? fallbackRepositoryID,
            "path": repository?.path ?? fallbackPath,
            "remote_slug": repository?.remoteSlug
        ])
    }

    private static func changeSetPayload(_ changeSet: WorkProvenanceChangeSetRecord?) -> [String: AnyHashable]? {
        optionalPayload([
            "id": changeSet?.id,
            "summary": changeSet?.summary,
            "diff_fingerprint": changeSet?.diffFingerprint,
            "created_at": changeSet?.createdAt.timeIntervalSince1970
        ])
    }

    private static func checkpointPayload(_ checkpoint: WorkProvenanceCheckpointRecord?) -> [String: AnyHashable]? {
        optionalPayload([
            "id": checkpoint?.id,
            "summary": checkpoint?.summary,
            "status": checkpoint?.status,
            "validation_state": checkpoint?.validationState,
            "semantic_confidence": checkpoint?.semanticConfidence.rawValue,
            "freshness": checkpoint?.freshness,
            "created_at": checkpoint?.createdAt.timeIntervalSince1970
        ])
    }

    private static func contributionPayload(_ contribution: WorkProvenanceContributionRecord?) -> [String: AnyHashable]? {
        optionalPayload([
            "id": contribution?.id,
            "declared_intent": contribution?.declaredIntent,
            "status": contribution?.status,
            "assignment_confidence": contribution?.assignmentConfidence.rawValue,
            "updated_at": contribution?.updatedAt.timeIntervalSince1970
        ])
    }

    private static func sessionPayload(_ session: WorkProvenanceSessionRecord?) -> [String: AnyHashable]? {
        optionalPayload([
            "id": session?.id,
            "agent_kind": session?.agentKind,
            "workspace_id": session?.workspaceID,
            "surface_id": session?.surfaceID,
            "status": session?.status,
            "cwd": session?.cwd,
            "updated_at": session?.updatedAt.timeIntervalSince1970
        ])
    }

    private static func workItemPayload(_ workItem: WorkProvenanceWorkItemRecord?) -> [String: AnyHashable]? {
        optionalPayload([
            "id": workItem?.id,
            "title": workItem?.title,
            "status": workItem?.status,
            "updated_at": workItem?.updatedAt.timeIntervalSince1970
        ])
    }

    private static func optionalPayload(_ values: [String: AnyHashable?]) -> [String: AnyHashable]? {
        let payload = compactPayload(values)
        return payload["id"] == nil ? nil : payload
    }

    private static func compactPayload(_ values: [String: AnyHashable?]) -> [String: AnyHashable] {
        values.reduce(into: [String: AnyHashable]()) { partial, item in
            if let value = item.value {
                partial[item.key] = value
            }
        }
    }
}
