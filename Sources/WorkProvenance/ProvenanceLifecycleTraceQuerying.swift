import Foundation

/// Internal contract-shaped query surface for provenance lifecycle telemetry.
protocol ProvenanceLifecycleTraceQuerying: Sendable {
    /// Returns bounded lifecycle-ingestion trace records.
    ///
    /// - Parameter request: Query parameters for the requested trace list.
    /// - Returns: Operational telemetry records matching the filters.
    func lifecycleTraces(
        _ request: ProvenanceLifecycleTraceListRequest
    ) async throws -> ProvenanceLifecycleTraceListResponse
}
