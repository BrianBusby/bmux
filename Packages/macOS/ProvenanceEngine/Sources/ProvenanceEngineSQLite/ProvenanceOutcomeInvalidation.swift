import ProvenanceEngineContracts

/// Limits historical refresh to changed repository boundaries and directly affected turns.
struct ProvenanceOutcomeInvalidation {
    let repositoryChanged: Bool
    let worktreeChanged: Bool
    let turnIDs: Set<String>
    let previousSessionIDs: Set<String>

    init(
        event: ProvenanceEvent,
        previousRepository: ProvenanceRepositoryRecord?,
        previousWorktree: ProvenanceWorktreeRecord?,
        previousTurnIDs: Set<String>,
        previousSessionIDs: Set<String>
    ) {
        self.previousSessionIDs = previousSessionIDs
        let payload = event.payload
        repositoryChanged = payload.repository.map {
            $0.id != previousRepository?.id || $0.path != previousRepository?.path
        } ?? false
        worktreeChanged = payload.worktree.map {
            $0.id != previousWorktree?.id || $0.repositoryID != previousWorktree?.repositoryID
                || $0.path != previousWorktree?.path || $0.branch != previousWorktree?.branch
                || $0.currentHEAD != previousWorktree?.currentHEAD
        } ?? false
        turnIDs = Set([
            payload.codingAgentTurn?.id, payload.codingAgentPrompt?.turnID,
            payload.codingAgentPlanUpdate?.turnID, payload.codingAgentCommand?.turnID,
            payload.codingAgentReasoningSummary?.turnID, payload.codingAgentFileChangeAttribution?.turnID
        ].compactMap { $0 }).union(previousTurnIDs)
    }
}
