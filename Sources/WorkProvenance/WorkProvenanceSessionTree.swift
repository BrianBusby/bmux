import Foundation

/// Bounded current-state session tree rooted at one provenance session.
struct WorkProvenanceSessionTree: Equatable, Sendable {
    /// Root session requested by the caller.
    let rootSessionID: String

    /// Sessions included in depth-first relationship order.
    let sessions: [WorkProvenanceSessionRecord]

    /// Parent-child relationships included in tree order.
    let relationships: [WorkProvenanceSessionRelationshipRecord]
}
