import Foundation

/// Describes the current health and supported capabilities of a Provenance Engine client.
///
/// This value is transport-neutral: an in-process client and a later daemon-backed
/// client can return the same contract shape.
public struct ProvenanceEngineHealth: Codable, Equatable, Sendable {
    /// The contract schema version for this health payload.
    public var schemaVersion: Int

    /// The current operational status of the engine client.
    public var status: ProvenanceEngineHealthStatus

    /// The semantic version or build version reported by the engine implementation.
    public var version: String

    /// The authoritative capabilities this engine client currently supports.
    public var capabilities: [ProvenanceEngineCapability]

    /// Creates a transport-neutral health response.
    ///
    /// - Parameters:
    ///   - schemaVersion: The contract schema version for this health payload. Defaults to `1`.
    ///   - status: The current operational status of the engine client.
    ///   - version: The semantic version or build version reported by the engine implementation.
    ///   - capabilities: The authoritative capabilities this engine client currently supports.
    public init(
        schemaVersion: Int = 1,
        status: ProvenanceEngineHealthStatus,
        version: String,
        capabilities: [ProvenanceEngineCapability]
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.version = version
        self.capabilities = capabilities
    }
}
