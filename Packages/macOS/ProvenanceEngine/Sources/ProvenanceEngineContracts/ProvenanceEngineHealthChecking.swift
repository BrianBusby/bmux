import Foundation

/// Provides the minimal health-check surface shared by in-process and future daemon-backed clients.
public protocol ProvenanceEngineHealthChecking: Sendable {
    /// Returns the current health and advertised capabilities for the engine client.
    ///
    /// - Returns: A transport-neutral ``ProvenanceEngineHealth`` payload.
    /// - Throws: An implementation-defined error when health cannot be determined.
    func health() async throws -> ProvenanceEngineHealth
}
