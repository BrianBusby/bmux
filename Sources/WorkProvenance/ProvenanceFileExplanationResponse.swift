import Foundation

/// Bounded response for a file-explanation query.
struct ProvenanceFileExplanationResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    let schemaVersion: Int

    /// Whether file-level provenance exists for the requested path.
    let found: Bool

    /// Stable reason code when `found` is false.
    let reason: String?

    /// File explanation when one was found.
    let explanation: WorkProvenanceFileExplanation?

    /// Creates a file-explanation response.
    init(
        schemaVersion: Int = 1,
        found: Bool,
        reason: String? = nil,
        explanation: WorkProvenanceFileExplanation?
    ) {
        self.schemaVersion = schemaVersion
        self.found = found
        self.reason = reason
        self.explanation = explanation
    }
}
