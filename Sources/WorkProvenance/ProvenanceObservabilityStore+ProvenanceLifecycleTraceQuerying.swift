import Foundation

extension ProvenanceObservabilityStore: ProvenanceLifecycleTraceQuerying {
    func lifecycleTraces(
        _ request: ProvenanceLifecycleTraceListRequest
    ) async throws -> ProvenanceLifecycleTraceListResponse {
        let traces = try lifecycleIngestionRuns(
            limit: request.limit ?? 20,
            pipelineRunID: request.pipelineRunID,
            parentSessionID: request.parentSessionID,
            childSessionID: request.childSessionID,
            status: request.status
        )
        let runs = traces.map(\.run)
        let found = !runs.isEmpty
        return ProvenanceLifecycleTraceListResponse(
            found: found,
            reason: found ? nil : "no_lifecycle_traces",
            runs: runs,
            stages: traces.flatMap(\.stages),
            identityResolutions: traces.flatMap(\.identityResolutions),
            projectionLineage: traces.flatMap(\.projectionLineage)
        )
    }
}
