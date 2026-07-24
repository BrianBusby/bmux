import Foundation

/// Legacy bmux-local client for provenance storage paths not yet migrated to the external engine.
protocol BmuxLegacyProvenanceClient: Sendable {
    /// Appends one immutable provenance event.
    ///
    /// - Parameter request: Event append request.
    /// - Returns: Response describing the accepted event.
    func appendEvent(_ request: ProvenanceAppendEventRequest) async throws -> ProvenanceAppendEventResponse

    /// Returns focused provenance context for a repository-relative file path.
    ///
    /// - Parameter request: File explanation query parameters.
    /// - Returns: A bounded file-explanation response.
    func fileExplanation(_ request: ProvenanceFileExplanationRequest) async throws -> ProvenanceFileExplanationResponse

    /// Returns the bounded current provenance context for one Git worktree.
    ///
    /// - Parameter request: Query parameters for the current context.
    /// - Returns: A domain response containing current worktree, session, file, and validation context.
    func currentContext(_ request: ProvenanceCurrentContextRequest) async throws
        -> ProvenanceCurrentContextResponse
}
