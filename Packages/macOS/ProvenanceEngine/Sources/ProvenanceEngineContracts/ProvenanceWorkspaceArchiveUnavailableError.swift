import Foundation

/// The client does not implement the retained workspace archive contract.
public struct ProvenanceWorkspaceArchiveUnavailableError: Error, Sendable {
    /// Creates the explicit unavailable error.
    public init() {}
}
