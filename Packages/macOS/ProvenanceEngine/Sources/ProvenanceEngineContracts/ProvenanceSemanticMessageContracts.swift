import Foundation

/// Lifecycle status for a presentation-oriented semantic message.
public enum ProvenanceSemanticMessageStatus: String, Codable, Equatable, Hashable, Sendable {
    /// The message is the currently active wording for its semantic kind, scope, and policy.
    case active

    /// The message remains historical presentation evidence but was replaced.
    case superseded

    /// The message was invalidated without a replacement.
    case invalidated
}

/// Presentation policy used to render semantic meaning into human-readable wording.
public struct ProvenanceSemanticMessagePresentationPolicy: Codable, Equatable, Hashable, Sendable {
    /// Stable policy identifier.
    public let id: String

    /// Policy version.
    public let version: String

    /// Locale identifier for the rendered wording.
    public let localeIdentifier: String?

    /// Creates a semantic message presentation policy.
    public init(
        id: String = "provenance-engine.semantic-message.default",
        version: String = "v1",
        localeIdentifier: String? = "en-US"
    ) {
        self.id = id
        self.version = version
        self.localeIdentifier = localeIdentifier
    }
}

/// Presentation-oriented rendering of one semantic inference record.
public struct ProvenanceSemanticMessageRecord: Codable, Equatable, Sendable, Identifiable {
    /// Stable message identifier.
    public let id: String

    /// Record schema version.
    public let schemaVersion: Int

    /// Semantic inference this message renders.
    public let semanticInferenceID: String

    /// Semantic inference kind rendered by this message.
    public let semanticInferenceKind: String

    /// Scope covered by the rendered semantic inference.
    public let scope: ProvenanceSemanticInferenceScope

    /// Stable identifier of the scoped session, thread, or turn.
    public let scopeID: String

    /// Glance-level phrase intended for dense session lists or status rows.
    public let concisePhrase: String

    /// Plain-language explanation intended for progressive disclosure.
    public let expandedMeaning: String

    /// Structured semantic meaning used as input to the presentation layer.
    public let structuredSemanticPayload: ProvenanceSemanticPayloadValue

    /// Evidence references inherited from the rendered semantic inference.
    public let supportingEvidenceRefs: [ProvenanceSemanticEvidenceReference]

    /// Factual revision inherited from the rendered semantic inference.
    public let supportingFactualRevision: Int?

    /// Confidence inherited from the rendered semantic inference.
    public let confidence: ProvenanceConfidence

    /// Specificity inherited from the rendered semantic inference.
    public let specificity: ProvenanceSemanticSpecificity

    /// Whether wording was produced by a rule or model-capable presentation worker.
    public let presentationProducerType: ProvenanceSemanticInferenceProducerType

    /// Stable presentation producer identifier.
    public let presentationProducerID: String

    /// Presentation producer version.
    public let presentationProducerVersion: String

    /// Presentation policy identifier.
    public let presentationPolicyID: String

    /// Presentation policy version.
    public let presentationPolicyVersion: String

    /// Locale identifier used for the rendered wording.
    public let localeIdentifier: String?

    /// Creation time for this message record.
    public let createdAt: Date

    /// Historical message IDs this record replaces.
    public let supersedes: [String]

    /// Later message ID that replaced this record, when superseded.
    public let supersededBy: String?

    /// Lifecycle status for this message record.
    public let status: ProvenanceSemanticMessageStatus

    /// Creates a semantic message record.
    public init(
        id: String,
        schemaVersion: Int = 1,
        semanticInferenceID: String,
        semanticInferenceKind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        concisePhrase: String,
        expandedMeaning: String,
        structuredSemanticPayload: ProvenanceSemanticPayloadValue,
        supportingEvidenceRefs: [ProvenanceSemanticEvidenceReference],
        supportingFactualRevision: Int?,
        confidence: ProvenanceConfidence,
        specificity: ProvenanceSemanticSpecificity,
        presentationProducerType: ProvenanceSemanticInferenceProducerType,
        presentationProducerID: String,
        presentationProducerVersion: String,
        presentationPolicyID: String,
        presentationPolicyVersion: String,
        localeIdentifier: String?,
        createdAt: Date,
        supersedes: [String] = [],
        supersededBy: String? = nil,
        status: ProvenanceSemanticMessageStatus = .active
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.semanticInferenceID = semanticInferenceID
        self.semanticInferenceKind = semanticInferenceKind
        self.scope = scope
        self.scopeID = scopeID
        self.concisePhrase = concisePhrase
        self.expandedMeaning = expandedMeaning
        self.structuredSemanticPayload = structuredSemanticPayload
        self.supportingEvidenceRefs = supportingEvidenceRefs
        self.supportingFactualRevision = supportingFactualRevision
        self.confidence = confidence
        self.specificity = specificity
        self.presentationProducerType = presentationProducerType
        self.presentationProducerID = presentationProducerID
        self.presentationProducerVersion = presentationProducerVersion
        self.presentationPolicyID = presentationPolicyID
        self.presentationPolicyVersion = presentationPolicyVersion
        self.localeIdentifier = localeIdentifier
        self.createdAt = createdAt
        self.supersedes = supersedes
        self.supersededBy = supersededBy
        self.status = status
    }
}

