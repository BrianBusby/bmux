import Foundation

extension ProvenanceCodingAgentSessionSemanticInferenceProducer {
    static func explicitSemanticStatements(
        in snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ExplicitSemanticStatement] {
        var statements: [ExplicitSemanticStatement] = []
        var order = 0
        for turn in detailedSemanticTurns(in: snapshot) {
            for summary in sortedReasoningSummaries(turn) {
                statements.append(contentsOf: explicitStatements(
                    in: summary.text,
                    sourceID: summary.id,
                    sourceKind: "coding_agent_reasoning_summary",
                    turnID: turn.turn.id,
                    provider: summary.provider,
                    source: summary.source,
                    completedAt: summary.completedAt,
                    startingOrder: &order
                ))
            }
            for message in sortedAssistantMessages(turn) {
                statements.append(contentsOf: explicitStatements(
                    in: message.text,
                    sourceID: message.id,
                    sourceKind: "coding_agent_assistant_message",
                    turnID: turn.turn.id,
                    provider: message.provider,
                    source: message.source,
                    completedAt: message.completedAt,
                    startingOrder: &order
                ))
            }
        }
        return statements.sorted(by: eventSort)
    }

    static func sortedReasoningSummaries(
        _ turn: ProvenanceFactualSessionProjectionTurnSnapshot
    ) -> [ProvenanceCodingAgentReasoningSummaryRecord] {
        turn.visibleReasoningSummaries.sorted {
            if $0.completedAt == $1.completedAt { return $0.id < $1.id }
            return $0.completedAt < $1.completedAt
        }
    }

    static func sortedAssistantMessages(
        _ turn: ProvenanceFactualSessionProjectionTurnSnapshot
    ) -> [ProvenanceCodingAgentAssistantMessageRecord] {
        turn.assistantMessages.sorted {
            if $0.completedAt == $1.completedAt { return $0.id < $1.id }
            return $0.completedAt < $1.completedAt
        }
    }

