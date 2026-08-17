import Foundation

/// One semantic model field with provenance back to the authoritative inference record.
public struct ProvenanceSessionWorkModelSemanticField: Codable, Equatable, Sendable {
    /// Semantic inference kind represented by this field.
    public let kind: String

    /// Intended scope for the semantic field.
    public let scope: ProvenanceSemanticInferenceScope

    /// Scoped subject identifier, when factual data can identify it.
    public let scopeID: String?

    /// Composition state for this field.
    public let state: ProvenanceSessionWorkModelSemanticState

    /// Selected active semantic record, when known.
    public let record: ProvenanceSessionWorkModelSemanticRecord?

    /// Stable reason code when the field is not backed by a selected record.
    public let reason: String?

    /// Creates a semantic field.
    ///
    /// - Parameters:
    ///   - kind: Semantic inference kind represented by this field.
    ///   - scope: Intended scope for the semantic field.
    ///   - scopeID: Scoped subject identifier, when factual data can identify it.
    ///   - state: Composition state for this field.
    ///   - record: Selected active semantic record, when known.
    ///   - reason: Stable reason code when the field is not backed by a selected record.
    public init(
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String?,
        state: ProvenanceSessionWorkModelSemanticState,
        record: ProvenanceSessionWorkModelSemanticRecord? = nil,
        reason: String? = nil
    ) {
        self.kind = kind
        self.scope = scope
        self.scopeID = scopeID
        self.state = state
        self.record = record
        self.reason = reason
    }
}
