import Foundation

/// Attribution linking completed file-change activity to a coding-agent turn.
public struct ProvenanceCodingAgentFileChangeAttributionRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable file-change attribution identifier.
    public let id: String

    /// Provenance session that owns the file-change activity.
    public let sessionID: String

    /// Provider thread projection identifier, when known.
    public let threadID: String?

    /// Provider turn projection identifier, when known.
    public let turnID: String?

    /// Provider name, such as `codex`.
    public let provider: String

    /// Provider operation or item identifier, when available.
    public let operationID: String?

    /// Linked change-set identifier when the existing PE change-set model is populated.
    public let changeSetID: String?

    /// Linked file-change projection identifiers when available.
    public let fileChangeIDs: [String]

    /// Repository-relative paths attributed to this activity.
    public let paths: [String]

    /// Bounded provider or producer summary of the file-change activity.
    public let summary: String?

    /// Time this file-change activity was observed.
    public let observedAt: Date

    /// Evidence class behind this attribution.
    public let source: ProvenanceSource

    /// Confidence in this attribution.
    public let confidence: ProvenanceConfidence

    /// Creates a file-change attribution projection record.
    public init(
        id: String,
        sessionID: String,
        threadID: String? = nil,
        turnID: String? = nil,
        provider: String,
        operationID: String? = nil,
        changeSetID: String? = nil,
        fileChangeIDs: [String] = [],
        paths: [String] = [],
        summary: String? = nil,
        observedAt: Date,
        source: ProvenanceSource,
        confidence: ProvenanceConfidence
    ) {
        self.id = id
        self.sessionID = sessionID
        self.threadID = threadID
        self.turnID = turnID
        self.provider = provider
        self.operationID = operationID
        self.changeSetID = changeSetID
        self.fileChangeIDs = fileChangeIDs
        self.paths = paths
        self.summary = summary
        self.observedAt = observedAt
        self.source = source
        self.confidence = confidence
    }
}
