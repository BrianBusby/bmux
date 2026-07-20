import Foundation

/// Request for a bounded provenance lifecycle-trace query.
struct ProvenanceLifecycleTraceListRequest: Codable, Equatable, Sendable {
    /// Maximum number of lifecycle pipeline runs to return.
    let limit: Int?

    /// Optional exact pipeline run identifier filter.
    let pipelineRunID: String?

    /// Optional parent session identifier filter.
    let parentSessionID: String?

    /// Optional child session identifier filter.
    let childSessionID: String?

    /// Optional run status filter.
    let status: String?

    /// Creates a lifecycle-trace query request.
    init(
        limit: Int? = nil,
        pipelineRunID: String? = nil,
        parentSessionID: String? = nil,
        childSessionID: String? = nil,
        status: String? = nil
    ) {
        self.limit = limit
        self.pipelineRunID = pipelineRunID
        self.parentSessionID = parentSessionID
        self.childSessionID = childSessionID
        self.status = status
    }
}
