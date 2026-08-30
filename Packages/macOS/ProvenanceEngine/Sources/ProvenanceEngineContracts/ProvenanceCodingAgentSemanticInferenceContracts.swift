import Foundation

/// Concrete coding-agent semantic inference kinds currently owned by Provenance Engine.
public enum ProvenanceCodingAgentSemanticInferenceKind: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// Broader outcome for one provider conversation or workstream.
    case threadIntent = "coding_agent.thread_intent"

    /// Local objective for one provider turn.
    case turnIntent = "coding_agent.turn_intent"

    /// Current high-level session phase.
    case sessionPhase = "coding_agent.session_phase"

    /// Current milestone set inferred from bounded coding-agent plan or prompt evidence.
    case milestones = "coding_agent.milestones"

    /// Current blocker set inferred from explicit visible coding-agent statements.
    case blockers = "coding_agent.blockers"

    /// Approach changes inferred from explicit visible coding-agent statements.
    case approachChanges = "coding_agent.approach_changes"

    /// Current/latest concrete activity inside a turn.
    case currentActivity = "coding_agent.current_activity"
}

/// Coarse coding-agent work phase inferred above factual Current State.
public enum ProvenanceCodingAgentSessionPhase: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    case understanding
    case investigation
    case planning
    case implementation
    case validation
    case debugging
    case waitingBlocked = "waiting_blocked"
    case concluding
    case unknown
}

/// Activity category for the current/latest coding-agent work.
public enum ProvenanceCodingAgentActivityKind: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    case investigation
    case planning
    case implementation
    case validation
    case debugging
    case waiting
    case concluding
    case unknown
}

/// Structured semantic intent payload for thread and turn intent claims.
public struct ProvenanceCodingAgentIntentPayload: Codable, Equatable, Sendable {
    /// Human-readable but evidence-derived claim text.
    public let summary: String

    /// Action phrase when deterministically extractable from bounded evidence.
    public let action: String?

    /// Subject of the intent when deterministically extractable.
    public let subject: String?

    /// Target or destination when the source text contains a clear directional phrase.
    public let target: String?

    /// Purpose when the source text contains an explicit purpose phrase.
    public let purpose: String?

    /// Component or file-path hints carried as structured facts, not display wording.
    public let components: [String]

    /// Bounded source text used to derive the claim.
    public let sourceText: String?

    /// Why the claim had to remain broad or unknown.
    public let unknownReason: String?

    /// Creates an intent payload.
    public init(
        summary: String,
        action: String? = nil,
        subject: String? = nil,
        target: String? = nil,
        purpose: String? = nil,
        components: [String] = [],
        sourceText: String? = nil,
        unknownReason: String? = nil
    ) {
        self.summary = summary
        self.action = action
        self.subject = subject
        self.target = target
        self.purpose = purpose
        self.components = components
        self.sourceText = sourceText
        self.unknownReason = unknownReason
    }

    /// Converts this typed payload into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(semanticObject([
            "summary": .string(summary),
            "action": action.map(ProvenanceSemanticPayloadValue.string),
            "subject": subject.map(ProvenanceSemanticPayloadValue.string),
            "target": target.map(ProvenanceSemanticPayloadValue.string),
            "purpose": purpose.map(ProvenanceSemanticPayloadValue.string),
            "components": .array(components.map(ProvenanceSemanticPayloadValue.string)),
            "sourceText": sourceText.map(ProvenanceSemanticPayloadValue.string),
            "unknownReason": unknownReason.map(ProvenanceSemanticPayloadValue.string),
        ]))
    }

    /// Creates a typed intent payload from a generic semantic record payload.
    public init?(semanticPayloadValue: ProvenanceSemanticPayloadValue) {
        guard case let .object(object) = semanticPayloadValue,
              let summary = object.stringValue(for: "summary") else { return nil }
        self.init(
            summary: summary,
            action: object.stringValue(for: "action"),
            subject: object.stringValue(for: "subject"),
            target: object.stringValue(for: "target"),
            purpose: object.stringValue(for: "purpose"),
            components: object.stringArrayValue(for: "components"),
            sourceText: object.stringValue(for: "sourceText"),
            unknownReason: object.stringValue(for: "unknownReason")
        )
    }
}