/// Request to publish one semantic message record.
public struct ProvenanceSemanticMessagePublishRequest: Codable, Equatable, Sendable {
    /// Record to publish.
    public let record: ProvenanceSemanticMessageRecord

    /// Creates a publish request.
    public init(record: ProvenanceSemanticMessageRecord) {
        self.record = record
    }
}

/// Response from publishing one semantic message record.
public struct ProvenanceSemanticMessagePublishResponse: Codable, Equatable, Sendable {
    /// Whether the message was accepted.
    public let accepted: Bool

    /// Published message ID.
    public let messageID: String

    /// Prior messages superseded by the published message.
    public let supersededMessageIDs: [String]

    /// Creates a publish response.
    public init(accepted: Bool, messageID: String, supersededMessageIDs: [String]) {
        self.accepted = accepted
        self.messageID = messageID
        self.supersededMessageIDs = supersededMessageIDs
    }
}

/// Query parameters for semantic message records.
public struct ProvenanceSemanticMessageQueryRequest: Codable, Equatable, Sendable {
    /// Scope to read.
    public let scope: ProvenanceSemanticInferenceScope

    /// Stable scope identifier to read.
    public let scopeID: String

    /// Optional semantic inference kind filter.
    public let semanticInferenceKind: String?

    /// Optional semantic inference ID filter.
    public let semanticInferenceID: String?

    /// Optional presentation policy filter.
    public let presentationPolicyID: String?

    /// Whether historical superseded or invalidated messages should be included.
    public let includeInactive: Bool

    /// Maximum records to return.
    public let limit: Int?

    /// Creates a semantic message query request.
    public init(
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        semanticInferenceKind: String? = nil,
        semanticInferenceID: String? = nil,
        presentationPolicyID: String? = nil,
        includeInactive: Bool = false,
        limit: Int? = nil
    ) {
        self.scope = scope
        self.scopeID = scopeID
        self.semanticInferenceKind = semanticInferenceKind
        self.semanticInferenceID = semanticInferenceID
        self.presentationPolicyID = presentationPolicyID
        self.includeInactive = includeInactive
        self.limit = limit
    }
}

/// Query response for semantic message records.
public struct ProvenanceSemanticMessageQueryResponse: Codable, Equatable, Sendable {
    /// Schema version for this response shape.
    public let schemaVersion: Int

    /// Returned semantic message records.
    public let records: [ProvenanceSemanticMessageRecord]

    /// Creates a query response.
    public init(schemaVersion: Int = 1, records: [ProvenanceSemanticMessageRecord]) {
        self.schemaVersion = schemaVersion
        self.records = records
    }
}

/// Request to materialize human-readable messages from semantic inference records.
public struct ProvenanceSemanticMessageMaterializationRequest: Codable, Equatable, Sendable {
    /// Semantic inference records to render.
    public let semanticInferenceRecords: [ProvenanceSemanticInferenceRecord]

    /// Presentation policy to apply.
    public let presentationPolicy: ProvenanceSemanticMessagePresentationPolicy

    /// Presentation producer identity.
    public let presentationProducerID: String

    /// Presentation producer version.
    public let presentationProducerVersion: String

    /// Creation timestamp for newly published message records.
    public let createdAt: Date

    /// Creates a materialization request.
    public init(
        semanticInferenceRecords: [ProvenanceSemanticInferenceRecord],
        presentationPolicy: ProvenanceSemanticMessagePresentationPolicy = ProvenanceSemanticMessagePresentationPolicy(),
        presentationProducerID: String = ProvenanceSemanticMessageRenderer.producerID,
        presentationProducerVersion: String = ProvenanceSemanticMessageRenderer.producerVersion,
        createdAt: Date
    ) {
        self.semanticInferenceRecords = semanticInferenceRecords
        self.presentationPolicy = presentationPolicy
        self.presentationProducerID = presentationProducerID
        self.presentationProducerVersion = presentationProducerVersion
        self.createdAt = createdAt
    }
}