    static func explicitStatements(
        in text: String,
        sourceID: String,
        sourceKind: String,
        turnID: String,
        provider: String,
        source: ProvenanceSource,
        completedAt: Date,
        startingOrder: inout Int
    ) -> [ExplicitSemanticStatement] {
        var statements: [ExplicitSemanticStatement] = []
        var insideFence = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if beginsFence(trimmed) {
                insideFence.toggle()
                continue
            }
            defer { startingOrder += 1 }
            guard !insideFence, isExplicitSemanticMarkerLine(trimmed) else { continue }
            statements.append(ExplicitSemanticStatement(
                line: trimmed,
                sourceID: sourceID,
                sourceKind: sourceKind,
                turnID: turnID,
                provider: provider,
                source: source,
                completedAt: completedAt,
                order: startingOrder
            ))
        }
        return statements
    }

    static func statementFields(after marker: String, in line: String) -> [String: String]? {
        guard line.hasPrefix(marker) else { return nil }
        let body = line.dropFirst(marker.count)
        var fields: [String: String] = [:]
        for component in body.split(separator: ";", omittingEmptySubsequences: true) {
            let parts = component.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = stripBoundaryQuotes(String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines))
            guard !key.isEmpty, let normalizedValue = normalizedEvidenceText(value) else {
                return nil
            }
            fields[key] = normalizedValue
        }
        return fields.isEmpty ? nil : fields
    }

    static func isBlockerStatement(_ line: String) -> Bool {
        line.hasPrefix("Blocker:") || line.hasPrefix("Blocker resolved:")
    }

    static func isExplicitSemanticMarkerLine(_ line: String) -> Bool {
        isBlockerStatement(line) || line.hasPrefix("Approach change:")
    }

    static func isUnsupportedExplicitStatement(_ line: String) -> Bool {
        if line.contains("?") { return true }
        if line.hasPrefix(">") || line.hasPrefix("\"") || line.hasPrefix("'") || line.hasPrefix("//") {
            return true
        }
        let lowercased = line.lowercased()
        let unsupportedPhrases = [
            "example",
            "hypothetical",
            "not a blocker",
            "not blocked",
            "no blocker",
            "quoted",
        ]
        return unsupportedPhrases.contains { lowercased.contains($0) }
    }

    static func blockerResolutionState(
        from token: String
    ) -> ProvenanceCodingAgentBlockerState? {
        switch token {
        case "cleared", "resolved":
            return .reportedCleared
        case "bypassed", "workaround", "worked_around":
            return .reportedBypassed
        case "no_longer_applies", "ceased", "obsolete":
            return .reportedNoLongerApplies
        default:
            return nil
        }
    }

    static func approachChangeState(
        from token: String
    ) -> ProvenanceCodingAgentApproachChangeState? {
        switch token {
        case "replaced", "replacement":
            return .reportedReplaced
        case "abandoned":
            return .reportedAbandoned
        case "deferred":
            return .reportedDeferred
        case "failed":
            return .reportedFailed
        default:
            return nil
        }
    }

    static func blockerKey(activity: String, condition: String, milestoneID: String?) -> String {
        [
            "session",
            normalizedIdentityText(activity),
            normalizedIdentityText(condition),
            milestoneID.map(normalizedIdentityText) ?? "no-milestone",
        ].joined(separator: "|")
    }

    static func approachChangeKey(_ event: ApproachChangeEvent) -> String {
        [
            "session",
            normalizedIdentityText(event.objective),
            normalizedIdentityText(event.priorApproach),
            event.replacementApproach.map(normalizedIdentityText) ?? "no-replacement",
            event.reason.map(normalizedIdentityText) ?? "no-reason",
            event.milestoneID.map(normalizedIdentityText) ?? "no-milestone",
            event.state.rawValue,
        ].joined(separator: "|")
    }

    static func blockerID(key: String, episode: Int) -> String {
        let fingerprint = fnv1a64Hex("blocker|\(key)|episode:\(episode)")
        return ["blocker", "session", "episode", String(episode), fingerprint]
            .map(sanitizedIDComponent)
            .joined(separator: "-")
    }

    static func approachChangeID(key: String) -> String {
        let fingerprint = fnv1a64Hex("approach-change|\(key)")
        return ["approach-change", "session", fingerprint]
            .map(sanitizedIDComponent)
            .joined(separator: "-")
    }

    static func normalizedSemanticToken(_ value: String?) -> String? {
        normalizedEvidenceText(value)?
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    static func normalizedIdentityText(_ value: String) -> String {
        normalizedEvidenceText(value)?
            .lowercased()
            .replacingOccurrences(of: " ", with: "-") ?? "unknown"
    }

    static func stripBoundaryQuotes(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let first = value.first
        let last = value.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    static let codeFenceScalar = 96

    static func beginsFence(_ value: String) -> Bool {
        let backtickFence = String(repeating: String(UnicodeScalar(codeFenceScalar)!), count: 3)
        let tildeFence = String(repeating: String(UnicodeScalar(126)!), count: 3)
        return value.hasPrefix(backtickFence) || value.hasPrefix(tildeFence)
    }

    static func eventSort(_ lhs: ExplicitSemanticStatement, _ rhs: ExplicitSemanticStatement) -> Bool {
        if lhs.completedAt != rhs.completedAt {
            return lhs.completedAt < rhs.completedAt
        }
        if lhs.order != rhs.order {
            return lhs.order < rhs.order
        }
        return lhs.sourceID < rhs.sourceID
    }

    static func eventSort(_ lhs: BlockerEvent, _ rhs: BlockerEvent) -> Bool {
        eventSort(lhs.statement, rhs.statement)
    }

    static func eventSort(_ lhs: ApproachChangeEvent, _ rhs: ApproachChangeEvent) -> Bool {
        eventSort(lhs.statement, rhs.statement)
    }
}

extension ProvenanceCodingAgentSessionSemanticInferenceProducer.BlockerAccumulator {
    mutating func apply(_ event: ProvenanceCodingAgentSessionSemanticInferenceProducer.BlockerEvent) {
        activity = event.activity
        condition = event.condition
        description = event.description ?? event.condition
        milestoneID = event.milestoneID
        state = event.state
        stateBasis = event.stateBasis
        reportedByProvider = event.statement.provider
        reportedBySource = event.statement.source.rawValue
        sourceEvidenceRefs.append(event.statement.evidenceRef)
        ambiguityReasons.append(contentsOf: event.ambiguityReasons)
        omissionReasons.append(contentsOf: event.omissionReasons)
        if sourceEvidenceRefs.count == 1,
           event.stateBasis == .visibleAgentResolutionStatement {
            ambiguityReasons.append("resolution_without_matching_open_blocker")
        }
    }
}
