import Foundation

/// One accepted evidence event supporting a projected outcome item.
public struct ProvenanceTurnOutcomeEvidenceReference: Codable, Equatable, Sendable {
    /// Stable ledger event identifier.
    public let eventID: String

    /// SQLite append-order sequence for the event.
    public let eventSequence: Int

    /// Stable event type.
    public let eventType: String

    /// Evidence claim classification.
    public let source: ProvenanceSource

    /// Producing system for the event, when known.
    public let evidenceOrigin: ProvenanceEvidenceOrigin?

    /// Ownership boundary for the event, when known.
    public let evidenceScope: ProvenanceEvidenceScope?

    /// Projection record kind supported by this event.
    public let recordKind: String

    /// Projection record identifier supported by this event.
    public let recordID: String

    /// Rule version that interpreted the evidence for this projection.
    public let interpretedByRuleVersion: String

    /// Source availability state used by this projection.
    public let sourceState: String

    /// Creates an outcome evidence reference.
    public init(
        eventID: String,
        eventSequence: Int,
        eventType: String,
        source: ProvenanceSource,
        evidenceOrigin: ProvenanceEvidenceOrigin?,
        evidenceScope: ProvenanceEvidenceScope?,
        recordKind: String,
        recordID: String,
        interpretedByRuleVersion: String,
        sourceState: String
    ) {
        self.eventID = eventID
        self.eventSequence = eventSequence
        self.eventType = eventType
        self.source = source
        self.evidenceOrigin = evidenceOrigin
        self.evidenceScope = evidenceScope
        self.recordKind = recordKind
        self.recordID = recordID
        self.interpretedByRuleVersion = interpretedByRuleVersion
        self.sourceState = sourceState
    }
}
