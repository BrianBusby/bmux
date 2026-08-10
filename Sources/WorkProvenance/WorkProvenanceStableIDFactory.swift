import CryptoKit
import Foundation

/// Builds stable identifiers and fingerprints for observed provenance records.
struct WorkProvenanceStableIDFactory: Sendable {
    /// Stable repository identifier for a repository root path.
    func repositoryID(repositoryRoot: String) -> String {
        id(prefix: "repository", value: normalizedPath(repositoryRoot))
    }

    /// Stable worktree identifier for a worktree root path.
    func worktreeID(repositoryRoot: String) -> String {
        id(prefix: "worktree", value: normalizedPath(repositoryRoot))
    }

    /// Stable file-change identifier for a file path within a worktree.
    func fileChangeID(worktreeID: String, path: String) -> String {
        id(prefix: "file", value: "\(worktreeID)\n\(path)")
    }

    /// Stable change-set identifier for a worktree fingerprint.
    func changeSetID(worktreeID: String, fingerprint: String) -> String {
        id(prefix: "changeset", value: "\(worktreeID)\n\(fingerprint)")
    }

    /// Stable workspace-display identifier for a restart-stable workspace id.
    func workspaceDisplayID(stableWorkspaceID: UUID) -> String {
        "workspace-display-\(stableWorkspaceID.uuidString.lowercased())"
    }

    /// Stable event identifier for a workspace-display observation.
    func workspaceDisplayEventID(stableWorkspaceID: UUID, fingerprint: String) -> String {
        id(prefix: "event", value: "workspace-display\n\(stableWorkspaceID.uuidString.lowercased())\n\(fingerprint)")
    }

    /// Fingerprint for the Git state represented by a snapshot.
    func fingerprint(for snapshot: WorkProvenanceGitSnapshot) -> String {
        let fileLines = snapshot.statusEntries
            .map { "\($0.status)\t\($0.path)\t\($0.previousPath ?? "")" }
            .joined(separator: "\n")
        let payload = [
            normalizedPath(snapshot.repositoryRoot),
            snapshot.commonDirectory ?? "",
            snapshot.remoteSlug ?? "",
            snapshot.branch ?? "",
            snapshot.headCommit ?? "",
            snapshot.isDirty ? "dirty" : "clean",
            fileLines
        ].joined(separator: "\n")
        return "git-status-\(digest(payload))"
    }

    /// Fingerprint for workspace display metadata that PE should project as current state.
    func workspaceDisplayFingerprint(
        stableWorkspaceID: UUID,
        title: String,
        titleSource: String?,
        currentDirectory: String,
        branch: String?,
        pullRequestNumber: Int?,
        pullRequestURL: String?,
        pullRequestStatus: String?,
        pullRequestBranch: String?,
        pullRequestIsStale: Bool,
        gitSnapshot: WorkProvenanceGitSnapshot?,
        ticketIDs: [String]
    ) -> String {
        let payload = [
            stableWorkspaceID.uuidString.lowercased(),
            title,
            titleSource ?? "",
            currentDirectory,
            gitSnapshot.map { normalizedPath($0.repositoryRoot) } ?? "",
            gitSnapshot?.remoteSlug ?? "",
            branch ?? gitSnapshot?.branch ?? "",
            pullRequestNumber.map { "\($0)" } ?? "",
            pullRequestURL ?? "",
            pullRequestStatus ?? "",
            pullRequestBranch ?? "",
            pullRequestIsStale ? "stale" : "fresh",
            ticketIDs.joined(separator: ",")
        ].joined(separator: "\n")
        return "workspace-display-\(digest(payload))"
    }

    func id(prefix: String, value: String) -> String {
        "\(prefix)-\(digest(value).prefix(24))"
    }

    private func digest(_ value: String) -> String {
        let hash = SHA256.hash(data: Data(value.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func normalizedPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return URL(fileURLWithPath: trimmed).standardizedFileURL.path
    }
}
