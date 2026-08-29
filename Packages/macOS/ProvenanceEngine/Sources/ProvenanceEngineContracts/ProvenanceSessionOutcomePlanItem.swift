import Foundation

/// Latest factual state of one plan item reconciled across a session.
public struct ProvenanceSessionOutcomePlanItem: Codable, Equatable, Sendable {
    /// Stable session-level plan item identifier.
    public let id: String

    /// Plan item text copied from accepted evidence.
    public let text: String

    /// Latest observed plan item status.
    public let status: String

    /// Turn where this plan item text first appeared.
    public let firstObservedTurnID: String

    /// Turn where the latest factual state was observed.
    public let latestObservedTurnID: String

    /// Exact turn-outcome revision that supplied the latest state.
    public let latestTurnOutcomeRevisionID: String

    /// Source turn-level plan item identifiers that reconciled into this item.
    public let sourcePlanItemIDs: [String]

    /// Supporting evidence references for the latest factual state.
    public let evidence: [ProvenanceTurnOutcomeEvidenceReference]

    /// Creates a reconciled session-level plan item.
    public init(
        id: String,
        text: String,
        status: String,
        firstObservedTurnID: String,
        latestObservedTurnID: String,
        latestTurnOutcomeRevisionID: String,
        sourcePlanItemIDs: [String],
        evidence: [ProvenanceTurnOutcomeEvidenceReference]
    ) {
        self.id = id
        self.text = text
        self.status = status
        self.firstObservedTurnID = firstObservedTurnID
        self.latestObservedTurnID = latestObservedTurnID
        self.latestTurnOutcomeRevisionID = latestTurnOutcomeRevisionID
        self.sourcePlanItemIDs = sourcePlanItemIDs
        self.evidence = evidence
    }
}