/// Response from materializing human-readable semantic messages.
public struct ProvenanceSemanticMessageMaterializationResponse: Codable, Equatable, Sendable {
    /// Active messages produced or retained by this pass.
    public let records: [ProvenanceSemanticMessageRecord]

    /// New message IDs published by this pass.
    public let publishedMessageIDs: [String]

    /// Existing active message IDs retained because wording and policy did not change.
    public let unchangedMessageIDs: [String]

    /// Semantic inference IDs skipped because no renderer exists for their kind.
    public let skippedSemanticInferenceIDs: [String]

    /// Creates a materialization response.
    public init(
        records: [ProvenanceSemanticMessageRecord],
        publishedMessageIDs: [String] = [],
        unchangedMessageIDs: [String] = [],
        skippedSemanticInferenceIDs: [String] = []
    ) {
        self.records = records
        self.publishedMessageIDs = publishedMessageIDs
        self.unchangedMessageIDs = unchangedMessageIDs
        self.skippedSemanticInferenceIDs = skippedSemanticInferenceIDs
    }
}

/// Deterministic default renderer for first-pass semantic message records.
public struct ProvenanceSemanticMessageRenderer: Sendable {
    /// Stable presentation producer identity.
    public static let producerID = "provenance-engine.semantic-message.rule"

    /// Stable presentation producer version.
    public static let producerVersion = "human-readable-semantic-messaging-v1"

    /// Presentation policy applied to rendered messages.
    public let presentationPolicy: ProvenanceSemanticMessagePresentationPolicy

    /// Presentation producer identity written to generated message records.
    public let presentationProducerID: String

    /// Presentation producer version written to generated message records.
    public let presentationProducerVersion: String

    /// Creates a semantic message renderer.
    public init(
        presentationPolicy: ProvenanceSemanticMessagePresentationPolicy = ProvenanceSemanticMessagePresentationPolicy(),
        presentationProducerID: String = Self.producerID,
        presentationProducerVersion: String = Self.producerVersion
    ) {
        self.presentationPolicy = presentationPolicy
        self.presentationProducerID = presentationProducerID
        self.presentationProducerVersion = presentationProducerVersion
    }

    /// Builds one candidate message record for a supported semantic inference record.
    public func record(
        for inference: ProvenanceSemanticInferenceRecord,
        createdAt: Date
    ) -> ProvenanceSemanticMessageRecord? {
        guard let rendered = Self.render(
            inference,
            localeIdentifier: presentationPolicy.localeIdentifier
        ) else { return nil }
        return ProvenanceSemanticMessageRecord(
            id: Self.stableMessageID(
                inferenceID: inference.id,
                policy: presentationPolicy,
                producerID: presentationProducerID,
                producerVersion: presentationProducerVersion,
                concisePhrase: rendered.concisePhrase,
                expandedMeaning: rendered.expandedMeaning
            ),
            semanticInferenceID: inference.id,
            semanticInferenceKind: inference.kind,
            scope: inference.scope,
            scopeID: inference.scopeID,
            concisePhrase: rendered.concisePhrase,
            expandedMeaning: rendered.expandedMeaning,
            structuredSemanticPayload: inference.payload,
            supportingEvidenceRefs: inference.supportingEvidenceRefs,
            supportingFactualRevision: inference.supportingFactualRevision,
            confidence: inference.confidence,
            specificity: inference.specificity,
            presentationProducerType: .rule,
            presentationProducerID: presentationProducerID,
            presentationProducerVersion: presentationProducerVersion,
            presentationPolicyID: presentationPolicy.id,
            presentationPolicyVersion: presentationPolicy.version,
            localeIdentifier: presentationPolicy.localeIdentifier,
            createdAt: createdAt
        )
    }

    /// Builds one candidate message record with one-off renderer metadata.
    public static func record(
        for inference: ProvenanceSemanticInferenceRecord,
        presentationPolicy: ProvenanceSemanticMessagePresentationPolicy = ProvenanceSemanticMessagePresentationPolicy(),
        createdAt: Date,
        presentationProducerID: String = Self.producerID,
        presentationProducerVersion: String = Self.producerVersion
    ) -> ProvenanceSemanticMessageRecord? {
        Self(
            presentationPolicy: presentationPolicy,
            presentationProducerID: presentationProducerID,
            presentationProducerVersion: presentationProducerVersion
        ).record(for: inference, createdAt: createdAt)
    }
}