/// Structured semantic payload for the session phase claim.
public struct ProvenanceCodingAgentSessionPhasePayload: Codable, Equatable, Sendable {
    /// Current inferred phase.
    public let phase: ProvenanceCodingAgentSessionPhase

    /// Evidence-derived explanation for the phase assignment.
    public let reason: String

    /// Bounded signal labels that supported the phase.
    public let signals: [String]

    /// Creates a phase payload.
    public init(phase: ProvenanceCodingAgentSessionPhase, reason: String, signals: [String] = []) {
        self.phase = phase
        self.reason = reason
        self.signals = signals
    }

    /// Converts this typed payload into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(semanticObject([
            "phase": .string(phase.rawValue),
            "reason": .string(reason),
            "signals": .array(signals.map(ProvenanceSemanticPayloadValue.string)),
        ]))
    }

    /// Creates a typed phase payload from a generic semantic record payload.
    public init?(semanticPayloadValue: ProvenanceSemanticPayloadValue) {
        guard case let .object(object) = semanticPayloadValue,
              let phaseRawValue = object.stringValue(for: "phase"),
              let phase = ProvenanceCodingAgentSessionPhase(rawValue: phaseRawValue),
              let reason = object.stringValue(for: "reason") else { return nil }
        self.init(phase: phase, reason: reason, signals: object.stringArrayValue(for: "signals"))
    }
}

/// Structured semantic payload for the current activity claim.
public struct ProvenanceCodingAgentCurrentActivityPayload: Codable, Equatable, Sendable {
    /// Current activity category.
    public let activityKind: ProvenanceCodingAgentActivityKind

    /// Human-readable but evidence-derived activity claim text.
    public let summary: String

    /// Action phrase when deterministically extractable.
    public let action: String?

    /// Subject being acted on when deterministically extractable.
    public let subject: String?

    /// Target or destination when the source text contains a clear directional phrase.
    public let target: String?

    /// Purpose when the source text contains an explicit purpose phrase.
    public let purpose: String?

    /// Component or file-path hints carried as structured facts, not display wording.
    public let components: [String]

    /// Evidence class or bounded source that produced the activity claim.
    public let basis: String

    /// Why the claim had to remain broad or unknown.
    public let unknownReason: String?

    /// Creates an activity payload.
    public init(
        activityKind: ProvenanceCodingAgentActivityKind,
        summary: String,
        action: String? = nil,
        subject: String? = nil,
        target: String? = nil,
        purpose: String? = nil,
        components: [String] = [],
        basis: String,
        unknownReason: String? = nil
    ) {
        self.activityKind = activityKind
        self.summary = summary
        self.action = action
        self.subject = subject
        self.target = target
        self.purpose = purpose
        self.components = components
        self.basis = basis
        self.unknownReason = unknownReason
    }

    /// Converts this typed payload into the generic semantic record payload shape.
    public var semanticPayloadValue: ProvenanceSemanticPayloadValue {
        .object(semanticObject([
            "activityKind": .string(activityKind.rawValue),
            "summary": .string(summary),
            "action": action.map(ProvenanceSemanticPayloadValue.string),
            "subject": subject.map(ProvenanceSemanticPayloadValue.string),
            "target": target.map(ProvenanceSemanticPayloadValue.string),
            "purpose": purpose.map(ProvenanceSemanticPayloadValue.string),
            "components": .array(components.map(ProvenanceSemanticPayloadValue.string)),
            "basis": .string(basis),
            "unknownReason": unknownReason.map(ProvenanceSemanticPayloadValue.string),
        ]))
    }

    /// Creates a typed activity payload from a generic semantic record payload.
    public init?(semanticPayloadValue: ProvenanceSemanticPayloadValue) {
        guard case let .object(object) = semanticPayloadValue,
              let kindRawValue = object.stringValue(for: "activityKind"),
              let activityKind = ProvenanceCodingAgentActivityKind(rawValue: kindRawValue),
              let summary = object.stringValue(for: "summary"),
              let basis = object.stringValue(for: "basis") else { return nil }
        self.init(
            activityKind: activityKind,
            summary: summary,
            action: object.stringValue(for: "action"),
            subject: object.stringValue(for: "subject"),
            target: object.stringValue(for: "target"),
            purpose: object.stringValue(for: "purpose"),
            components: object.stringArrayValue(for: "components"),
            basis: basis,
            unknownReason: object.stringValue(for: "unknownReason")
        )
    }
}

