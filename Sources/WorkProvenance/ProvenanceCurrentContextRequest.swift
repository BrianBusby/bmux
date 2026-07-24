import Foundation

/// Query parameters for the current provenance context of one Git worktree.
struct ProvenanceCurrentContextRequest: Codable, Equatable, Sendable {
    /// Absolute worktree root path resolved by the caller.
    let repositoryPath: String

    /// Maximum active session rows to return.
    let activeSessionLimit: Int

    /// Maximum dirty file rows to return.
    let dirtyFileLimit: Int

    /// Maximum unattributed file-change rows to return.
    let unattributedChangeLimit: Int

    /// Maximum checkpoint rows to return.
    let recentCheckpointLimit: Int

    /// Maximum validation-run rows to return.
    let validationRunLimit: Int

    /// Maximum conflict rows to return.
    let conflictLimit: Int

    /// Creates a current-context query request.
    init(
        repositoryPath: String,
        activeSessionLimit: Int = 10,
        dirtyFileLimit: Int = 25,
        unattributedChangeLimit: Int = 15,
        recentCheckpointLimit: Int = 5,
        validationRunLimit: Int = 5,
        conflictLimit: Int = 10
    ) {
        self.repositoryPath = repositoryPath
        self.activeSessionLimit = activeSessionLimit
        self.dirtyFileLimit = dirtyFileLimit
        self.unattributedChangeLimit = unattributedChangeLimit
        self.recentCheckpointLimit = recentCheckpointLimit
        self.validationRunLimit = validationRunLimit
        self.conflictLimit = conflictLimit
    }
}
