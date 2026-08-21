import Foundation

/// Current thread section for the model.
public struct ProvenanceSessionWorkModelThread: Codable, Equatable, Sendable {
    /// Observed provider thread identity.
    public let identity: ProvenanceFactualSessionProjectionProviderThreadIdentity

    /// PE-owned semantic thread intent.
    public let intent: ProvenanceSessionWorkModelSemanticField

    /// Creates a thread section.
    ///
    /// - Parameters:
    ///   - identity: Observed provider thread identity.
    ///   - intent: PE-owned semantic thread intent.
    public init(
        identity: ProvenanceFactualSessionProjectionProviderThreadIdentity,
        intent: ProvenanceSessionWorkModelSemanticField
    ) {
        self.identity = identity
        self.intent = intent
    }
}
