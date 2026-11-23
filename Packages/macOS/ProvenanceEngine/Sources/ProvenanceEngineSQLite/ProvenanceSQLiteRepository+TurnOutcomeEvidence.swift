import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func turnOutcomeEvidenceKeys(
        turn: ProvenanceCodingAgentTurnRecord, session: ProvenanceSessionRecord?,
        prompt: ProvenanceCodingAgentPromptRecord?, plan: ProvenanceCodingAgentPlanUpdateRecord?,
        commands: [ProvenanceCodingAgentCommandRecord],
        reasoningSummaries: [ProvenanceCodingAgentReasoningSummaryRecord],
        attributions: [ProvenanceCodingAgentFileChangeAttributionRecord]
    ) throws -> Set<TurnOutcomeEvidenceKey> {
        var keys: Set<TurnOutcomeEvidenceKey> = []
        func include(_ kind: String, _ id: String?) {
            if let id { keys.insert(TurnOutcomeEvidenceKey(kind: kind, id: id)) }
        }
        include("coding_agent_turn", turn.id)
        include("session", session?.id)
        include("coding_agent_prompt", prompt?.id)
        include("coding_agent_plan_update", plan?.id)
        for command in commands { include("coding_agent_command", command.id) }
        for summary in reasoningSummaries { include("coding_agent_reasoning_summary", summary.id) }
        for attribution in attributions {
            include("coding_agent_file_change_attribution", attribution.id)
            for id in attribution.fileChangeIDs { include("file_change", id) }
        }
        let thread = try turn.threadID.flatMap { try codingAgentThread(id: $0) }
        include("coding_agent_thread", thread?.id)
        let worktreeID = session?.worktreeID ?? thread?.worktreeID
        let observedWorktree: ProvenanceWorktreeRecord?
        if let worktreeID {
            observedWorktree = try worktree(id: worktreeID)
        } else {
            observedWorktree = nil
        }
        include("worktree", observedWorktree?.id)
        include("repository", observedWorktree?.repositoryID)
        return keys
    }

    func turnOutcomeEvidenceIndex(
        sessionID: String, throughSequence: Int?, keys: Set<TurnOutcomeEvidenceKey>
    ) throws -> TurnOutcomeEvidenceIndex {
        var referencesByKey: [TurnOutcomeEvidenceKey: [ProvenanceTurnOutcomeEvidenceReference]] = [:]
        try forEachEventLedgerEntry(sessionID: sessionID, throughSequence: throughSequence) { entry in
            func append(kind: String, id: String?) {
                guard let id else { return }
                let key = TurnOutcomeEvidenceKey(kind: kind, id: id)
                guard keys.contains(key) else { return }
                referencesByKey[key, default: []].append(
                    ProvenanceTurnOutcomeEvidenceReference(
                        eventID: entry.event.id,
                        eventSequence: entry.sequence,
                        eventType: entry.event.eventType.rawValue,
                        source: entry.event.source,
                        evidenceOrigin: entry.event.evidenceOrigin,
                        evidenceScope: entry.event.evidenceScope,
                        recordKind: kind,
                        recordID: id,
                        interpretedByRuleVersion: Self.turnOutcomeRuleVersion,
                        sourceState: "available"
                    )
                )
            }
            let payload = entry.event.payload
            append(kind: "repository", id: payload.repository?.id)
            append(kind: "worktree", id: payload.worktree?.id)
            append(kind: "session", id: payload.session?.id)
            append(kind: "session_relationship", id: payload.sessionRelationship?.sessionID)
            append(kind: "work_item", id: payload.workItem?.id)
            append(kind: "contribution", id: payload.contribution?.id)
            append(kind: "checkpoint", id: payload.checkpoint?.id)
            append(kind: "change_set", id: payload.changeSet?.id)
            for fileChange in payload.fileChanges {
                append(kind: "file_change", id: fileChange.id)
            }
            append(kind: "validation_run", id: payload.validationRun?.id)
            append(kind: "coding_agent_thread", id: payload.codingAgentThread?.id)
            append(kind: "coding_agent_turn", id: payload.codingAgentTurn?.id)
            append(kind: "coding_agent_prompt", id: payload.codingAgentPrompt?.id)
            append(kind: "coding_agent_plan_update", id: payload.codingAgentPlanUpdate?.id)
            append(kind: "coding_agent_command", id: payload.codingAgentCommand?.id)
            append(kind: "coding_agent_reasoning_summary", id: payload.codingAgentReasoningSummary?.id)
            append(kind: "coding_agent_file_change_attribution", id: payload.codingAgentFileChangeAttribution?.id)
        }
        return TurnOutcomeEvidenceIndex(referencesByKey: referencesByKey)
    }

}
