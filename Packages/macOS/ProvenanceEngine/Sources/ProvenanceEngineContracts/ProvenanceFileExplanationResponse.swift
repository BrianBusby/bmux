import Foundation

/// Bounded response for a file-explanation query.
public struct ProvenanceFileExplanationResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Whether file-level provenance exists for the requested path.
    public let found: Bool

    /// Stable reason code when `found` is false.
    public let reason: String?

    /// File explanation when one was found.
    public let explanation: ProvenanceFileExplanation?

    /// Creates a file-explanation response.
    public init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        explanation: ProvenanceFileExplanation?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.explanation = explanation
    }
}
