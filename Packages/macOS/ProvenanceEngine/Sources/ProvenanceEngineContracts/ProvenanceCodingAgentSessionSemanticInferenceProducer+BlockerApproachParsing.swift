import Foundation

extension ProvenanceCodingAgentSessionSemanticInferenceProducer {
    struct ExplicitSemanticStatement {
        let line: String
        let sourceID: String
        let sourceKind: String
        let turnID: String
        let provider: String
        let source: ProvenanceSource
        let completedAt: Date
        let order: Int

        var evidenceRef: ProvenanceSemanticEvidenceReference {
            ProvenanceSemanticEvidenceReference(kind: sourceKind, id: sourceID)
        }
    }

    struct BlockerEvent {
        let activity: String
        let condition: String
        let description: String?
        let milestoneID: String?
        let state: ProvenanceCodingAgentBlockerState
        let stateBasis: ProvenanceCodingAgentBlockerStateBasis
        let statement: ExplicitSemanticStatement
        let ambiguityReasons: [String]
        let omissionReasons: [String]
    }

    struct BlockerAccumulator {
        let key: String
        var episode: Int
        var order: Int
        var activity: String
        var condition: String
        var description: String
        var milestoneID: String?
        var state: ProvenanceCodingAgentBlockerState
        var stateBasis: ProvenanceCodingAgentBlockerStateBasis
        var reportedByProvider: String?
        var reportedBySource: String?
        var sourceEvidenceRefs: [ProvenanceSemanticEvidenceReference]
        var ambiguityReasons: [String]
        var omissionReasons: [String]
    }

    struct ApproachChangeEvent {
        let objective: String
        let priorApproach: String
        let replacementApproach: String?
        let reason: String?
        let milestoneID: String?
        let state: ProvenanceCodingAgentApproachChangeState
        let statement: ExplicitSemanticStatement
        let ambiguityReasons: [String]
        let omissionReasons: [String]
    }

    struct ApproachChangeAccumulator {
        let key: String
        var order: Int
        var objective: String
        var priorApproach: String
        var replacementApproach: String?
        var reason: String?
        var milestoneID: String?
        var state: ProvenanceCodingAgentApproachChangeState
        var reportedByProvider: String?
        var reportedBySource: String?
        var sourceEvidenceRefs: [ProvenanceSemanticEvidenceReference]
        var ambiguityReasons: [String]
        var omissionReasons: [String]
    }

    static func blockerPayload(
        for snapshot: ProvenanceFactualSessionProjectionSnapshot,
        milestonePayload: ProvenanceCodingAgentMilestonePayload
    ) -> ProvenanceCodingAgentBlockerPayload {
        let sourceHistoryState = semanticSourceHistoryState(in: snapshot)
        let parse = blockerEvents(in: snapshot, milestonePayload: milestonePayload)
        var omissions = parse.omissionReasons
        if sourceHistoryState == .partial {
            omissions.append("partial_factual_source_history")
        }
        guard !parse.events.isEmpty else {
            return ProvenanceCodingAgentBlockerPayload(
                blockers: [],
                basis: "explicit_visible_agent_statement",
                sourceHistoryState: sourceHistoryState,
                unknownReason: "No supported explicit blocker statement is available in the bounded factual session projection.",
                omissionReasons: omissions
            )
        }

        let blockers = blockers(from: parse.events)
        let bounded = Array(blockers.prefix(maximumBlockersPerSession))
        if blockers.count > bounded.count {
            omissions.append("blocker_output_truncated")
        }
        return ProvenanceCodingAgentBlockerPayload(
            blockers: bounded,
            basis: "explicit_visible_agent_statement",
            sourceHistoryState: sourceHistoryState,
            omissionReasons: omissions
        )
    }

