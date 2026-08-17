import Foundation

/// Source layers used to compose one SessionWorkModel snapshot.
public struct ProvenanceSessionWorkModelBasis: Codable, Equatable, Sendable {
    /// Factual Current State snapshot backing this model.
    public let factualSessionProjection: ProvenanceFactualSessionProjectionSnapshot

    /// Active semantic inference records selected into semantic model fields.
    public let semanticInferenceRecords: [ProvenanceSemanticInferenceRecord]

    /// Creates basis metadata.
    ///
    /// - Parameters:
    ///   - factualSessionProjection: Factual Current State snapshot backing this model.
    ///   - semanticInferenceRecords: Active semantic records selected into the model.
    public init(
        factualSessionProjection: ProvenanceFactualSessionProjectionSnapshot,
        semanticInferenceRecords: [ProvenanceSemanticInferenceRecord]
    ) {
        self.factualSessionProjection = factualSessionProjection
        self.semanticInferenceRecords = semanticInferenceRecords
    }
}