/// Request to materialize first-pass coding-agent semantic session inferences.
public struct ProvenanceCodingAgentSessionSemanticInferenceRequest: Codable, Equatable, Sendable {
    /// PE session identifier to read through the factual session projection.
    public let sessionID: String

    /// Maximum detailed turns to include in the factual projection read.
    public let turnLimit: Int?

    /// Producer identity written to published inference records.
    public let producerID: String

    /// Producer version written to published inference records.
    public let producerVersion: String

    /// Creation timestamp for any newly published semantic records.
    public let createdAt: Date

    /// Creates a coding-agent semantic inference request.
    public init(
        sessionID: String,
        turnLimit: Int? = nil,
        producerID: String = ProvenanceCodingAgentSessionSemanticInferenceProducer.producerID,
        producerVersion: String = ProvenanceCodingAgentSessionSemanticInferenceProducer.producerVersion,
        createdAt: Date
    ) {
        self.sessionID = sessionID
        self.turnLimit = turnLimit
        self.producerID = producerID
        self.producerVersion = producerVersion
        self.createdAt = createdAt
    }
}

/// Response from materializing first-pass coding-agent semantic session inferences.
public struct ProvenanceCodingAgentSessionSemanticInferenceResponse: Codable, Equatable, Sendable {
    /// Whether the source session was found.
    public let found: Bool

    /// Reason when no inferences could be produced.
    public let reason: String?

    /// PE session identifier requested.
    public let sessionID: String

    /// Factual projection revision used for the inference pass.
    public let factualRevision: Int?

    /// Active records produced or retained by this pass, in deterministic concept order.
    public let records: [ProvenanceSemanticInferenceRecord]

    /// New inference IDs published by this pass.
    public let publishedInferenceIDs: [String]

    /// Existing active inference IDs retained because the semantic payload did not change.
    public let unchangedInferenceIDs: [String]

    /// Creates a coding-agent semantic inference response.
    public init(
        found: Bool,
        reason: String? = nil,
        sessionID: String,
        factualRevision: Int? = nil,
        records: [ProvenanceSemanticInferenceRecord] = [],
        publishedInferenceIDs: [String] = [],
        unchangedInferenceIDs: [String] = []
    ) {
        self.found = found
        self.reason = reason
        self.sessionID = sessionID
        self.factualRevision = factualRevision
        self.records = records
        self.publishedInferenceIDs = publishedInferenceIDs
        self.unchangedInferenceIDs = unchangedInferenceIDs
    }
}

/// Deterministic, rule-based first-pass semantic producer for coding-agent session facts.
public struct ProvenanceCodingAgentSessionSemanticInferenceProducer: Sendable {
    /// Stable producer identity for first-pass rule inferences.
    public static let producerID = "provenance-engine.coding-agent-session-semantics.rule"

    /// Stable producer version for first-pass rule inferences.
    public static let producerVersion = "first-semantic-session-inferences-v3"

    /// Maximum plan-derived milestones included in one semantic milestone payload.
    public static let maximumMilestonesPerPlan = 100

    /// Maximum blocker entries included in one semantic blocker payload.
    public static let maximumBlockersPerSession = 50

    /// Maximum approach-change entries included in one semantic approach-change payload.
    public static let maximumApproachChangesPerSession = 50

    /// Producer identity written to generated inference records.
    public let producerID: String

    /// Producer version written to generated inference records.
    public let producerVersion: String

    /// Creates a coding-agent semantic inference producer.
    public init(
        producerID: String = Self.producerID,
        producerVersion: String = Self.producerVersion
    ) {
        self.producerID = producerID
        self.producerVersion = producerVersion
    }