    static func approachChangePayload(
        for snapshot: ProvenanceFactualSessionProjectionSnapshot,
        milestonePayload: ProvenanceCodingAgentMilestonePayload
    ) -> ProvenanceCodingAgentApproachChangePayload {
        let sourceHistoryState = semanticSourceHistoryState(in: snapshot)
        let parse = approachChangeEvents(in: snapshot, milestonePayload: milestonePayload)
        var omissions = parse.omissionReasons
        if sourceHistoryState == .partial {
            omissions.append("partial_factual_source_history")
        }
        guard !parse.events.isEmpty else {
            return ProvenanceCodingAgentApproachChangePayload(
                approachChanges: [],
                basis: "explicit_visible_agent_statement",
                sourceHistoryState: sourceHistoryState,
                unknownReason: "No supported explicit approach-change statement is available in the bounded factual session projection.",
                omissionReasons: omissions
            )
        }

        let approachChanges = approachChanges(from: parse.events)
        let bounded = Array(approachChanges.prefix(maximumApproachChangesPerSession))
        if approachChanges.count > bounded.count {
            omissions.append("approach_change_output_truncated")
        }
        return ProvenanceCodingAgentApproachChangePayload(
            approachChanges: bounded,
            basis: "explicit_visible_agent_statement",
            sourceHistoryState: sourceHistoryState,
            omissionReasons: omissions
        )
    }

    static func blockerEvents(
        in snapshot: ProvenanceFactualSessionProjectionSnapshot,
        milestonePayload: ProvenanceCodingAgentMilestonePayload
    ) -> (events: [BlockerEvent], omissionReasons: [String]) {
        var events: [BlockerEvent] = []
        var omissions: [String] = []
        for statement in explicitSemanticStatements(in: snapshot) {
            guard isBlockerStatement(statement.line) else { continue }
            let parsed = blockerEvent(from: statement, milestonePayload: milestonePayload)
            if let event = parsed.event {
                events.append(event)
            } else if let reason = parsed.omissionReason {
                omissions.append(reason)
            }
        }
        return (events.sorted(by: eventSort), uniqueStrings(omissions))
    }

    static func approachChangeEvents(
        in snapshot: ProvenanceFactualSessionProjectionSnapshot,
        milestonePayload: ProvenanceCodingAgentMilestonePayload
    ) -> (events: [ApproachChangeEvent], omissionReasons: [String]) {
        var events: [ApproachChangeEvent] = []
        var omissions: [String] = []
        for statement in explicitSemanticStatements(in: snapshot) {
            guard statement.line.hasPrefix("Approach change:") else { continue }
            let parsed = approachChangeEvent(from: statement, milestonePayload: milestonePayload)
            if let event = parsed.event {
                events.append(event)
            } else if let reason = parsed.omissionReason {
                omissions.append(reason)
            }
        }
        return (events.sorted(by: eventSort), uniqueStrings(omissions))
    }

    static func blockerEvent(
        from statement: ExplicitSemanticStatement,
        milestonePayload: ProvenanceCodingAgentMilestonePayload
    ) -> (event: BlockerEvent?, omissionReason: String?) {
        guard !isUnsupportedExplicitStatement(statement.line) else {
            return (nil, "unsupported_blocker_statement_context")
        }
        if statement.line.hasPrefix("Blocker resolved:") {
            return blockerResolutionEvent(from: statement, milestonePayload: milestonePayload)
        }
        guard statement.line.hasPrefix("Blocker:"),
              let fields = statementFields(after: "Blocker:", in: statement.line),
              let activity = normalizedEvidenceText(fields["activity"]),
              let condition = normalizedEvidenceText(fields["condition"]) else {
            return (nil, "unsupported_blocker_statement_fields")
        }

        let milestone = resolvedMilestoneID(fields["milestone"], in: milestonePayload)
        return (BlockerEvent(
            activity: activity,
            condition: condition,
            description: normalizedEvidenceText(fields["description"]),
            milestoneID: milestone.id,
            state: .reportedOpen,
            stateBasis: .visibleAgentStatement,
            statement: statement,
            ambiguityReasons: milestone.ambiguityReasons,
            omissionReasons: milestone.omissionReasons
        ), nil)
    }

    static func blockerResolutionEvent(
        from statement: ExplicitSemanticStatement,
        milestonePayload: ProvenanceCodingAgentMilestonePayload
    ) -> (event: BlockerEvent?, omissionReason: String?) {
        guard let fields = statementFields(after: "Blocker resolved:", in: statement.line),
              let activity = normalizedEvidenceText(fields["activity"]),
              let condition = normalizedEvidenceText(fields["condition"]),
              let outcome = normalizedSemanticToken(fields["outcome"]),
              let state = blockerResolutionState(from: outcome) else {
            return (nil, "unsupported_blocker_resolution_statement_fields")
        }

        let milestone = resolvedMilestoneID(fields["milestone"], in: milestonePayload)
        return (BlockerEvent(
            activity: activity,
            condition: condition,
            description: normalizedEvidenceText(fields["description"]),
            milestoneID: milestone.id,
            state: state,
            stateBasis: .visibleAgentResolutionStatement,
            statement: statement,
            ambiguityReasons: milestone.ambiguityReasons,
            omissionReasons: milestone.omissionReasons
        ), nil)
    }

