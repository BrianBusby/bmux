import Foundation

/// Composition status for a semantic field in the model.
public enum ProvenanceSessionWorkModelSemanticState: String, Codable, Equatable, Sendable {
    /// A current active semantic inference record supplied this field.
    case known

    /// The semantic subject exists, but no active inference record was available.
    case unknown

    /// The factual subject needed to scope the semantic field was unavailable.
    case unavailable
}