    /// Builds candidate semantic records from one factual coding-agent session projection.
    public func records(
        for snapshot: ProvenanceFactualSessionProjectionSnapshot,
        createdAt: Date
    ) -> [ProvenanceSemanticInferenceRecord] {
        let latestTurn = snapshot.latestTurn
        var records: [ProvenanceSemanticInferenceRecord] = []

        if let thread = Self.currentThread(in: snapshot, latestTurn: latestTurn) {
            let threadPayload = Self.threadIntentPayload(for: thread, in: snapshot, latestTurn: latestTurn)
            records.append(Self.record(
                kind: .threadIntent,
                scope: .thread,
                scopeID: thread.id,
                payload: threadPayload.semanticPayloadValue,
                evidenceRefs: Self.evidenceRefs(for: threadPayload, thread: thread, snapshot: snapshot),
                revision: snapshot.revision,
                confidence: threadPayload.unknownReason == nil ? .medium : .unknown,
                specificity: threadPayload.unknownReason == nil ? .scoped : .broad,
                createdAt: createdAt,
                producerID: producerID,
                producerVersion: producerVersion
            ))
        }

        if let latestTurn {
            let intentPayload = Self.turnIntentPayload(for: latestTurn)
            records.append(Self.record(
                kind: .turnIntent,
                scope: .turn,
                scopeID: latestTurn.turn.id,
                payload: intentPayload.semanticPayloadValue,
                evidenceRefs: Self.evidenceRefs(for: intentPayload, turn: latestTurn, snapshot: snapshot),
                revision: snapshot.revision,
                confidence: intentPayload.unknownReason == nil ? .high : .unknown,
                specificity: intentPayload.unknownReason == nil ? .scoped : .broad,
                createdAt: createdAt,
                producerID: producerID,
                producerVersion: producerVersion
            ))
        }

        let activityPayload = Self.currentActivityPayload(for: latestTurn)
        let milestonePayload = Self.milestonePayload(for: latestTurn)
        let blockerPayload = Self.blockerPayload(for: snapshot, milestonePayload: milestonePayload)
        let approachChangePayload = Self.approachChangePayload(for: snapshot, milestonePayload: milestonePayload)
        records.append(Self.record(
            kind: .milestones,
            scope: .session,
            scopeID: snapshot.session.id,
            payload: milestonePayload.semanticPayloadValue,
            evidenceRefs: Self.evidenceRefs(for: milestonePayload, latestTurn: latestTurn, snapshot: snapshot),
            revision: snapshot.revision,
            confidence: milestonePayload.unknownReason == nil ? .medium : .unknown,
            specificity: milestonePayload.unknownReason == nil ? .scoped : .broad,
            createdAt: createdAt,
            producerID: producerID,
            producerVersion: producerVersion
        ))

        records.append(Self.record(
            kind: .blockers,
            scope: .session,
            scopeID: snapshot.session.id,
            payload: blockerPayload.semanticPayloadValue,
            evidenceRefs: Self.evidenceRefs(for: blockerPayload, snapshot: snapshot),
            revision: snapshot.revision,
            confidence: blockerPayload.unknownReason == nil ? .medium : .unknown,
            specificity: blockerPayload.unknownReason == nil ? .scoped : .broad,
            createdAt: createdAt,
            producerID: producerID,
            producerVersion: producerVersion
        ))

        records.append(Self.record(
            kind: .approachChanges,
            scope: .session,
            scopeID: snapshot.session.id,
            payload: approachChangePayload.semanticPayloadValue,
            evidenceRefs: Self.evidenceRefs(for: approachChangePayload, snapshot: snapshot),
            revision: snapshot.revision,
            confidence: approachChangePayload.unknownReason == nil ? .medium : .unknown,
            specificity: approachChangePayload.unknownReason == nil ? .scoped : .broad,
            createdAt: createdAt,
            producerID: producerID,
            producerVersion: producerVersion
        ))

        let phasePayload = Self.sessionPhasePayload(from: activityPayload, latestTurn: latestTurn)
        records.append(Self.record(
            kind: .sessionPhase,
            scope: .session,
            scopeID: snapshot.session.id,
            payload: phasePayload.semanticPayloadValue,
            evidenceRefs: Self.evidenceRefs(for: phasePayload, latestTurn: latestTurn, snapshot: snapshot),
            revision: snapshot.revision,
            confidence: phasePayload.phase == .unknown ? .unknown : .medium,
            specificity: phasePayload.phase == .unknown ? .broad : .scoped,
            createdAt: createdAt,
            producerID: producerID,
            producerVersion: producerVersion
        ))

        if let latestTurn {
            records.append(Self.record(
                kind: .currentActivity,
                scope: .turn,
                scopeID: latestTurn.turn.id,
                payload: activityPayload.semanticPayloadValue,
                evidenceRefs: Self.evidenceRefs(for: activityPayload, turn: latestTurn, snapshot: snapshot),
                revision: snapshot.revision,
                confidence: activityPayload.activityKind == .unknown ? .unknown : .medium,
                specificity: activityPayload.activityKind == .unknown ? .broad : .granular,
                createdAt: createdAt,
                producerID: producerID,
                producerVersion: producerVersion
            ))
        }

        return records
    }

