import Foundation

/// Lifecycle phase for an agent session observed by a producer.
public enum ProvenanceSessionLifecyclePhase: String, Codable, Equatable, Sendable {
    /// A session started.
    case started

    /// A session stopped.
    case stopped
}
