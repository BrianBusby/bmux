import Foundation

/// Represents the operational status reported by a Provenance Engine client.
public enum ProvenanceEngineHealthStatus: String, Codable, Equatable, Sendable {
    /// The engine client can serve its advertised capabilities.
    case available

    /// The engine client is reachable but one or more capabilities may be limited.
    case degraded

    /// The engine client cannot currently serve provenance requests.
    case unavailable
}