    /// Builds candidate semantic records with one-off producer metadata.
    public static func records(
        for snapshot: ProvenanceFactualSessionProjectionSnapshot,
        createdAt: Date,
        producerID: String = Self.producerID,
        producerVersion: String = Self.producerVersion
    ) -> [ProvenanceSemanticInferenceRecord] {
        Self(producerID: producerID, producerVersion: producerVersion)
            .records(for: snapshot, createdAt: createdAt)
    }
}

public extension ProvenanceSemanticInferenceRecord {
    /// Returns this record with replaced supersession fields while preserving the semantic claim.
    func superseding(_ inferenceIDs: [String]) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: id,
            schemaVersion: schemaVersion,
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: supportingEvidenceRefs,
            supportingFactualRevision: supportingFactualRevision,
            confidence: confidence,
            specificity: specificity,
            producerType: producerType,
            producerID: producerID,
            producerVersion: producerVersion,
            createdAt: createdAt,
            supersedes: inferenceIDs,
            supersededBy: supersededBy,
            status: status
        )
    }
}

public extension ProvenanceEngineClient {
    /// Materializes first-pass coding-agent semantic session inferences from the factual projection.
    func publishCodingAgentSessionSemanticInferences(
        _ request: ProvenanceCodingAgentSessionSemanticInferenceRequest
    ) async throws -> ProvenanceCodingAgentSessionSemanticInferenceResponse {
        let factual = try await factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: request.sessionID, turnLimit: request.turnLimit)
        )
        guard let snapshot = factual.snapshot else {
            return ProvenanceCodingAgentSessionSemanticInferenceResponse(
                found: false,
                reason: factual.reason ?? "no_session",
                sessionID: request.sessionID
            )
        }

        let producer = ProvenanceCodingAgentSessionSemanticInferenceProducer(
            producerID: request.producerID,
            producerVersion: request.producerVersion
        )
        let candidates = producer.records(
            for: snapshot,
            createdAt: request.createdAt
        )

        var activeRecords: [ProvenanceSemanticInferenceRecord] = []
        var publishedIDs: [String] = []
        var unchangedIDs: [String] = []
        for candidate in candidates {
            let existing = try await semanticInferences(
                ProvenanceSemanticInferenceQueryRequest(
                    scope: candidate.scope,
                    scopeID: candidate.scopeID,
                    kind: candidate.kind,
                    limit: 1
                )
            ).records.first
            let effectiveCandidate = existing
                .flatMap { candidate.mergingPartialSourceHistory(with: $0) } ?? candidate
            if let existing, existing.semanticClaimMatches(effectiveCandidate) {
                activeRecords.append(existing)
                unchangedIDs.append(existing.id)
                continue
            }

            let record = effectiveCandidate.superseding(existing.map { [$0.id] } ?? [])
            _ = try await publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: record))
            activeRecords.append(record)
            publishedIDs.append(record.id)
        }

        return ProvenanceCodingAgentSessionSemanticInferenceResponse(
            found: true,
            sessionID: request.sessionID,
            factualRevision: snapshot.revision,
            records: activeRecords,
            publishedInferenceIDs: publishedIDs,
            unchangedInferenceIDs: unchangedIDs
        )
    }
}

private extension ProvenanceSemanticInferenceRecord {
    func semanticClaimMatches(_ other: ProvenanceSemanticInferenceRecord) -> Bool {
        payload == other.payload
            && confidence == other.confidence
            && specificity == other.specificity
            && producerType == other.producerType
            && producerID == other.producerID
            && producerVersion == other.producerVersion
    }

    func mergingPartialSourceHistory(
        with existing: ProvenanceSemanticInferenceRecord
    ) -> ProvenanceSemanticInferenceRecord? {
        guard scope == existing.scope, scopeID == existing.scopeID, kind == existing.kind else {
            return nil
        }
        if kind == ProvenanceCodingAgentSemanticInferenceKind.blockers.rawValue {
            return mergingPartialBlockerPayload(with: existing)
        }
        if kind == ProvenanceCodingAgentSemanticInferenceKind.approachChanges.rawValue {
            return mergingPartialApproachChangePayload(with: existing)
        }
        return nil
    }

