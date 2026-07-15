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
