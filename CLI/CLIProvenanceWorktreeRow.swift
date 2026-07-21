import Foundation

struct CLIProvenanceWorktreeRow: Equatable {
    let id: String
    let repositoryID: String
    let path: String
    let branch: String?
    let currentHEAD: String?
    let isDirty: Bool
    let status: String?
    let lastReconciledAt: Double?
    let updatedAt: Double?
    let repositoryRecordID: String?
    let repositoryPath: String?
    let remoteSlug: String?

    init(
        id: String,
        repositoryID: String,
        path: String,
        branch: String?,
        currentHEAD: String?,
        isDirty: Bool,
        status: String?,
        lastReconciledAt: Double?,
        updatedAt: Double?,
        repositoryRecordID: String?,
        repositoryPath: String?,
        remoteSlug: String?
    ) {
        self.id = id
        self.repositoryID = repositoryID
        self.path = path
        self.branch = branch
        self.currentHEAD = currentHEAD
        self.isDirty = isDirty
        self.status = status
        self.lastReconciledAt = lastReconciledAt
        self.updatedAt = updatedAt
        self.repositoryRecordID = repositoryRecordID
        self.repositoryPath = repositoryPath
        self.remoteSlug = remoteSlug
    }

    init(entry: ProvenanceWorktreeListEntry) {
        self.init(
            id: entry.worktree.id,
            repositoryID: entry.worktree.repositoryID,
            path: entry.worktree.path,
            branch: entry.worktree.branch,
            currentHEAD: entry.worktree.currentHEAD,
            isDirty: entry.worktree.isDirty,
            status: entry.worktree.status,
            lastReconciledAt: entry.worktree.lastReconciledAt?.timeIntervalSince1970,
            updatedAt: entry.worktree.updatedAt.timeIntervalSince1970,
            repositoryRecordID: entry.repository?.id,
            repositoryPath: entry.repository?.path,
            remoteSlug: entry.repository?.remoteSlug
        )
    }

    var payload: [String: AnyHashable] {
        let values: [String: AnyHashable?] = [
            "id": id,
            "repository_id": repositoryID,
            "path": path,
            "branch": branch,
            "current_head": currentHEAD,
            "is_dirty": isDirty,
            "status": status,
            "last_reconciled_at": lastReconciledAt,
            "updated_at": updatedAt
        ]
        return compactPayload(values)
    }

    var repositoryPayload: [String: AnyHashable] {
        let values: [String: AnyHashable?] = [
            "id": repositoryRecordID ?? repositoryID,
            "path": repositoryPath ?? path,
            "remote_slug": remoteSlug
        ]
        return compactPayload(values)
    }

    private func compactPayload(_ values: [String: AnyHashable?]) -> [String: AnyHashable] {
        values.reduce(into: [String: AnyHashable]()) { partial, item in
            if let value = item.value {
                partial[item.key] = value
            }
        }
    }
}
