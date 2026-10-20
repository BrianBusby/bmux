import Foundation

/// Session activity directly verified from lifecycle, prompt, or turn evidence.
public struct ProvenanceWorkspaceSessionSummary: Codable, Equatable, Sendable, Identifiable {
    /// The observed PE session projection.
    public let session: ProvenanceSessionRecord
    /// Latest accepted lifecycle, prompt, or turn activity; nil when unobserved.
    public let lastActivityAt: Date?

    /// Stable PE session identity.
    public var id: String { session.id }

    /// Creates a summary with an independently verified activity timestamp.
    ///
    /// - Parameters:
    ///   - session: Observed PE session projection.
    ///   - lastActivityAt: Latest verified work event, when known.
    public init(session: ProvenanceSessionRecord, lastActivityAt: Date?) {
        self.session = session
        self.lastActivityAt = lastActivityAt
    }
}