    static func approachChangeEvent(
        from statement: ExplicitSemanticStatement,
        milestonePayload: ProvenanceCodingAgentMilestonePayload
    ) -> (event: ApproachChangeEvent?, omissionReason: String?) {
        guard !isUnsupportedExplicitStatement(statement.line) else {
            return (nil, "unsupported_approach_change_statement_context")
        }
        guard let fields = statementFields(after: "Approach change:", in: statement.line),
              let objective = normalizedEvidenceText(fields["objective"]),
              let priorApproach = normalizedEvidenceText(fields["prior"]),
              let stateToken = normalizedSemanticToken(fields["state"]),
              let state = approachChangeState(from: stateToken) else {
            return (nil, "unsupported_approach_change_statement_fields")
        }

        let replacement = normalizedEvidenceText(fields["replacement"])
        guard state != .reportedReplaced || replacement != nil else {
            return (nil, "replacement_approach_required_for_reported_replacement")
        }

        let milestone = resolvedMilestoneID(fields["milestone"], in: milestonePayload)
        return (ApproachChangeEvent(
            objective: objective,
            priorApproach: priorApproach,
            replacementApproach: replacement,
            reason: normalizedEvidenceText(fields["reason"]),
            milestoneID: milestone.id,
            state: state,
            statement: statement,
            ambiguityReasons: milestone.ambiguityReasons,
            omissionReasons: milestone.omissionReasons
        ), nil)
    }

    static func blockers(from events: [BlockerEvent]) -> [ProvenanceCodingAgentBlocker] {
        var accumulators: [String: BlockerAccumulator] = [:]
        for event in events {
            let key = blockerKey(
                activity: event.activity,
                condition: event.condition,
                milestoneID: event.milestoneID
            )
            var accumulator = accumulators[key]
            if accumulator == nil {
                accumulator = BlockerAccumulator(
                    key: key,
                    episode: 0,
                    order: event.statement.order,
                    activity: event.activity,
                    condition: event.condition,
                    description: event.description ?? event.condition,
                    milestoneID: event.milestoneID,
                    state: event.state,
                    stateBasis: event.stateBasis,
                    reportedByProvider: event.statement.provider,
                    reportedBySource: event.statement.source.rawValue,
                    sourceEvidenceRefs: [],
                    ambiguityReasons: [],
                    omissionReasons: []
                )
            } else if let state = accumulator?.state,
                      state != .reportedOpen,
                      event.state == .reportedOpen {
                accumulator?.episode += 1
                accumulator?.order = event.statement.order
                accumulator?.sourceEvidenceRefs = []
            }
            accumulator?.apply(event)
            accumulators[key] = accumulator
        }

        return accumulators.values
            .sorted {
                if $0.order == $1.order { return $0.key < $1.key }
                return $0.order < $1.order
            }
            .map { accumulator in
                ProvenanceCodingAgentBlocker(
                    id: blockerID(key: accumulator.key, episode: accumulator.episode),
                    description: accumulator.description,
                    affectedActivity: accumulator.activity,
                    condition: accumulator.condition,
                    affectedMilestoneID: accumulator.milestoneID,
                    state: accumulator.state,
                    identityBasis: accumulator.milestoneID == nil
                        ? .visibleStatementActivityCondition
                        : .visibleStatementActivityConditionMilestone,
                    stateBasis: accumulator.stateBasis,
                    reportedByProvider: accumulator.reportedByProvider,
                    reportedBySource: accumulator.reportedBySource,
                    sourceEvidenceRefs: deduplicated(accumulator.sourceEvidenceRefs),
                    ambiguityReasons: uniqueStrings(accumulator.ambiguityReasons),
                    omissionReasons: uniqueStrings(accumulator.omissionReasons)
                )
            }
    }

