import Foundation

/// Concrete coding-agent semantic inference kinds currently owned by Provenance Engine.
public enum ProvenanceCodingAgentSemanticInferenceKind: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// Broader outcome for one provider conversation or workstream.
    case threadIntent = "coding_agent.thread_intent"

    /// Local objective for one provider turn.
    case turnIntent = "coding_agent.turn_intent"

    /// Current high-level session phase.
    case sessionPhase = "coding_agent.session_phase"

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
    public static let producerVersion = "first-semantic-session-inferences-v1"

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
            if let existing, existing.semanticClaimMatches(candidate) {
                activeRecords.append(existing)
                unchangedIDs.append(existing.id)
                continue
            }

            let record = candidate.superseding(existing.map { [$0.id] } ?? [])
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

private extension ProvenanceCodingAgentSessionSemanticInferenceProducer {
    struct TextComponents {
        let action: String?
        let subject: String?
        let target: String?
        let purpose: String?
    }

    struct ActivitySignal {
        let observedAt: Date
        let priority: Int
        let payload: ProvenanceCodingAgentCurrentActivityPayload
    }

    static func currentThread(
        in snapshot: ProvenanceFactualSessionProjectionSnapshot,
        latestTurn: ProvenanceFactualSessionProjectionTurnSnapshot?
    ) -> ProvenanceCodingAgentThreadRecord? {
        if let threadID = latestTurn?.turn.threadID,
           let thread = snapshot.providerThreads.first(where: { $0.id == threadID }) {
            return thread
        }
        if snapshot.providerThreads.count == 1 {
            return snapshot.providerThreads[0]
        }
        return nil
    }

    static func threadIntentPayload(
        for thread: ProvenanceCodingAgentThreadRecord,
        in snapshot: ProvenanceFactualSessionProjectionSnapshot,
        latestTurn: ProvenanceFactualSessionProjectionTurnSnapshot?
    ) -> ProvenanceCodingAgentIntentPayload {
        let threadTurns = snapshot.turns
            .filter { $0.turn.threadID == thread.id }
            .sorted(by: turnSort)
        let prompt = threadTurns.compactMap(\.submittedPrompt).first ?? latestTurn?.submittedPrompt
        if let prompt, let summary = normalizedEvidenceText(prompt.text) {
            let parsed = parseText(summary)
            return ProvenanceCodingAgentIntentPayload(
                summary: summary,
                action: parsed.action,
                subject: parsed.subject,
                target: parsed.target,
                purpose: parsed.purpose,
                sourceText: prompt.text
            )
        }

        return ProvenanceCodingAgentIntentPayload(
            summary: "Unknown thread intent",
            unknownReason: "No submitted prompt or equivalent bounded intent evidence is available for this provider thread."
        )
    }

    static func turnIntentPayload(
        for turn: ProvenanceFactualSessionProjectionTurnSnapshot
    ) -> ProvenanceCodingAgentIntentPayload {
        if let prompt = turn.submittedPrompt,
           let summary = normalizedEvidenceText(prompt.text) {
            let parsed = parseText(summary)
            return ProvenanceCodingAgentIntentPayload(
                summary: summary,
                action: parsed.action,
                subject: parsed.subject,
                target: parsed.target,
                purpose: parsed.purpose,
                sourceText: prompt.text
            )
        }

        if let step = currentPlanStep(turn.currentPlan), let summary = normalizedEvidenceText(step.text) {
            let parsed = parseText(summary)
            return ProvenanceCodingAgentIntentPayload(
                summary: summary,
                action: parsed.action,
                subject: parsed.subject,
                target: parsed.target,
                purpose: parsed.purpose,
                sourceText: step.text
            )
        }

        return ProvenanceCodingAgentIntentPayload(
            summary: "Unknown turn intent",
            unknownReason: "No submitted prompt or active plan step is available for this turn."
        )
    }

    static func currentActivityPayload(
        for turn: ProvenanceFactualSessionProjectionTurnSnapshot?
    ) -> ProvenanceCodingAgentCurrentActivityPayload {
        guard let turn else {
            return ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .unknown,
                summary: "Unknown current activity",
                basis: "missing_turn",
                unknownReason: "No coding-agent turn has been observed for this session."
            )
        }

        let signals = activitySignals(for: turn).sorted { lhs, rhs in
            if lhs.observedAt == rhs.observedAt {
                return lhs.priority < rhs.priority
            }
            return lhs.observedAt < rhs.observedAt
        }
        if let signal = signals.last {
            return signal.payload
        }

