import Foundation

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
}
