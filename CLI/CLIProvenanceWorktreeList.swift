import Foundation

struct CLIProvenanceWorktreeList: Equatable {
    let worktrees: [CLIProvenanceWorktreeRow]
    let reason: String?

    init(worktrees: [CLIProvenanceWorktreeRow], reason: String? = nil) {
        self.worktrees = worktrees
        self.reason = reason
    }

    var payload: [String: Any] {
        [
            "count": worktrees.count,
            "reason": reason ?? NSNull(),
            "worktrees": worktrees.map { row in
                [
                    "worktree": dictionaryPayload(row.payload),
                    "repository": dictionaryPayload(row.repositoryPayload)
                ]
            }
        ]
    }

    private func dictionaryPayload(_ value: [String: AnyHashable]) -> [String: Any] {
        value.reduce(into: [String: Any]()) { partial, item in
            partial[item.key] = item.value
        }
    }
}
