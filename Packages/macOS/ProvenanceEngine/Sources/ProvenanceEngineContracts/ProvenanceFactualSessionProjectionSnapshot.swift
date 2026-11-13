import Foundation

/// One observed proposal and its immutable ledger reference. It is not a checklist
/// or a claim that the proposal is still current.
public struct ProvenanceFactualProposedPlanObservation: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let sequence: Int
    public let timestamp: Date
    public let proposal: ProvenanceCodingAgentProposedPlanRecord
    /// Actual source metadata; absent in older snapshots.
    public let source: ProvenanceSource?
    public let origin: ProvenanceEvidenceOrigin?
    public let eventSchemaVersion: Int?
    public let confidence: ProvenanceConfidence?

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

/// Coverage of this bounded ledger read, not of upstream provider emission.
public struct ProvenanceProposedPlanReadCoverage: Codable, Equatable, Sendable {
    public let scanWindowTruncated: Bool
    public let omittedObservations: Bool

    public init(scanWindowTruncated: Bool, omittedObservations: Bool) {
        self.scanWindowTruncated = scanWindowTruncated
        self.omittedObservations = omittedObservations
    }
}

/// Factual, deterministic projection snapshot for one coding-agent session.
public struct ProvenanceFactualSessionProjectionSnapshot: Codable, Equatable, Sendable {
    /// Monotonically increasing ledger revision current at read time.
    public let revision: Int?

    /// Provenance session identity.
    public let session: ProvenanceSessionRecord

    /// Compact provider thread identities explicitly observed for the session.
    public let providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity]

    /// Provider thread identities explicitly observed for the session.
    public let providerThreads: [ProvenanceCodingAgentThreadRecord]

    /// Detailed factual snapshot for the latest observed turn, when one exists.
    public let latestTurn: ProvenanceFactualSessionProjectionTurnSnapshot?

    /// Compact references to observed turns before ``latestTurn``.
    public let priorTurns: [ProvenanceFactualSessionProjectionTurnReference]

    /// Observed turns with only evidence directly linked to each turn.
    public let turns: [ProvenanceFactualSessionProjectionTurnSnapshot]

    /// Recent proposal observations within a bounded ledger window. Older
    /// observations remain in the ledger; this is not exhaustive coverage.
    public let proposedPlanObservations: [ProvenanceFactualProposedPlanObservation]

    /// Nil means the producer did not report whether proposal evidence was read.
    public let proposedPlanCoverage: ProvenanceProposedPlanReadCoverage?

    private enum CodingKeys: String, CodingKey {
        case revision
        case session
        case providerThreadIdentities
        case providerThreads
        case latestTurn
        case priorTurns
        case turns
        case proposedPlanObservations
        case proposedPlanCoverage
    }

    /// Creates a factual session projection snapshot.
    public init(
        revision: Int?,
        session: ProvenanceSessionRecord,
        providerThreadIdentities: [ProvenanceFactualSessionProjectionProviderThreadIdentity] = [],
        providerThreads: [ProvenanceCodingAgentThreadRecord],
        latestTurn: ProvenanceFactualSessionProjectionTurnSnapshot? = nil,
        priorTurns: [ProvenanceFactualSessionProjectionTurnReference] = [],
        turns: [ProvenanceFactualSessionProjectionTurnSnapshot],
        proposedPlanObservations: [ProvenanceFactualProposedPlanObservation] = [],
        proposedPlanCoverage: ProvenanceProposedPlanReadCoverage? = nil
    ) {
        self.revision = revision
        self.session = session
        self.providerThreadIdentities = providerThreadIdentities
        self.providerThreads = providerThreads
        self.latestTurn = latestTurn
        self.priorTurns = priorTurns
        self.turns = turns
        self.proposedPlanObservations = proposedPlanObservations
        self.proposedPlanCoverage = proposedPlanCoverage
    }

    /// Decodes both the current consumer-focused shape and the earlier v1
    /// shape that contained only provider thread records plus detailed turns.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.revision = try container.decodeIfPresent(Int.self, forKey: .revision)
        self.session = try container.decode(ProvenanceSessionRecord.self, forKey: .session)
        self.providerThreads = try container.decode([ProvenanceCodingAgentThreadRecord].self, forKey: .providerThreads)
        self.turns = try container.decode([ProvenanceFactualSessionProjectionTurnSnapshot].self, forKey: .turns)
        self.proposedPlanObservations = try container.decodeIfPresent(
            [ProvenanceFactualProposedPlanObservation].self, forKey: .proposedPlanObservations
        ) ?? []
        self.proposedPlanCoverage = try container.decodeIfPresent(
            ProvenanceProposedPlanReadCoverage.self, forKey: .proposedPlanCoverage
        )
        self.providerThreadIdentities = try container.decodeIfPresent(
            [ProvenanceFactualSessionProjectionProviderThreadIdentity].self,
            forKey: .providerThreadIdentities
        ) ?? providerThreads.map(ProvenanceFactualSessionProjectionProviderThreadIdentity.init(thread:))
        self.latestTurn = try container.decodeIfPresent(
            ProvenanceFactualSessionProjectionTurnSnapshot.self,
            forKey: .latestTurn
        ) ?? turns.last
        self.priorTurns = try container.decodeIfPresent(
            [ProvenanceFactualSessionProjectionTurnReference].self,
            forKey: .priorTurns
        ) ?? turns.dropLast(latestTurn == nil ? 0 : 1).map { turnSnapshot in
            ProvenanceFactualSessionProjectionTurnReference(turn: turnSnapshot.turn)
        }
    }
}
