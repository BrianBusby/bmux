import Foundation

/// Bounded operational telemetry response for lifecycle-ingestion traces.
struct ProvenanceLifecycleTraceListResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    let schemaVersion: Int

    /// Whether any lifecycle-ingestion traces matched the query.
    let found: Bool

    /// Stable reason code when `found` is false.
    let reason: String?

    /// Matching lifecycle-ingestion pipeline runs.
    let runs: [ProvenancePipelineRunRecord]

    /// Stage executions linked to the returned runs.
    let stages: [ProvenancePipelineStageExecutionRecord]

    /// Identity-resolution attempts linked to the returned runs.
    let identityResolutions: [ProvenanceIdentityResolutionRecord]

    /// Projection-lineage records linked to the returned runs.
    let projectionLineage: [ProvenanceProjectionLineageRecord]

    /// Creates a lifecycle-trace response.
    init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        runs: [ProvenancePipelineRunRecord],
        stages: [ProvenancePipelineStageExecutionRecord],
        identityResolutions: [ProvenanceIdentityResolutionRecord],
        projectionLineage: [ProvenanceProjectionLineageRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.runs = runs
        self.stages = stages
        self.identityResolutions = identityResolutions
        self.projectionLineage = projectionLineage
    }
}
