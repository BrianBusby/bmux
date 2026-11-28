import Foundation

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

    /// Turn IDs with unresolved ownership, or nil when ownership was not assessed.
    public let unresolvedTurnIDs: [String]?

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
        case unresolvedTurnIDs
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
        unresolvedTurnIDs: [String]? = nil,
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
        self.unresolvedTurnIDs = unresolvedTurnIDs
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
        self.unresolvedTurnIDs = try container.decodeIfPresent([String].self, forKey: .unresolvedTurnIDs)
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
