import Foundation

/// One observed proposal and its immutable ledger reference. It is not a checklist
/// or a claim that the proposal is still current.
public struct ProvenanceFactualProposedPlanObservation: Codable, Equatable, Sendable, Identifiable {
    /// Identifier of the ledger observation.
    public let id: String
    /// Ledger sequence of the observation.
    public let sequence: Int
    /// Time the proposal was observed.
    public let timestamp: Date
    /// Proposed plan recorded by the coding agent.
    public let proposal: ProvenanceCodingAgentProposedPlanRecord
    /// Actual source metadata; absent in older snapshots.
    public let source: ProvenanceSource?
    /// Origin of the evidence, when recorded.
    public let origin: ProvenanceEvidenceOrigin?
    /// Schema version of the ledger event, when recorded.
    public let eventSchemaVersion: Int?
    /// Confidence assigned to the evidence, when recorded.
    public let confidence: ProvenanceConfidence?

    /// Creates an observation with its ledger reference and available source metadata.
    /// - Parameters:
    ///   - id: Identifier of the ledger observation.
    ///   - sequence: Ledger sequence of the observation.
    ///   - timestamp: Time the proposal was observed.
    ///   - proposal: Proposed plan recorded by the coding agent.
    ///   - source: Actual source metadata, if recorded.
    ///   - origin: Origin of the evidence, if recorded.
    ///   - eventSchemaVersion: Schema version of the ledger event, if recorded.
    ///   - confidence: Confidence assigned to the evidence, if recorded.
    public init(id: String, sequence: Int, timestamp: Date, proposal: ProvenanceCodingAgentProposedPlanRecord,
                source: ProvenanceSource? = nil, origin: ProvenanceEvidenceOrigin? = nil, eventSchemaVersion: Int? = nil,
                confidence: ProvenanceConfidence? = nil) {
        self.id = id
        self.sequence = sequence
        self.timestamp = timestamp
        self.proposal = proposal
        self.source = source
        self.origin = origin
        self.eventSchemaVersion = eventSchemaVersion
        self.confidence = confidence
    }
}
