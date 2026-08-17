import Foundation

/// Selected semantic inference record as embedded in a SessionWorkModel.
public struct ProvenanceSessionWorkModelSemanticRecord: Codable, Equatable, Sendable {
    /// Stable inference identifier.
    public let inferenceID: String

    /// Record schema version.
    public let schemaVersion: Int

    /// Structured semantic payload.
    public let payload: ProvenanceSemanticPayloadValue

    /// Evidence references supporting the claim.
    public let supportingEvidenceRefs: [ProvenanceSemanticEvidenceReference]

    /// Factual projection revision used as input to the semantic claim.
    public let supportingFactualRevision: Int?

    /// Confidence in the semantic claim.
    public let confidence: ProvenanceConfidence

    /// Semantic claim specificity.
    public let specificity: ProvenanceSemanticSpecificity

    /// Producer class for the claim.
    public let producerType: ProvenanceSemanticInferenceProducerType

    /// Stable producer identity.
    public let producerID: String

    /// Producer version.
    public let producerVersion: String

    /// Creation time for this semantic record.
    public let createdAt: Date

    /// Lifecycle status for the selected record.
    public let status: ProvenanceSemanticInferenceStatus

    /// Historical inference IDs this record supersedes.
    public let supersedes: [String]

    /// Later replacement ID when present.
    public let supersededBy: String?

    /// Creates a semantic record embedded in the model.
    ///
    /// - Parameter record: Authoritative semantic inference record selected by PE.
    public init(record: ProvenanceSemanticInferenceRecord) {
        self.inferenceID = record.id
        self.schemaVersion = record.schemaVersion
        self.payload = record.payload
        self.supportingEvidenceRefs = record.supportingEvidenceRefs
        self.supportingFactualRevision = record.supportingFactualRevision
        self.confidence = record.confidence
        self.specificity = record.specificity
        self.producerType = record.producerType
        self.producerID = record.producerID
        self.producerVersion = record.producerVersion
        self.createdAt = record.createdAt
        self.status = record.status
        self.supersedes = record.supersedes
        self.supersededBy = record.supersededBy
    }
}
