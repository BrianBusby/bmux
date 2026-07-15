import Foundation

/// One file entry from `git status --porcelain`.
struct WorkProvenanceGitStatusEntry: Equatable, Sendable {
    /// Repository-relative current path.
    let path: String

    /// Normalized status such as `modified`, `added`, `deleted`, or `untracked`.
    let status: String

    /// Previous repository-relative path for renames and copies, when known.
    let previousPath: String?

    /// Creates a Git status entry.
    init(path: String, status: String, previousPath: String? = nil) {
        self.path = path
        self.status = status
        self.previousPath = previousPath
    }
}