public extension ProvenanceSemanticMessageRecord {
    /// Returns this record with replaced supersession fields while preserving the rendered message.
    func superseding(_ messageIDs: [String]) -> ProvenanceSemanticMessageRecord {
        ProvenanceSemanticMessageRecord(
            id: id,
            schemaVersion: schemaVersion,
            semanticInferenceID: semanticInferenceID,
            semanticInferenceKind: semanticInferenceKind,
            scope: scope,
            scopeID: scopeID,
            concisePhrase: concisePhrase,
            expandedMeaning: expandedMeaning,
            structuredSemanticPayload: structuredSemanticPayload,
            supportingEvidenceRefs: supportingEvidenceRefs,
            supportingFactualRevision: supportingFactualRevision,
            confidence: confidence,
            specificity: specificity,
            presentationProducerType: presentationProducerType,
            presentationProducerID: presentationProducerID,
            presentationProducerVersion: presentationProducerVersion,
            presentationPolicyID: presentationPolicyID,
            presentationPolicyVersion: presentationPolicyVersion,
            localeIdentifier: localeIdentifier,
            createdAt: createdAt,
            supersedes: messageIDs,
            supersededBy: supersededBy,
            status: status
        )
    }
}

public extension ProvenanceEngineClient {
    /// Default unsupported response for clients that have not adopted semantic message publishing.
    func publishSemanticMessage(_ request: ProvenanceSemanticMessagePublishRequest) async throws
        -> ProvenanceSemanticMessagePublishResponse {
        ProvenanceSemanticMessagePublishResponse(
            accepted: false,
            messageID: request.record.id,
            supersededMessageIDs: []
        )
    }

    /// Default empty response for clients that have not adopted semantic message reads.
    func semanticMessages(_ request: ProvenanceSemanticMessageQueryRequest) async throws
        -> ProvenanceSemanticMessageQueryResponse {
        ProvenanceSemanticMessageQueryResponse(records: [])
    }

    /// Materializes and caches semantic message records for supplied semantic inferences.
    func materializeSemanticMessages(
        _ request: ProvenanceSemanticMessageMaterializationRequest
    ) async throws -> ProvenanceSemanticMessageMaterializationResponse {
        var activeRecords: [ProvenanceSemanticMessageRecord] = []
        var publishedIDs: [String] = []
        var unchangedIDs: [String] = []
        var skippedIDs: [String] = []

        let renderer = ProvenanceSemanticMessageRenderer(
            presentationPolicy: request.presentationPolicy,
            presentationProducerID: request.presentationProducerID,
            presentationProducerVersion: request.presentationProducerVersion
        )
        for inference in request.semanticInferenceRecords {
            guard let candidate = renderer.record(
                for: inference,
                createdAt: request.createdAt
            ) else {
                skippedIDs.append(inference.id)
                continue
            }

            let existing = try await semanticMessages(
                ProvenanceSemanticMessageQueryRequest(
                    scope: candidate.scope,
                    scopeID: candidate.scopeID,
                    semanticInferenceKind: candidate.semanticInferenceKind,
                    presentationPolicyID: candidate.presentationPolicyID,
                    limit: 1
                )
            ).records.first

            if let existing, existing.messageClaimMatches(candidate) {
                activeRecords.append(existing)
                unchangedIDs.append(existing.id)
                continue
            }

            let record = candidate.superseding(existing.map { [$0.id] } ?? [])
            _ = try await publishSemanticMessage(ProvenanceSemanticMessagePublishRequest(record: record))
            activeRecords.append(record)
            publishedIDs.append(record.id)
        }

        return ProvenanceSemanticMessageMaterializationResponse(
            records: activeRecords,
            publishedMessageIDs: publishedIDs,
            unchangedMessageIDs: unchangedIDs,
            skippedSemanticInferenceIDs: skippedIDs
        )
    }
}

private extension ProvenanceSemanticMessageRecord {
    func messageClaimMatches(_ other: ProvenanceSemanticMessageRecord) -> Bool {
        semanticInferenceID == other.semanticInferenceID
            && semanticInferenceKind == other.semanticInferenceKind
            && concisePhrase == other.concisePhrase
            && expandedMeaning == other.expandedMeaning
            && structuredSemanticPayload == other.structuredSemanticPayload
            && confidence == other.confidence
            && specificity == other.specificity
            && presentationProducerType == other.presentationProducerType
            && presentationProducerID == other.presentationProducerID
            && presentationProducerVersion == other.presentationProducerVersion
            && presentationPolicyID == other.presentationPolicyID
            && presentationPolicyVersion == other.presentationPolicyVersion
            && localeIdentifier == other.localeIdentifier
    }
}
