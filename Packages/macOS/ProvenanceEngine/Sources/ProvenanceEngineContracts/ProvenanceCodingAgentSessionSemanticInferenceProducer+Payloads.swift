import Foundation

extension ProvenanceCodingAgentSessionSemanticInferenceProducer {
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

    static func milestonePayload(
        for turn: ProvenanceFactualSessionProjectionTurnSnapshot?
    ) -> ProvenanceCodingAgentMilestonePayload {
        guard let turn else {
            return ProvenanceCodingAgentMilestonePayload(
                currentMilestoneID: nil,
                milestones: [],
                basis: "missing_turn",
                unknownReason: "No coding-agent turn has been observed for this session."
            )
        }

        if let plan = turn.currentPlan {
            let milestones = milestones(from: plan)
            if !milestones.isEmpty {
                return ProvenanceCodingAgentMilestonePayload(
                    currentMilestoneID: currentMilestoneID(in: milestones),
                    milestones: milestones,
                    basis: "current_plan"
                )
            }
        }

        if let prompt = turn.submittedPrompt,
           let summary = normalizedEvidenceText(prompt.text) {
            let milestone = ProvenanceCodingAgentMilestone(
                id: milestoneID(prefix: "prompt", title: summary, order: 0),
                title: summary,
                status: .active,
                order: 0
            )
            return ProvenanceCodingAgentMilestonePayload(
                currentMilestoneID: milestone.id,
                milestones: [milestone],
                basis: "submitted_prompt"
            )
        }

        return ProvenanceCodingAgentMilestonePayload(
            currentMilestoneID: nil,
            milestones: [],
            basis: "insufficient_milestone_evidence",
            unknownReason: "No bounded plan or submitted prompt evidence is available for this turn."
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
}
