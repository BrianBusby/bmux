import Foundation

/// Records normalized child-session lifecycle events.
public protocol ProvenanceSubsessionLifecycleRecording: Sendable {
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
    /// - Throws: An implementation-defined error when the event cannot be built.
    func subsessionLifecycleEvent(
        for request: ProvenanceSubsessionLifecycleRequest
    ) async throws -> ProvenanceEvent
}
