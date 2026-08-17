import Foundation

/// Records normalized session lifecycle events.
public protocol ProvenanceSessionLifecycleRecording: Sendable {
    /// Records a normalized lifecycle transition.
    ///
    /// - Parameter request: Normalized lifecycle request supplied by a client adapter.
    /// - Returns: Bounded response describing the accepted event or persistence failure.
    func recordSessionLifecycle(
        _ request: ProvenanceSessionLifecycleRequest
    ) async -> ProvenanceSessionLifecycleResponse

    /// Builds the append-only lifecycle event for a normalized request.
    ///
    /// - Parameter request: Normalized lifecycle request supplied by a client adapter.
    /// - Returns: Event that would be appended for the lifecycle transition.
    /// - Throws: An implementation-defined error when the event cannot be built.
    func sessionLifecycleEvent(
        for request: ProvenanceSessionLifecycleRequest
    ) async throws -> ProvenanceEvent
}

public extension ProvenanceSessionLifecycleRecording {
    /// Records a normalized child-session lifecycle transition.
    ///
    /// - Parameter request: Normalized lifecycle request supplied by a client adapter.
    /// - Returns: Bounded response describing the accepted event or persistence failure.
    @available(*, deprecated, renamed: "recordSessionLifecycle")
    func recordSubsessionLifecycle(
        _ request: ProvenanceSubsessionLifecycleRequest
    ) async -> ProvenanceSubsessionLifecycleResponse {
        await recordSessionLifecycle(request.sessionLifecycleRequest).subsessionLifecycleResponse
    }

    /// Builds the append-only lifecycle event for a normalized child-session request.
    ///
    /// - Parameter request: Normalized lifecycle request supplied by a client adapter.
    /// - Returns: Event that would be appended for the lifecycle transition.
    /// - Throws: An implementation-defined error when the event cannot be built.
    @available(*, deprecated, renamed: "sessionLifecycleEvent")
    func subsessionLifecycleEvent(
        for request: ProvenanceSubsessionLifecycleRequest
    ) async throws -> ProvenanceEvent {
        try await sessionLifecycleEvent(for: request.sessionLifecycleRequest)
    }
}

/// Records normalized child-session lifecycle events.
@available(*, deprecated, renamed: "ProvenanceSessionLifecycleRecording")
public typealias ProvenanceSubsessionLifecycleRecording = ProvenanceSessionLifecycleRecording
