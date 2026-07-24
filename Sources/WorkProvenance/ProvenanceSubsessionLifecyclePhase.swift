import Foundation

/// Lifecycle phase for a child agent session observed by a client adapter.
enum ProvenanceSubsessionLifecyclePhase: String, Codable, Equatable, Sendable {
    /// A child session started.
    case started

    /// A child session stopped.
    case stopped
}
