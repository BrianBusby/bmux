import Foundation

/// JSON-like semantic payload value carried by versioned inference records.
public indirect enum ProvenanceSemanticPayloadValue: Codable, Equatable, Sendable {
    /// JSON null.
    case null

    /// Boolean payload value.
    case bool(Bool)

    /// Integer payload value.
    case int(Int)

    /// Floating-point payload value.
    case double(Double)

    /// String payload value.
    case string(String)

    /// Ordered nested payload values.
    case array([ProvenanceSemanticPayloadValue])

    /// Named nested payload values.
    case object([String: ProvenanceSemanticPayloadValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([ProvenanceSemanticPayloadValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: ProvenanceSemanticPayloadValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

/// Scope covered by a semantic inference record.
public enum ProvenanceSemanticInferenceScope: String, Codable, Equatable, Hashable, Sendable {
    /// Inference about a Provenance Engine session.
    case session

    /// Inference about a coding-agent provider thread.
    case thread

    /// Inference about a coding-agent turn.
    case turn
}

/// Producer class for a semantic inference record.
public enum ProvenanceSemanticInferenceProducerType: String, Codable, Equatable, Hashable, Sendable {
    /// Deterministic rule or reducer produced the inference.
    case rule

    /// A model-capable asynchronous worker produced the inference.
    case model
}

/// Lifecycle status for a semantic inference record.
public enum ProvenanceSemanticInferenceStatus: String, Codable, Equatable, Hashable, Sendable {
    /// The record is the currently active claim for its kind and scope.
    case active

    /// The record remains historical evidence but has been replaced by a later record.
    case superseded

    /// The record was invalidated without a replacement.
    case invalidated
}

/// Claim granularity independent from confidence.
public enum ProvenanceSemanticSpecificity: String, Codable, Equatable, Hashable, Sendable {
    /// Broad claim about a large work area or session.
    case broad

    /// Claim scoped to a specific thread, turn, file set, or subtask.
    case scoped

    /// Granular claim with concrete supporting details.
    case granular

    /// Atomic claim that should not be decomposed further by consumers.
    case atomic
}

/// Inspectable pointer from semantic inference back to factual or ledger evidence.
public struct ProvenanceSemanticEvidenceReference: Codable, Equatable, Hashable, Sendable {
    /// Stable reference kind, such as `ledger_event`, `factual_session_projection`, or `coding_agent_prompt`.
    public let kind: String

    /// Stable identifier in the referenced evidence domain.
    public let id: String

    /// Ledger append sequence when the reference points at an immutable event.
    public let ledgerSequence: Int?

    /// Factual projection revision used when the reference points at deterministic Current State.
    public let factualRevision: Int?

    /// Creates a semantic evidence reference.
    public init(
        kind: String,
        id: String,
        ledgerSequence: Int? = nil,
        factualRevision: Int? = nil
    ) {
        self.kind = kind
        self.id = id
        self.ledgerSequence = ledgerSequence
        self.factualRevision = factualRevision
    }
}

/// Public, revisioned semantic inference record stored above deterministic Current State.
public struct ProvenanceSemanticInferenceRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable inference identifier.
    public let id: String

    /// Record schema version.
    public let schemaVersion: Int

    /// Stable semantic kind name. Concrete kinds are defined by later inference slices.
    public let kind: String

    /// Scope covered by this inference.
    public let scope: ProvenanceSemanticInferenceScope

    /// Stable identifier of the scoped session, thread, or turn.
    public let scopeID: String

    /// Structured semantic payload for the claim.
    public let payload: ProvenanceSemanticPayloadValue

    /// Evidence references supporting this claim.
    public let supportingEvidenceRefs: [ProvenanceSemanticEvidenceReference]

    /// Factual Current State revision used as input to this inference.
    public let supportingFactualRevision: Int?

    /// Confidence in the semantic claim.
    public let confidence: ProvenanceConfidence

    /// Specificity or claim granularity, independent from confidence.
    public let specificity: ProvenanceSemanticSpecificity

    /// Whether this inference was produced by a rule or a model-capable worker.
    public let producerType: ProvenanceSemanticInferenceProducerType

    /// Stable producer identity, such as an inference definition or worker name.
    public let producerID: String

    /// Producer definition, prompt, rule, or model version.
    public let producerVersion: String

    /// Creation time for this semantic record.
    public let createdAt: Date

    /// Historical inference IDs this record replaces.
    public let supersedes: [String]

    /// Later inference ID that replaced this record, when superseded.
    public let supersededBy: String?

    /// Lifecycle status for this record.
    public let status: ProvenanceSemanticInferenceStatus

    /// Creates a semantic inference record.
    public init(
        id: String,
        schemaVersion: Int = 1,
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        payload: ProvenanceSemanticPayloadValue,
        supportingEvidenceRefs: [ProvenanceSemanticEvidenceReference],
        supportingFactualRevision: Int?,
        confidence: ProvenanceConfidence,
        specificity: ProvenanceSemanticSpecificity,
        producerType: ProvenanceSemanticInferenceProducerType,
        producerID: String,
        producerVersion: String,
        createdAt: Date,
        supersedes: [String] = [],
        supersededBy: String? = nil,
        status: ProvenanceSemanticInferenceStatus = .active
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.scope = scope
        self.scopeID = scopeID
        self.payload = payload
        self.supportingEvidenceRefs = supportingEvidenceRefs
        self.supportingFactualRevision = supportingFactualRevision
        self.confidence = confidence
        self.specificity = specificity
        self.producerType = producerType
        self.producerID = producerID
        self.producerVersion = producerVersion
        self.createdAt = createdAt
        self.supersedes = supersedes
        self.supersededBy = supersededBy
        self.status = status
    }
}

/// Request to publish one semantic inference record.
public struct ProvenanceSemanticInferencePublishRequest: Codable, Equatable, Sendable {
    /// Record to publish.
    public let record: ProvenanceSemanticInferenceRecord

    /// Creates a publish request.
    public init(record: ProvenanceSemanticInferenceRecord) {
        self.record = record
    }
}

/// Response from publishing one semantic inference record.
public struct ProvenanceSemanticInferencePublishResponse: Codable, Equatable, Sendable {
    /// Whether the inference was accepted.
    public let accepted: Bool

    /// Published inference ID.
    public let inferenceID: String

    /// Prior records superseded by the published inference.
    public let supersededInferenceIDs: [String]

    /// Creates a publish response.
    public init(
        accepted: Bool,
        inferenceID: String,
        supersededInferenceIDs: [String]
    ) {
        self.accepted = accepted
        self.inferenceID = inferenceID
        self.supersededInferenceIDs = supersededInferenceIDs
    }
}

/// Query parameters for semantic inference records.
public struct ProvenanceSemanticInferenceQueryRequest: Codable, Equatable, Sendable {
    /// Scope to read.
    public let scope: ProvenanceSemanticInferenceScope

    /// Stable scope identifier to read.
    public let scopeID: String

    /// Optional semantic inference kind filter.
    public let kind: String?

    /// Whether historical superseded or invalidated records should be included.
    public let includeInactive: Bool

    /// Maximum records to return.
    public let limit: Int?

    /// Creates a semantic inference query request.
    public init(
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        kind: String? = nil,
        includeInactive: Bool = false,
        limit: Int? = nil
    ) {
        self.scope = scope
        self.scopeID = scopeID
        self.kind = kind
        self.includeInactive = includeInactive
        self.limit = limit
    }
}

/// Query response for semantic inference records.
public struct ProvenanceSemanticInferenceQueryResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Returned semantic inference records.
    public let records: [ProvenanceSemanticInferenceRecord]

    /// Creates a query response.
    public init(schemaVersion: Int = 1, records: [ProvenanceSemanticInferenceRecord]) {
        self.schemaVersion = schemaVersion
        self.records = records
    }
}

/// Bounded item allowed in a model-capable inference input packet.
public struct ProvenanceSemanticInferencePacketItem: Codable, Equatable, Sendable {
    /// Evidence or factual reference for this packet item.
    public let reference: ProvenanceSemanticEvidenceReference

    /// Optional bounded title or label.
    public let title: String?

    /// Optional bounded summary, excerpt, or digest. This is not an unrestricted transcript field.
    public let boundedSummary: String?

    /// Creates a bounded packet item.
    public init(
        reference: ProvenanceSemanticEvidenceReference,
        title: String? = nil,
        boundedSummary: String? = nil
    ) {
        self.reference = reference
        self.title = title
        self.boundedSummary = boundedSummary
    }
}

/// Bounded semantic inference input shape for asynchronous rule or model workers.
public struct ProvenanceSemanticInferenceInputPacket: Codable, Equatable, Sendable {
    /// Packet schema version.
    public let schemaVersion: Int

    /// Target scope for the requested inference pass.
    public let scope: ProvenanceSemanticInferenceScope

    /// Stable target scope identifier.
    public let scopeID: String

    /// Factual projection revision represented by the packet.
    public let factualRevision: Int?

    /// Current prompt item, when policy includes one.
    public let currentPrompt: ProvenanceSemanticInferencePacketItem?

    /// Current or latest plan item, when policy includes one.
    public let currentPlan: ProvenanceSemanticInferencePacketItem?

    /// Visible reasoning summaries, bounded by producer policy.
    public let visibleReasoningSummaries: [ProvenanceSemanticInferencePacketItem]

    /// Recently completed commands, bounded by producer policy.
    public let recentCompletedCommands: [ProvenanceSemanticInferencePacketItem]

    /// Recent file-change attribution items, bounded by producer policy.
    public let recentFileChangeAttributions: [ProvenanceSemanticInferencePacketItem]

    /// Lifecycle or turn-state facts, bounded by producer policy.
    public let lifecycle: [ProvenanceSemanticInferencePacketItem]

    /// Prior semantic records supplied as bounded state, not as raw transcripts.
    public let priorSemanticState: [ProvenanceSemanticInferencePacketItem]

    /// Relevant deterministic factual context, bounded by producer policy.
    public let relevantFactualContext: [ProvenanceSemanticInferencePacketItem]

    /// Creates a bounded semantic inference input packet.
    public init(
        schemaVersion: Int = 1,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        factualRevision: Int?,
        currentPrompt: ProvenanceSemanticInferencePacketItem? = nil,
        currentPlan: ProvenanceSemanticInferencePacketItem? = nil,
        visibleReasoningSummaries: [ProvenanceSemanticInferencePacketItem] = [],
        recentCompletedCommands: [ProvenanceSemanticInferencePacketItem] = [],
        recentFileChangeAttributions: [ProvenanceSemanticInferencePacketItem] = [],
        lifecycle: [ProvenanceSemanticInferencePacketItem] = [],
        priorSemanticState: [ProvenanceSemanticInferencePacketItem] = [],
        relevantFactualContext: [ProvenanceSemanticInferencePacketItem] = []
    ) {
        self.schemaVersion = schemaVersion
        self.scope = scope
        self.scopeID = scopeID
        self.factualRevision = factualRevision
        self.currentPrompt = currentPrompt
        self.currentPlan = currentPlan
        self.visibleReasoningSummaries = visibleReasoningSummaries
        self.recentCompletedCommands = recentCompletedCommands
        self.recentFileChangeAttributions = recentFileChangeAttributions
        self.lifecycle = lifecycle
        self.priorSemanticState = priorSemanticState
        self.relevantFactualContext = relevantFactualContext
    }
}

/// Evidence change kinds that can mark semantic inference kinds dirty.
public enum ProvenanceSemanticInferenceEvidenceChangeKind: String, Codable, Equatable, Hashable, Sendable {
    /// A new prompt was submitted.
    case promptSubmitted

    /// The current or latest plan changed.
    case planUpdated

    /// A visible reasoning summary completed.
    case visibleReasoningSummaryCompleted

    /// A meaningful command completed.
    case meaningfulCommandCompleted

    /// File-change activity was attributed to the session or turn.
    case fileChangeActivity

    /// Validation evidence was recorded.
    case validationResultRecorded

    /// Session, thread, or turn lifecycle changed.
    case lifecycleChanged

    /// Evidence not expected to affect semantic inference.
    case irrelevant
}

/// One observed evidence change considered by invalidation/coalescing policy.
public struct ProvenanceSemanticInferenceEvidenceChange: Codable, Equatable, Sendable {
    /// Change kind.
    public let kind: ProvenanceSemanticInferenceEvidenceChangeKind

    /// Scope affected by the change.
    public let scope: ProvenanceSemanticInferenceScope

    /// Stable affected scope identifier.
    public let scopeID: String

    /// Supporting evidence reference, when known.
    public let evidenceRef: ProvenanceSemanticEvidenceReference?

    /// Observation time for deterministic ordering.
    public let observedAt: Date

    /// Creates an evidence change.
    public init(
        kind: ProvenanceSemanticInferenceEvidenceChangeKind,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        evidenceRef: ProvenanceSemanticEvidenceReference? = nil,
        observedAt: Date
    ) {
        self.kind = kind
        self.scope = scope
        self.scopeID = scopeID
        self.evidenceRef = evidenceRef
        self.observedAt = observedAt
    }
}

/// Rule declaring which evidence changes dirty one semantic inference kind.
public struct ProvenanceSemanticInferenceInvalidationRule: Codable, Equatable, Sendable {
    /// Semantic inference kind dirtied by the rule.
    public let inferenceKind: String

    /// Evidence change kinds that invalidate the inference kind.
    public let dirtyOn: Set<ProvenanceSemanticInferenceEvidenceChangeKind>

    /// Creates an invalidation rule.
    public init(
        inferenceKind: String,
        dirtyOn: Set<ProvenanceSemanticInferenceEvidenceChangeKind>
    ) {
        self.inferenceKind = inferenceKind
        self.dirtyOn = dirtyOn
    }
}

/// Deterministic plan for one coalesced semantic inference pass.
public struct ProvenanceSemanticInferencePassPlan: Codable, Equatable, Sendable {
    /// Scope for the inference pass.
    public let scope: ProvenanceSemanticInferenceScope

    /// Stable target scope identifier.
    public let scopeID: String

    /// Dirty inference kinds that should be refreshed.
    public let dirtyInferenceKinds: [String]

    /// Coalesced evidence change kinds that triggered this pass.
    public let triggeringChangeKinds: [ProvenanceSemanticInferenceEvidenceChangeKind]

    /// Evidence references that should seed input-packet gathering.
    public let triggeringEvidenceRefs: [ProvenanceSemanticEvidenceReference]

    /// Creates a coalesced inference pass plan.
    public init(
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        dirtyInferenceKinds: [String],
        triggeringChangeKinds: [ProvenanceSemanticInferenceEvidenceChangeKind],
        triggeringEvidenceRefs: [ProvenanceSemanticEvidenceReference]
    ) {
        self.scope = scope
        self.scopeID = scopeID
        self.dirtyInferenceKinds = dirtyInferenceKinds
        self.triggeringChangeKinds = triggeringChangeKinds
        self.triggeringEvidenceRefs = triggeringEvidenceRefs
    }
}

/// Deterministic invalidation and coalescing policy for semantic inference workers.
public enum ProvenanceSemanticInferenceInvalidationPolicy {
    /// Returns dirty inference kinds for a burst of evidence changes.
    public static func dirtyInferenceKinds(
        for changes: [ProvenanceSemanticInferenceEvidenceChange],
        rules: [ProvenanceSemanticInferenceInvalidationRule]
    ) -> [String] {
        let changeKinds = Set(changes.map(\.kind))
        var seen = Set<String>()
        var dirty: [String] = []
        for rule in rules where !rule.dirtyOn.isDisjoint(with: changeKinds) {
            guard !seen.contains(rule.inferenceKind) else { continue }
            seen.insert(rule.inferenceKind)
            dirty.append(rule.inferenceKind)
        }
        return dirty
    }

    /// Coalesces a burst of evidence changes into at most one inference pass plan for one scope.
    public static func coalescedPass(
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        changes: [ProvenanceSemanticInferenceEvidenceChange],
        rules: [ProvenanceSemanticInferenceInvalidationRule]
    ) -> ProvenanceSemanticInferencePassPlan? {
        let scopedChanges = changes
            .filter { $0.scope == scope && $0.scopeID == scopeID }
            .sorted { lhs, rhs in
                if lhs.observedAt == rhs.observedAt {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.observedAt < rhs.observedAt
            }
        let dirtyKinds = dirtyInferenceKinds(for: scopedChanges, rules: rules)
        guard !dirtyKinds.isEmpty else { return nil }
        let dirtyKindSet = Set(dirtyKinds)
        let relevantChangeKinds = rules.reduce(into: Set<ProvenanceSemanticInferenceEvidenceChangeKind>()) { result, rule in
            guard dirtyKindSet.contains(rule.inferenceKind) else { return }
            result.formUnion(rule.dirtyOn)
        }
        let materialChanges = scopedChanges.filter { relevantChangeKinds.contains($0.kind) }

        var triggeringKinds: [ProvenanceSemanticInferenceEvidenceChangeKind] = []
        var seenKinds = Set<ProvenanceSemanticInferenceEvidenceChangeKind>()
        var triggeringRefs: [ProvenanceSemanticEvidenceReference] = []
        var seenRefs = Set<ProvenanceSemanticEvidenceReference>()
        for change in materialChanges {
            if !seenKinds.contains(change.kind) {
                triggeringKinds.append(change.kind)
                seenKinds.insert(change.kind)
            }
            if let evidenceRef = change.evidenceRef, !seenRefs.contains(evidenceRef) {
                triggeringRefs.append(evidenceRef)
                seenRefs.insert(evidenceRef)
            }
        }

        return ProvenanceSemanticInferencePassPlan(
            scope: scope,
            scopeID: scopeID,
            dirtyInferenceKinds: dirtyKinds,
            triggeringChangeKinds: triggeringKinds,
            triggeringEvidenceRefs: triggeringRefs
        )
    }
}
