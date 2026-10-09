import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// Captures previous owners before an upsert can reassign a stable evidence record.
    func outcomeInvalidation(before event: ProvenanceEvent) throws -> ProvenanceOutcomeInvalidation {
        let payload = event.payload
        let thread = try payload.codingAgentThread.flatMap { try codingAgentThread(id: $0.id) }
        let message = try payload.codingAgentAssistantMessage.flatMap { try codingAgentAssistantMessage(id: $0.id) }
        let turn = try payload.codingAgentTurn.flatMap { try codingAgentTurn(id: $0.id) }
        let prompt = try payload.codingAgentPrompt.flatMap { try codingAgentPrompt(id: $0.id) }
        let plan = try payload.codingAgentPlanUpdate.flatMap { try codingAgentPlanUpdate(id: $0.id) }
        let command = try payload.codingAgentCommand.flatMap { try codingAgentCommand(id: $0.id) }
        let reasoning = try payload.codingAgentReasoningSummary.flatMap { try codingAgentReasoningSummary(id: $0.id) }
        let attribution = try payload.codingAgentFileChangeAttribution.flatMap { try codingAgentFileChangeAttribution(id: $0.id) }
        var previousTurnIDs = Set([turn?.id, prompt?.turnID, plan?.turnID, command?.turnID,
                                   reasoning?.turnID, attribution?.turnID].compactMap { $0 })
        if let thread {
            previousTurnIDs.formUnion(try turnOutcomeTurnIDs(sessionID: thread.sessionID))
        }
        return try ProvenanceOutcomeInvalidation(
            event: event,
            previousRepository: payload.repository.flatMap { try repository(id: $0.id) },
            previousWorktree: payload.worktree.flatMap { try worktree(id: $0.id) },
            previousTurnIDs: previousTurnIDs,
            previousSessionIDs: Set([thread?.sessionID, message?.sessionID, turn?.sessionID, prompt?.sessionID, plan?.sessionID, command?.sessionID,
                                     reasoning?.sessionID, attribution?.sessionID].compactMap { $0 })
        )
    }

    func affectedTurnOutcomeIDs(event: ProvenanceEvent, invalidation: ProvenanceOutcomeInvalidation) throws -> Set<String> {
        let payload = event.payload
        var turnIDs = invalidation.turnIDs
        var sessionIDs = Set<String>()
        if turnIDs.isEmpty, let sessionID = event.sessionID { sessionIDs.insert(sessionID) }
        if let session = payload.session { sessionIDs.insert(session.id) }
        if let thread = payload.codingAgentThread { sessionIDs.insert(thread.sessionID) }
        for sessionID in sessionIDs {
            turnIDs.formUnion(try turnOutcomeTurnIDs(sessionID: sessionID))
        }
        if let worktree = payload.worktree, invalidation.worktreeChanged {
            turnIDs.formUnion(try turnOutcomeTurnIDs(worktreeID: worktree.id))
        }
        if let repository = payload.repository, invalidation.repositoryChanged {
            turnIDs.formUnion(try turnOutcomeTurnIDs(repositoryID: repository.id))
        }
        if let changeSet = payload.changeSet {
            turnIDs.formUnion(try turnOutcomeTurnIDs(changeSetID: changeSet.id))
        }
        for fileChange in payload.fileChanges {
            turnIDs.formUnion(try turnOutcomeTurnIDs(fileChangeID: fileChange.id))
            turnIDs.formUnion(try turnOutcomeTurnIDs(worktreeID: fileChange.worktreeID))
        }
        return turnIDs
    }

    func affectedSessionOutcomeIDs(event: ProvenanceEvent, invalidation: ProvenanceOutcomeInvalidation) throws -> Set<String> {
        let payload = event.payload
        var sessionIDs = invalidation.previousSessionIDs
        if let sessionID = event.sessionID {
            sessionIDs.insert(sessionID)
        }
        if let session = payload.session {
            sessionIDs.insert(session.id)
        }
        if let thread = payload.codingAgentThread {
            sessionIDs.insert(thread.sessionID)
        }
        if let turn = payload.codingAgentTurn {
            sessionIDs.insert(turn.sessionID)
        }
        if let prompt = payload.codingAgentPrompt {
            sessionIDs.insert(prompt.sessionID)
        }
        if let plan = payload.codingAgentPlanUpdate {
            sessionIDs.insert(plan.sessionID)
        }
        if let command = payload.codingAgentCommand {
            sessionIDs.insert(command.sessionID)
        }
        if let summary = payload.codingAgentReasoningSummary {
            sessionIDs.insert(summary.sessionID)
        }
        if let message = payload.codingAgentAssistantMessage {
            sessionIDs.insert(message.sessionID)
        }
        if let attribution = payload.codingAgentFileChangeAttribution {
            sessionIDs.insert(attribution.sessionID)
        }
        if let worktree = payload.worktree, invalidation.worktreeChanged {
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(worktreeID: worktree.id))
        }
        if let repository = payload.repository, invalidation.repositoryChanged {
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(repositoryID: repository.id))
        }
        if let changeSet = payload.changeSet {
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(changeSetID: changeSet.id))
        }
        for fileChange in payload.fileChanges {
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(fileChangeID: fileChange.id))
            sessionIDs.formUnion(try sessionOutcomeSessionIDs(worktreeID: fileChange.worktreeID))
        }
        return sessionIDs
    }
}
