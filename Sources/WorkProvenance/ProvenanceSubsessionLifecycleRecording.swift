import Foundation

/// Internal contract-shaped recorder for normalized child-session lifecycle events.
protocol ProvenanceSubsessionLifecycleRecording: Sendable {
    /// Records a normalized lifecycle transition.
    ///
    /// - Parameter request: Normalized lifecycle request supplied by a client adapter.
    /// - Returns: Bounded response describing the accepted event or persistence failure.
    func recordSubsessionLifecycle(
        _ request: ProvenanceSubsessionLifecycleRequest
    ) async -> ProvenanceSubsessionLifecycleResponse

    /// Builds the append-only lifecycle event for a normalized request.
    ///
    /// - Parameter request: Normalized lifecycle request supplied by a client adapter.
    /// - Returns: Event that would be appended for the lifecycle transition.
    func subsessionLifecycleEvent(
        for request: ProvenanceSubsessionLifecycleRequest
    ) async throws -> WorkProvenanceEvent
}
