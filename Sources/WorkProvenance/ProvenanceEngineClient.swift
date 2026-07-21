import Foundation

/// Internal contract-shaped client for provenance engine queries used by bmux.
protocol ProvenanceEngineClient: Sendable {
    /// Appends one immutable provenance event.
    ///
    /// - Parameter request: Event append request.
    /// - Returns: Response describing the accepted event.
    func appendEvent(_ request: ProvenanceAppendEventRequest) async throws -> ProvenanceAppendEventResponse

    /// Returns a bounded session tree rooted at the requested session.
    ///
    /// - Parameter request: Query parameters for the requested session tree.
    /// - Returns: A domain response containing sessions, relationships, and identities.
    func sessionTree(_ request: ProvenanceSessionTreeRequest) async throws -> ProvenanceSessionTreeResponse

    /// Returns focused provenance context for a repository-relative file path.
    ///
    /// - Parameter request: File explanation query parameters.
    /// - Returns: A bounded file-explanation response.
    func fileExplanation(_ request: ProvenanceFileExplanationRequest) async throws -> ProvenanceFileExplanationResponse

    /// Returns provenance worktrees in current-state query order.
    ///
    /// - Parameter request: Query parameters for the worktree list.
    /// - Returns: A domain response containing worktrees and linked repositories.
    func worktrees(_ request: ProvenanceWorktreeListRequest) async throws -> ProvenanceWorktreeListResponse

    /// Returns the bounded current provenance context for one Git worktree.
    ///
    /// - Parameter request: Query parameters for the current context.
    /// - Returns: A domain response containing current worktree, session, file, and validation context.
    func currentContext(_ request: ProvenanceCurrentContextRequest) async throws
        -> ProvenanceCurrentContextResponse
}