    func mergingPartialBlockerPayload(
        with existing: ProvenanceSemanticInferenceRecord
    ) -> ProvenanceSemanticInferenceRecord? {
        guard let candidatePayload = ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: payload),
              candidatePayload.sourceHistoryState == .partial,
              let existingPayload = ProvenanceCodingAgentBlockerPayload(semanticPayloadValue: existing.payload),
              !existingPayload.blockers.isEmpty else {
            return nil
        }
        guard !candidatePayload.blockers.isEmpty else {
            return existing
        }
        let candidateIDs = Set(candidatePayload.blockers.map(\.id))
        let retained = existingPayload.blockers.filter { !candidateIDs.contains($0.id) }
        let merged = ProvenanceCodingAgentBlockerPayload(
            blockers: retained + candidatePayload.blockers,
            basis: candidatePayload.basis,
            sourceHistoryState: .partial,
            ambiguityReasons: candidatePayload.ambiguityReasons,
            omissionReasons: candidatePayload.omissionReasons + ["partial_source_history_retained_prior_blockers"]
        )
        return replacingPayload(
            merged.semanticPayloadValue,
            evidenceRefs: ProvenanceCodingAgentSessionSemanticInferenceProducer.deduplicated(
                existing.supportingEvidenceRefs + supportingEvidenceRefs
            )
        )
    }

    func mergingPartialApproachChangePayload(
        with existing: ProvenanceSemanticInferenceRecord
    ) -> ProvenanceSemanticInferenceRecord? {
        guard let candidatePayload = ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: payload),
              candidatePayload.sourceHistoryState == .partial,
              let existingPayload = ProvenanceCodingAgentApproachChangePayload(semanticPayloadValue: existing.payload),
              !existingPayload.approachChanges.isEmpty else {
            return nil
        }
        guard !candidatePayload.approachChanges.isEmpty else {
            return existing
        }
        let candidateIDs = Set(candidatePayload.approachChanges.map(\.id))
        let retained = existingPayload.approachChanges.filter { !candidateIDs.contains($0.id) }
        let merged = ProvenanceCodingAgentApproachChangePayload(
            approachChanges: retained + candidatePayload.approachChanges,
            basis: candidatePayload.basis,
            sourceHistoryState: .partial,
            ambiguityReasons: candidatePayload.ambiguityReasons,
            omissionReasons: candidatePayload.omissionReasons + ["partial_source_history_retained_prior_approach_changes"]
        )
        return replacingPayload(
            merged.semanticPayloadValue,
            evidenceRefs: ProvenanceCodingAgentSessionSemanticInferenceProducer.deduplicated(
                existing.supportingEvidenceRefs + supportingEvidenceRefs
            )
        )
    }

    func replacingPayload(
        _ payload: ProvenanceSemanticPayloadValue,
        evidenceRefs: [ProvenanceSemanticEvidenceReference]
    ) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: ProvenanceCodingAgentSessionSemanticInferenceProducer.stableRecordID(
                kind: kind,
                scope: scope,
                scopeID: scopeID,
                revision: supportingFactualRevision,
                payload: payload,
                producerVersion: producerVersion
            ),
            schemaVersion: schemaVersion,
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: evidenceRefs,
            supportingFactualRevision: supportingFactualRevision,
            confidence: confidence,
            specificity: specificity,
            producerType: producerType,
            producerID: producerID,
            producerVersion: producerVersion,
            createdAt: createdAt,
            supersedes: supersedes,
            supersededBy: supersededBy,
            status: status
        )
    }
}

private func semanticObject(
    _ values: [String: ProvenanceSemanticPayloadValue?]
) -> [String: ProvenanceSemanticPayloadValue] {
    values.compactMapValues { $0 }
}

private extension Dictionary where Key == String, Value == ProvenanceSemanticPayloadValue {
    func stringValue(for key: String) -> String? {
        guard case let .string(value) = self[key] else { return nil }
        return value
    }

    func stringArrayValue(for key: String) -> [String] {
        guard case let .array(values) = self[key] else { return [] }
        return values.compactMap { value in
            guard case let .string(string) = value else { return nil }
            return string
        }
    }
}
