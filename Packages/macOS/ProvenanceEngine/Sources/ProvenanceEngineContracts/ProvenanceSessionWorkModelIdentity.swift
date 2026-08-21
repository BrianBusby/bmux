import Foundation

/// Factual identity for the modeled session.
public struct ProvenanceSessionWorkModelIdentity: Codable, Equatable, Sendable {
    /// Current factual session projection.
    public let session: ProvenanceSessionRecord

    /// Observed provider thread identities for this session.
    public let providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity]

    /// Creates identity metadata.
    ///
    /// - Parameters:
    ///   - session: Current factual session projection record.
    ///   - providerThreadIdentities: Observed provider thread identities for this session.
    public init(
        session: ProvenanceSessionRecord,
        providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity]
    ) {
        self.session = session
        self.providerThreadIdentities = providerThreadIdentities
    }
}