    static func approachChanges(from events: [ApproachChangeEvent]) -> [ProvenanceCodingAgentApproachChange] {
        var accumulators: [String: ApproachChangeAccumulator] = [:]
        for event in events {
            let key = approachChangeKey(event)
            var accumulator = accumulators[key] ?? ApproachChangeAccumulator(
                key: key,
                order: event.statement.order,
                objective: event.objective,
                priorApproach: event.priorApproach,
                replacementApproach: event.replacementApproach,
                reason: event.reason,
                milestoneID: event.milestoneID,
                state: event.state,
                reportedByProvider: event.statement.provider,
                reportedBySource: event.statement.source.rawValue,
                sourceEvidenceRefs: [],
                ambiguityReasons: [],
                omissionReasons: []
            )
            accumulator.sourceEvidenceRefs.append(event.statement.evidenceRef)
            accumulator.ambiguityReasons.append(contentsOf: event.ambiguityReasons)
            accumulator.omissionReasons.append(contentsOf: event.omissionReasons)
            accumulators[key] = accumulator
        }

        return accumulators.values
            .sorted {
                if $0.order == $1.order { return $0.key < $1.key }
                return $0.order < $1.order
            }
            .map { accumulator in
                ProvenanceCodingAgentApproachChange(
                    id: approachChangeID(key: accumulator.key),
                    objective: accumulator.objective,
                    priorApproach: accumulator.priorApproach,
                    replacementApproach: accumulator.replacementApproach,
                    reason: accumulator.reason,
                    affectedMilestoneID: accumulator.milestoneID,
                    state: accumulator.state,
                    identityBasis: accumulator.milestoneID == nil
                        ? .visibleStatementStrategyTransition
                        : .visibleStatementStrategyTransitionMilestone,
                    stateBasis: .visibleAgentStatement,
                    reportedByProvider: accumulator.reportedByProvider,
                    reportedBySource: accumulator.reportedBySource,
                    sourceEvidenceRefs: deduplicated(accumulator.sourceEvidenceRefs),
                    ambiguityReasons: uniqueStrings(accumulator.ambiguityReasons),
                    omissionReasons: uniqueStrings(accumulator.omissionReasons)
                )
            }
    }

    static func detailedSemanticTurns(
        in snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> [ProvenanceFactualSessionProjectionTurnSnapshot] {
        var byID: [String: ProvenanceFactualSessionProjectionTurnSnapshot] = [:]
        for turn in snapshot.turns {
            byID[turn.turn.id] = turn
        }
        if let latestTurn = snapshot.latestTurn {
            byID[latestTurn.turn.id] = latestTurn
        }
        return byID.values.sorted(by: turnSort)
    }

    static func semanticSourceHistoryState(
        in snapshot: ProvenanceFactualSessionProjectionSnapshot
    ) -> ProvenanceCodingAgentSemanticSourceHistoryState {
        var observedTurnIDs = Set(snapshot.priorTurns.map(\.turnID))
        if let latestTurnID = snapshot.latestTurn?.turn.id {
            observedTurnIDs.insert(latestTurnID)
        }
        if observedTurnIDs.isEmpty {
            observedTurnIDs = Set(snapshot.turns.map(\.turn.id))
        }
        let detailedTurnIDs = Set(detailedSemanticTurns(in: snapshot).map(\.turn.id))
        return observedTurnIDs.subtracting(detailedTurnIDs).isEmpty ? .complete : .partial
    }

    static func resolvedMilestoneID(
        _ rawID: String?,
        in payload: ProvenanceCodingAgentMilestonePayload
    ) -> (id: String?, ambiguityReasons: [String], omissionReasons: [String]) {
        guard let rawID = normalizedEvidenceText(rawID) else {
            return (nil, [], [])
        }
        if rawID.lowercased().hasPrefix("title:") {
            return (nil, [], ["milestone_title_link_unsupported"])
        }
        let matches = payload.milestones.filter { $0.id == rawID }
        if matches.count == 1 {
            return (rawID, [], [])
        }
        if matches.count > 1 {
            return (nil, ["milestone_reference_ambiguous"], [])
        }
        return (nil, [], ["milestone_reference_unresolved_or_out_of_scope"])
    }

}
