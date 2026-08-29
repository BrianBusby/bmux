import Foundation

/// Deterministic, bounded related-session projection for one target session.
public struct ProvenanceRelatedSessionProjection: Codable, Equatable, Sendable {
    /// Schema version for this projection shape.
    public let schemaVersion: Int

    /// Provenance session identifier used as the relationship target.
    public let targetSessionID: String

    /// Target session projection record.
    public let targetSession: ProvenanceSessionRecord

    /// Exact Session Outcome projection used for the target, when available.
    public let targetSessionOutcomeProjection: ProvenanceSessionOutcomeProjectionMetadata?

    /// Exact SessionWorkModel revision used for the target, when available.
    public let targetSessionWorkModelRevision: ProvenanceSessionWorkModelRevision?

    /// Related-session projection metadata.
    public let projection: ProvenanceRelatedSessionProjectionMetadata

    /// Bounded related-session briefs in deterministic order.
    public let relatedSessions: [ProvenanceRelatedSessionBrief]

    /// Bounded explanations for candidates excluded by request or missing evidence.
    public let excludedCandidates: [ProvenanceRelatedSessionCandidateExclusion]

    /// Completeness state for this projection.
    public let completeness: ProvenanceRelatedSessionCompleteness

    /// Creates a related-session projection.
    public init(
        schemaVersion: Int = 1,
        targetSessionID: String,
        targetSession: ProvenanceSessionRecord,
        targetSessionOutcomeProjection: ProvenanceSessionOutcomeProjectionMetadata?,
        targetSessionWorkModelRevision: ProvenanceSessionWorkModelRevision?,
        projection: ProvenanceRelatedSessionProjectionMetadata,
        relatedSessions: [ProvenanceRelatedSessionBrief],
        excludedCandidates: [ProvenanceRelatedSessionCandidateExclusion],
        completeness: ProvenanceRelatedSessionCompleteness
    ) {
        self.schemaVersion = schemaVersion
        self.targetSessionID = targetSessionID
        self.targetSession = targetSession
        self.targetSessionOutcomeProjection = targetSessionOutcomeProjection
        self.targetSessionWorkModelRevision = targetSessionWorkModelRevision
        self.projection = projection
        self.relatedSessions = relatedSessions
        self.excludedCandidates = excludedCandidates
        self.completeness = completeness
    }
}