        return ProvenanceCodingAgentCurrentActivityPayload(
            activityKind: .unknown,
            summary: "Unknown current activity",
            components: components(from: turn.fileChangeAttributions),
            basis: "insufficient_turn_evidence",
            unknownReason: "No bounded prompt, plan, visible reasoning, command, or file-change evidence is available for this turn."
        )
    }

    static func sessionPhasePayload(
        from activity: ProvenanceCodingAgentCurrentActivityPayload,
        latestTurn: ProvenanceFactualSessionProjectionTurnSnapshot?
    ) -> ProvenanceCodingAgentSessionPhasePayload {
        if let turn = latestTurn?.turn, turn.status.lowercased().contains("blocked") {
            return ProvenanceCodingAgentSessionPhasePayload(
                phase: .waitingBlocked,
                reason: "Latest turn lifecycle is blocked.",
                signals: ["turn_lifecycle"]
            )
        }

        switch activity.activityKind {
        case .debugging:
            return ProvenanceCodingAgentSessionPhasePayload(
                phase: .debugging,
                reason: activity.summary,
                signals: [activity.basis]
            )
        case .validation:
            return ProvenanceCodingAgentSessionPhasePayload(
                phase: .validation,
                reason: activity.summary,
                signals: [activity.basis]
            )
        case .implementation:
            return ProvenanceCodingAgentSessionPhasePayload(
                phase: .implementation,
                reason: activity.summary,
                signals: [activity.basis]
            )
        case .planning:
            return ProvenanceCodingAgentSessionPhasePayload(
                phase: .planning,
                reason: activity.summary,
                signals: [activity.basis]
            )
        case .investigation:
            return ProvenanceCodingAgentSessionPhasePayload(
                phase: .investigation,
                reason: activity.summary,
                signals: [activity.basis]
            )
        case .waiting:
            return ProvenanceCodingAgentSessionPhasePayload(
                phase: .waitingBlocked,
                reason: activity.summary,
                signals: [activity.basis]
            )
        case .concluding:
            return ProvenanceCodingAgentSessionPhasePayload(
                phase: .concluding,
                reason: activity.summary,
                signals: [activity.basis]
            )
        case .unknown:
            return ProvenanceCodingAgentSessionPhasePayload(
                phase: .unknown,
                reason: activity.unknownReason ?? activity.summary,
                signals: [activity.basis]
            )
        }
    }

    static func activitySignals(for turn: ProvenanceFactualSessionProjectionTurnSnapshot) -> [ActivitySignal] {
        var signals: [ActivitySignal] = []
        for attribution in turn.fileChangeAttributions {
            guard let summary = normalizedEvidenceText(attribution.summary) else { continue }
            let parsed = parseText(summary)
            signals.append(ActivitySignal(
                observedAt: attribution.observedAt,
                priority: 4,
                payload: ProvenanceCodingAgentCurrentActivityPayload(
                    activityKind: .implementation,
                    summary: summary,
                    action: parsed.action,
                    subject: parsed.subject,
                    target: parsed.target,
                    purpose: parsed.purpose,
                    components: normalizedStrings(attribution.paths),
                    basis: "file_change_attribution"
                )
            ))
        }

        if let plan = turn.currentPlan,
           let step = currentPlanStep(plan),
           let summary = normalizedEvidenceText(step.text) {
            let parsed = parseText(summary)
            signals.append(ActivitySignal(
                observedAt: plan.observedAt,
                priority: 3,
                payload: ProvenanceCodingAgentCurrentActivityPayload(
                    activityKind: activityKind(from: summary, fallback: .planning),
                    summary: summary,
                    action: parsed.action,
                    subject: parsed.subject,
                    target: parsed.target,
                    purpose: parsed.purpose,
                    components: components(from: turn.fileChangeAttributions),
                    basis: "current_plan"
                )
            ))
        }

        for command in turn.completedCommands {
            guard let payload = activityPayload(for: command, fileComponents: components(from: turn.fileChangeAttributions)) else {
                continue
            }
            signals.append(ActivitySignal(observedAt: command.completedAt, priority: 5, payload: payload))
        }

        for summaryRecord in turn.visibleReasoningSummaries {
            guard let summary = normalizedEvidenceText(summaryRecord.text) else { continue }
            let parsed = parseText(summary)
            signals.append(ActivitySignal(
                observedAt: summaryRecord.completedAt,
                priority: 2,
                payload: ProvenanceCodingAgentCurrentActivityPayload(
                    activityKind: activityKind(from: summary, fallback: .investigation),
                    summary: summary,
                    action: parsed.action,
                    subject: parsed.subject,
                    target: parsed.target,
                    purpose: parsed.purpose,
                    components: components(from: turn.fileChangeAttributions),
                    basis: "visible_reasoning_summary"
                )
            ))
        }

        if let prompt = turn.submittedPrompt,
           let summary = normalizedEvidenceText(prompt.text) {
            let parsed = parseText(summary)
            signals.append(ActivitySignal(
                observedAt: prompt.submittedAt,
                priority: 1,
                payload: ProvenanceCodingAgentCurrentActivityPayload(
                    activityKind: activityKind(from: summary, fallback: .planning),
                    summary: summary,
                    action: parsed.action,
                    subject: parsed.subject,
                    target: parsed.target,
                    purpose: parsed.purpose,
                    components: components(from: turn.fileChangeAttributions),
                    basis: "submitted_prompt"
                )
            ))
        }

        return signals
    }

    static func activityPayload(
        for command: ProvenanceCodingAgentCommandRecord,
        fileComponents: [String]
    ) -> ProvenanceCodingAgentCurrentActivityPayload? {
        let commandText = command.command.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedCommand = commandText.lowercased()
        let lowercasedStatus = command.status.lowercased()
        if lowercasedCommand == "pwd" || lowercasedCommand == "true" || lowercasedCommand == ":" {
            return nil
        }

        if lowercasedStatus.contains("fail") || (command.exitCode.map { $0 != 0 } ?? false) {
            return ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .debugging,
                summary: "Investigating failed command: \(commandText)",
                action: "investigate",
                subject: "failed command",
                components: fileComponents,
                basis: "failed_command"
            )
        }

        if isValidationCommand(lowercasedCommand) {
            return ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .validation,
                summary: "Validating with \(commandText)",
                action: "validate",
                subject: "current changes",
                components: fileComponents,
                basis: "completed_command"
            )
        }

        if isInspectionCommand(lowercasedCommand) {
            return ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .investigation,
                summary: "Inspecting with \(commandText)",
                action: "inspect",
                subject: "workspace evidence",
                components: fileComponents,
                basis: "completed_command"
            )
        }

        let parsed = parseText(commandText)
        return ProvenanceCodingAgentCurrentActivityPayload(
            activityKind: activityKind(from: commandText, fallback: .implementation),
            summary: commandText,
            action: parsed.action,
            subject: parsed.subject,
            target: parsed.target,
            purpose: parsed.purpose,
            components: fileComponents,
            basis: "completed_command"
        )
    }

    static func record(
        kind: ProvenanceCodingAgentSemanticInferenceKind,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        payload: ProvenanceSemanticPayloadValue,
        evidenceRefs: [ProvenanceSemanticEvidenceReference],
        revision: Int?,
        confidence: ProvenanceConfidence,
        specificity: ProvenanceSemanticSpecificity,
        createdAt: Date,
        producerID: String,
        producerVersion: String
    ) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: stableRecordID(
                kind: kind.rawValue,
                scope: scope,
                scopeID: scopeID,
                revision: revision,
                payload: payload,
                producerVersion: producerVersion
            ),
            kind: kind.rawValue,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: evidenceRefs,
            supportingFactualRevision: revision,
            confidence: confidence,
            specificity: specificity,
            producerType: .rule,
            producerID: producerID,
            producerVersion: producerVersion,
            createdAt: createdAt
        )
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentIntentPayload,
        thread: ProvenanceCodingAgentThreadRecord,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_thread", id: thread.id))
        if let prompt = snapshot.turns
            .filter({ $0.turn.threadID == thread.id })
            .sorted(by: turnSort)
            .compactMap(\.submittedPrompt)
            .first {
            refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: prompt.id))
        }
        return deduplicated(refs)
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentIntentPayload,
        turn: ProvenanceFactualSessionProjectionTurnSnapshot,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_turn", id: turn.turn.id))
        if let prompt = turn.submittedPrompt {
            refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: prompt.id))
        } else if let plan = turn.currentPlan {
            refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_plan_update", id: plan.id))
        }
        return deduplicated(refs)
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentSessionPhasePayload,
        latestTurn: ProvenanceFactualSessionProjectionTurnSnapshot?,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        if let latestTurn {
            refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_turn", id: latestTurn.turn.id))
            refs.append(contentsOf: materialActivityEvidenceRefs(from: latestTurn))
        }
        return deduplicated(refs)
    }

    static func evidenceRefs(
        for payload: ProvenanceCodingAgentCurrentActivityPayload,
        turn: ProvenanceFactualSessionProjectionTurnSnapshot,
        snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceSemanticEvidenceReference] {
        var refs = baseEvidenceRefs(sessionID: snapshot.session.id, revision: snapshot.revision)
        refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_turn", id: turn.turn.id))
        refs.append(contentsOf: materialActivityEvidenceRefs(from: turn, basis: payload.basis))
        return deduplicated(refs)
    }

    static func baseEvidenceRefs(sessionID: String, revision: Int?) -> [ProvenanceSemanticEvidenceReference] {
        [ProvenanceSemanticEvidenceReference(
            kind: "factual_session_projection",
            id: sessionID,
            factualRevision: revision
        )]
    }

    static func materialActivityEvidenceRefs(
        from turn: ProvenanceFactualSessionProjectionTurnSnapshot,
        basis: String? = nil
    ) -> [ProvenanceSemanticEvidenceReference] {
        switch basis {
        case "file_change_attribution":
            return turn.fileChangeAttributions.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_file_change_attribution", id: $0.id)
            }
        case "failed_command", "completed_command":
            return turn.completedCommands.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_command", id: $0.id)
            }
        case "current_plan":
            return turn.currentPlan.map {
                [ProvenanceSemanticEvidenceReference(kind: "coding_agent_plan_update", id: $0.id)]
            } ?? []
        case "visible_reasoning_summary":
            return turn.visibleReasoningSummaries.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_reasoning_summary", id: $0.id)
            }
        case "submitted_prompt":
            return turn.submittedPrompt.map {
                [ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: $0.id)]
            } ?? []
        default:
            var refs: [ProvenanceSemanticEvidenceReference] = []
            if let prompt = turn.submittedPrompt {
                refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: prompt.id))
            }
            if let plan = turn.currentPlan {
                refs.append(ProvenanceSemanticEvidenceReference(kind: "coding_agent_plan_update", id: plan.id))
            }
            refs.append(contentsOf: turn.visibleReasoningSummaries.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_reasoning_summary", id: $0.id)
            })
            refs.append(contentsOf: turn.completedCommands.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_command", id: $0.id)
            })
            refs.append(contentsOf: turn.fileChangeAttributions.map {
                ProvenanceSemanticEvidenceReference(kind: "coding_agent_file_change_attribution", id: $0.id)
            })
            return refs
        }
    }

    static func stableRecordID(
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        revision: Int?,
        payload: ProvenanceSemanticPayloadValue,
        producerVersion: String
    ) -> String {
        let encodedPayload = (try? sortedJSONEncoder.encode(payload)).map {
            String(decoding: $0, as: UTF8.self)
        } ?? "unencodable"
        let fingerprint = fnv1a64Hex("\(kind)|\(scope.rawValue)|\(scopeID)|\(revision ?? 0)|\(producerVersion)|\(encodedPayload)")
        return ["semantic", kind, scope.rawValue, scopeID, "rev", String(revision ?? 0), fingerprint]
            .map(sanitizedIDComponent)
            .joined(separator: "-")
    }

    static func currentPlanStep(_ plan: ProvenanceCodingAgentPlanUpdateRecord?) -> ProvenanceCodingAgentPlanStepRecord? {
        guard let plan else { return nil }
        let statusPriority = ["in_progress": 0, "pending": 1, "completed": 2]
        return plan.steps.sorted { lhs, rhs in
            let lhsPriority = statusPriority[lhs.status.lowercased()] ?? 3
            let rhsPriority = statusPriority[rhs.status.lowercased()] ?? 3
            if lhsPriority == rhsPriority { return lhs.order < rhs.order }
            return lhsPriority < rhsPriority
        }.first
    }

    static func normalizedEvidenceText(_ text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return collapsed.isEmpty ? nil : collapsed
    }

    static func normalizedStrings(_ values: [String]) -> [String] {
        values.compactMap(normalizedEvidenceText)
    }

    static func components(from attributions: [ProvenanceCodingAgentFileChangeAttributionRecord]) -> [String] {
        normalizedStrings(attributions.flatMap(\.paths))
    }

    static func parseText(_ text: String) -> TextComponents {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let leading = words.first.map(String.init) ?? ""
        let lowercasedLeading = leading.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":,."))
        let recognizedActions: Set<String> = [
            "add", "adding", "audit", "auditing", "build", "building", "change", "changing", "debug", "debugging",
            "fix", "fixing", "implement", "implementing", "inspect", "inspecting", "investigate", "investigating",
            "migrate", "migrating", "plan", "planning", "read", "reading", "refine", "refining", "refactor",
            "refactoring", "test", "testing", "update", "updating", "validate", "validating", "verify", "verifying",
        ]
        let action = recognizedActions.contains(lowercasedLeading) ? lowercasedLeading : nil
        let remainder = words.count > 1 ? String(words[1]) : nil
        let directional = splitDirectionalSubject(remainder ?? trimmed)
        return TextComponents(
            action: action,
            subject: directional.subject,
            target: directional.target,
            purpose: directional.purpose
        )
    }

    static func splitDirectionalSubject(_ text: String) -> (subject: String?, target: String?, purpose: String?) {
        let separators = [" to use ", " into ", " toward ", " for "]
        let lowercased = text.lowercased()
        for separator in separators {
            if let range = lowercased.range(of: separator) {
                let subject = text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                let tail = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if separator == " for " {
                    return (subject.isEmpty ? nil : subject, nil, tail.isEmpty ? nil : tail)
                }
                return (subject.isEmpty ? nil : subject, tail.isEmpty ? nil : tail, nil)
            }
        }
        let subject = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (subject.isEmpty ? nil : subject, nil, nil)
    }

    static func activityKind(
        from text: String,
        fallback: ProvenanceCodingAgentActivityKind
    ) -> ProvenanceCodingAgentActivityKind {
        let lowercased = text.lowercased()
        if lowercased.contains("debug") || lowercased.contains("failed") || lowercased.contains("failure") {
            return .debugging
        }
        if lowercased.contains("test") || lowercased.contains("validate") || lowercased.contains("verify") || lowercased.contains("check") {
            return .validation
        }
        if lowercased.contains("inspect") || lowercased.contains("investigat") || lowercased.contains("audit") || lowercased.contains("read") {
            return .investigation
        }
        if lowercased.contains("plan") || lowercased.contains("design") {
            return .planning
        }
        if lowercased.contains("implement") || lowercased.contains("add") || lowercased.contains("change") || lowercased.contains("update") || lowercased.contains("refactor") || lowercased.contains("migrate") {
            return .implementation
        }
        return fallback
    }

    static func isValidationCommand(_ command: String) -> Bool {
        command.contains(" test") || command.hasPrefix("test") || command.contains("swift test") || command.contains("project-docs check") || command.contains("project-docs validate") || command.contains("lint") || command.contains("tsc")
    }

    static func isInspectionCommand(_ command: String) -> Bool {
        ["rg", "sed", "ls", "cat", "find", "git status", "git diff", "git log", "grep"].contains { command == $0 || command.hasPrefix("\($0) ") }
    }

    static func turnSort(
        _ lhs: ProvenanceFactualSessionProjectionTurnSnapshot,
        _ rhs: ProvenanceFactualSessionProjectionTurnSnapshot
    ) -> Bool {
        let lhsDate = lhs.turn.startedAt ?? lhs.turn.completedAt ?? lhs.turn.updatedAt
        let rhsDate = rhs.turn.startedAt ?? rhs.turn.completedAt ?? rhs.turn.updatedAt
        if lhsDate == rhsDate { return lhs.turn.id < rhs.turn.id }
        return lhsDate < rhsDate
    }

    static func deduplicated(_ refs: [ProvenanceSemanticEvidenceReference]) -> [ProvenanceSemanticEvidenceReference] {
        var seen = Set<ProvenanceSemanticEvidenceReference>()
        var result: [ProvenanceSemanticEvidenceReference] = []
        for ref in refs where !seen.contains(ref) {
            result.append(ref)
            seen.insert(ref)
        }
        return result
    }

    static var sortedJSONEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func fnv1a64Hex(_ value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    static func sanitizedIDComponent(_ value: String) -> String {
        let scalars = value.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
            .lowercased()
        return collapsed.isEmpty ? "unknown" : collapsed
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
